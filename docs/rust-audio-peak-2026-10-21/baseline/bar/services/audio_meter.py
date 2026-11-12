"""Peak meter with bounded capture latency and a measured, time-based release."""
import math
import sys
from array import array


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
        self.pending = max(self.pending, max((abs(sample) for sample in samples if math.isfinite(sample)), default=0))

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
