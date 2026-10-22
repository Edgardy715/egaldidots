#!/usr/bin/env python3
"""Parity and fallback checks for the optional in-process audio reducer."""
import argparse
import ctypes
import importlib.util
import math
import os
from pathlib import Path
import random
import shutil
import struct
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
BASELINE = ROOT / "docs/rust-audio-peak-2026-10-21/baseline/bar/services/audio_meter.py"
SOURCE = ROOT / "bar/services/audio_meter.py"


def load(path, data_home):
    with patch.dict(os.environ, {"XDG_DATA_HOME": str(data_home)}):
        spec = importlib.util.spec_from_file_location("peak_test_module", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module


class PeakTest(unittest.TestCase):
    def test_fragmented_pcm_and_envelope_parity(self):
        rng = random.Random(1847)
        # Raw bit patterns include subnormals, signalling NaNs and arbitrary exponents.
        bits = [0, 0x80000000, 1, 0x80000001, 0x7f7fffff, 0xff7fffff,
                0x7f800000, 0xff800000, 0x7fc00000, 0x7f800001]
        bits += [rng.getrandbits(32) for _ in range(12000)]
        data = b"".join(struct.pack("<I", value) for value in bits)
        for size in (1, 2, 3, 5, 127, 3840, 32768):
            meters = [module.PeakMeter(0) for module in (original, fallback, native)]
            now = 0
            for start in range(0, len(data), size):
                now += .01
                for meter in meters:
                    meter.feed(data[start:start + size])
                    meter.feed(b"")
                self.assertEqual([m.pending for m in meters], [meters[0].pending] * 3)
                self.assertEqual([m.remainder for m in meters], [meters[0].remainder] * 3)
                values = [m.value(now) for m in meters]
                self.assertEqual(values, [values[0]] * 3)
            for when in (now - 1, now, now + .01, now + .5, now + 60):
                values = [m.value(when) for m in meters]
                self.assertEqual(values, [values[0]] * 3)

    def test_signal_attack_release_and_invalid_samples(self):
        for samples in ([], [math.nan, math.inf, -math.inf], [0., -0.],
                        [-.2, .1], [1.e-40, -1.e-39], [-1., .99]):
            meters = [module.PeakMeter(0) for module in (original, fallback, native)]
            data = struct.pack("<" + "f" * len(samples), *samples)
            for m in meters:
                m.feed(data)
            for now in (0, .033, .066, .5, 1):
                values = [m.value(now) for m in meters]
                self.assertEqual(values, [values[0]] * 3)
            self.assertEqual(values, [0.] * 3)

    def test_missing_corrupt_and_wrong_abi_fall_back(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertIsNone(load(SOURCE, tmp)._native_peak)
            target = Path(tmp) / "isla/lib/libisla_audio_peak.so"
            target.parent.mkdir(parents=True)
            target.write_text("not a library")
            self.assertIsNone(load(SOURCE, tmp)._native_peak)
            with patch.object(ctypes, "CDLL", return_value=object()):
                self.assertIsNone(load(SOURCE, tmp)._native_peak)
        self.assertIsNone(fallback._native_peak)
        self.assertIsNotNone(native._native_peak)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--library", type=Path, required=True)
    args, remaining = parser.parse_known_args()
    with tempfile.TemporaryDirectory() as tmp:
        target = Path(tmp) / "native/isla/lib/libisla_audio_peak.so"
        target.parent.mkdir(parents=True)
        shutil.copy2(args.library, target)
        original = load(BASELINE, tmp)
        fallback = load(SOURCE, Path(tmp) / "absent")
        native = load(SOURCE, Path(tmp) / "native")
        unittest.main(argv=[__file__, *remaining])
