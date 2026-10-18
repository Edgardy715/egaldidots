"""Small libpulse bridge for the device-manager extension used by pavucontrol."""

import ctypes as C
import ctypes.util
import time


CALLBACK = C.CFUNCTYPE(None, C.c_void_p, C.c_int, C.c_void_p)


def _library():
    path = ctypes.util.find_library("pulse") or "libpulse.so.0"
    lib = C.CDLL(path)
    definitions = {
        "pa_mainloop_new": (C.c_void_p, []),
        "pa_mainloop_get_api": (C.c_void_p, [C.c_void_p]),
        "pa_mainloop_iterate": (C.c_int, [C.c_void_p, C.c_int, C.POINTER(C.c_int)]),
        "pa_mainloop_free": (None, [C.c_void_p]),
        "pa_context_new": (C.c_void_p, [C.c_void_p, C.c_char_p]),
        "pa_context_connect": (C.c_int, [C.c_void_p, C.c_char_p, C.c_int, C.c_void_p]),
        "pa_context_get_state": (C.c_int, [C.c_void_p]),
        "pa_context_errno": (C.c_int, [C.c_void_p]),
        "pa_context_disconnect": (None, [C.c_void_p]),
        "pa_context_unref": (None, [C.c_void_p]),
        "pa_strerror": (C.c_char_p, [C.c_int]),
        "pa_ext_device_manager_set_device_description": (
            C.c_void_p, [C.c_void_p, C.c_char_p, C.c_char_p, CALLBACK, C.c_void_p]),
        "pa_operation_get_state": (C.c_int, [C.c_void_p]),
        "pa_operation_unref": (None, [C.c_void_p]),
    }
    for name, (result, arguments) in definitions.items():
        function = getattr(lib, name)
        function.restype = result
        function.argtypes = arguments
    return lib


def rename_device(device_key, description, timeout=4):
    lib = _library()
    loop = lib.pa_mainloop_new()
    if not loop:
        raise RuntimeError("No se pudo iniciar libpulse")
    context = None
    operation = None
    try:
        context = lib.pa_context_new(lib.pa_mainloop_get_api(loop), b"Isla audio")
        if not context:
            raise RuntimeError("No se pudo crear el contexto de audio")

        def failure():
            code = lib.pa_context_errno(context)
            return (lib.pa_strerror(code) or b"error de audio").decode("utf-8", "replace")

        if lib.pa_context_connect(context, None, 0, None) < 0:
            raise RuntimeError(failure())
        deadline = time.monotonic() + timeout
        while True:
            state = lib.pa_context_get_state(context)
            if state == 4:  # PA_CONTEXT_READY
                break
            if state in (5, 6):  # FAILED, TERMINATED
                raise RuntimeError(failure())
            if time.monotonic() >= deadline:
                raise TimeoutError("Tiempo agotado al conectar con el audio")
            if lib.pa_mainloop_iterate(loop, 0, None) < 0:
                raise RuntimeError(failure())
            time.sleep(.01)

        success = []

        @CALLBACK
        def finished(_context, ok, _userdata):
            success.append(bool(ok))

        operation = lib.pa_ext_device_manager_set_device_description(
            context, device_key.encode("utf-8"), description.encode("utf-8"), finished, None)
        if not operation:
            raise RuntimeError(failure())
        while True:
            if success:
                if not success[0]:
                    raise RuntimeError(failure())
                return
            state = lib.pa_operation_get_state(operation)
            if state != 0:  # PA_OPERATION_RUNNING
                raise RuntimeError(failure() if state == 2 else "El servidor no confirmó el nombre")
            if time.monotonic() >= deadline:
                raise TimeoutError("Tiempo agotado al renombrar el dispositivo")
            if lib.pa_mainloop_iterate(loop, 0, None) < 0:
                raise RuntimeError(failure())
            time.sleep(.01)
    finally:
        if operation:
            lib.pa_operation_unref(operation)
        if context:
            lib.pa_context_disconnect(context)
            lib.pa_context_unref(context)
        lib.pa_mainloop_free(loop)
