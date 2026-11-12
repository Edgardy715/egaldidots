"""Peak meter with bounded capture latency and a measured, time-based release."""
import math
import sys
from array import array
import ctypes
import os
from pathlib import Path


try:
    _library = ctypes.CDLL(str(Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
                               / "isla/lib/libisla_audio_peak.so"))
    _native_peak = _library.isla_peak_f32_v1
    _native_peak.argtypes = (ctypes.c_void_p, ctypes.c_size_t)
    _native_peak.restype = ctypes.c_float
except (OSError, AttributeError):
    _native_peak = None


INTERVAL = 1 / 30
CAPTURE_OPTIONS = ["--raw", "--format=float32le", "--rate=48000", "--channels=2",
                   "--latency-msec=20", "--process-time-msec=10",
                   "--property=application.name=Isla audio meter"]


class PeakMeter:
    def __init__(self, now):
        self.pending = 0.0
        self.envelope = 0.0
        self.last_tick = now
        self.remainder = b""

    def feed(self, data):
        data = self.remainder + data
        length = len(data) - len(data) % 4
        self.remainder = data[length:]
        samples = array("f")
        samples.frombytes(data[:length])
        if sys.byteorder != "little":
            samples.byteswap()
        # buffer_info points to this owned array, retained until the call returns.
        peak = (_native_peak(*samples.buffer_info()) if _native_peak is not None else
                max((abs(sample) for sample in samples if math.isfinite(sample)), default=0))
        self.pending = max(self.pending, peak)

    def value(self, now):
        elapsed = max(0, now - self.last_tick)
        self.last_tick = now
        # Immediate attack; release follows elapsed time rather than capture chunk count.
        self.envelope = max(self.pending, self.envelope * math.exp(-elapsed / .085))
        self.pending = 0
        if self.envelope < .001:
            return 0.0
        # A dBFS scale keeps quiet but audible signals visible without inventing activity.
        return max(0.0, min(1.0, (20 * math.log10(self.envelope) + 60) / 60))
