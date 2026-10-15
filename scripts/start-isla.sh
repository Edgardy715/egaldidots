#!/bin/sh
set -eu

# shortcut: bridge an updated userspace to the loaded driver until the next reboot.
version=$(cat /sys/module/nvidia/version 2>/dev/null || true)
compat="${XDG_DATA_HOME:-$HOME/.local/share}/isla/nvidia-compat/$version"
system_egl=$(readlink -f /usr/lib/libEGL_nvidia.so.0 2>/dev/null || true)
if [ -n "$version" ] && [ "$system_egl" != "/usr/lib/libEGL_nvidia.so.$version" ] &&
   [ -r "$compat/usr/lib/libEGL_nvidia.so.$version" ] &&
   [ -r "$compat/usr/share/glvnd/egl_vendor.d/10_nvidia.json" ] &&
   [ -r "$compat/usr/lib/gbm/nvidia-drm_gbm.so" ]; then
    export LD_LIBRARY_PATH="$compat/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export __EGL_VENDOR_LIBRARY_FILENAMES="$compat/usr/share/glvnd/egl_vendor.d/10_nvidia.json"
    export GBM_BACKENDS_PATH="$compat/usr/lib/gbm"
fi

qml_plugins="${XDG_DATA_HOME:-$HOME/.local/share}/isla/qml"
if [ -d "$qml_plugins/Wpscan" ]; then
    export QML_IMPORT_PATH="$qml_plugins${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
fi

exec qs -c bar --no-duplicate "$@"
