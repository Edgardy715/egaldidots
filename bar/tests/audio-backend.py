#!/usr/bin/env python3
"""Backend parser and protocol checks without changing host audio."""

import importlib.util
import json
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch


BRIDGE = Path(__file__).resolve().parents[1] / "services" / "audio_bridge.py"
sys.path.insert(0, str(BRIDGE.parent))
import audio_pulse
spec = importlib.util.spec_from_file_location("audio_bridge", BRIDGE)
audio = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audio)


def fixture():
    channel = lambda value: {"value": value}
    volume = {"front-left": channel(32768), "front-right": channel(65536)}
    return {
        "clients": [],
        "info": {"default_sink_name": "sink.a", "default_source_name": "source.a"},
        "sinks": [{"index": 1, "name": "sink.a", "description": "Speakers", "volume": volume,
                   "channel_map": "front-left,front-right", "base_volume": channel(65536),
                   "flags": ["SET_FORMATS"], "formats": ["pcm", "ac3-iec61937, format.rate = 48000"],
                   "monitor_source": "sink.a.monitor", "ports": [{"name": "analog", "description": "Analog",
                   "availability": "available"}], "active_port": "analog"}],
        "sources": [{"index": 2, "name": "source.a", "volume": {"mono": channel(65536)},
                     "channel_map": "mono", "ports": []},
                    {"index": 3, "name": "sink.a.monitor", "monitor_of_sink": 1,
                     "volume": {"mono": channel(65536)}}],
        "sink-inputs": [{"index": 4, "sink": 1, "volume": volume,
                         "channel_map": "front-left,front-right", "properties": {
                             "application.name": "Music", "application.icon_name": "music",
                             "media.name": "Song"}}],
        "source-outputs": [{"index": 5, "source": 2, "volume": {"mono": channel(65536)},
                            "properties": {"application.name": "Recorder"}},
                           {"index": 6, "source": 3, "properties": {
                               "application.name": "Isla audio meter"}}],
        "cards": [{"index": 7, "name": "card.a", "properties": {"device.description": "Card"},
                   "profiles": {"off": {"description": "Off", "available": True},
                                "analog": {"description": "Analog", "available": False}},
                   "active_profile": "off", "ports": {"analog": {
                       "description": "Analog", "latency_offset": "100 usec"}}}],
    }


class AudioBackendTest(unittest.TestCase):
    def setUp(self):
        self.state = audio.normalize(fixture())
        self.output = b""

    def test_normalization_and_monitor_filter(self):
        self.assertEqual(self.state["outputs"][0]["channels"], [
            {"name": "front-left", "volume": 0.5}, {"name": "front-right", "volume": 1.0}])
        self.assertEqual(self.state["outputs"][0]["monitorSource"], "sink.a.monitor")
        self.assertTrue(self.state["outputs"][0]["canRename"])
        self.assertTrue(self.state["inputs"][0]["canRename"])
        pipewire = fixture()
        pipewire["info"]["server_name"] = "PulseAudio (on PipeWire 1.6.9)"
        self.assertFalse(audio.normalize(pipewire)["outputs"][0]["canRename"])
        self.assertEqual(self.state["outputs"][0]["formats"], ["pcm", "ac3-iec61937"])
        self.assertTrue(self.state["outputs"][0]["canSetFormats"])
        self.assertTrue(self.state["inputs"][1]["monitor"])
        self.assertEqual(len(self.state["recording"]), 1)
        self.assertEqual(self.state["playback"][0]["meterSource"], "playback:4")
        self.assertEqual(self.state["cards"][0]["ports"][0]["latencyOffset"], 100)

    def test_zero_indices_and_fallback_descriptions(self):
        raw = fixture()
        raw["sinks"][0].update(index=0, card=0, monitor_source=0)
        raw["sink-inputs"][0]["sink"] = 0
        raw["sources"][0]["card"] = 0
        state = audio.normalize(raw)
        self.assertEqual(state["outputs"][0]["card"], "0")
        self.assertEqual(state["inputs"][0]["card"], "0")
        self.assertEqual(state["playback"][0]["device"], "0")
        self.assertEqual(state["outputs"][0]["monitorSource"], "0")
        self.assertEqual(audio.display_description({"name":"output:analog-stereo+input:mono-fallback","description":"(null)"}),
                         "Salida estéreo analógica + Micrófono mono")

    def test_validated_commands_and_relative_channels(self):
        build = lambda action, args: audio.action_command(action, args, self.state)
        self.assertEqual(build("setVolume", {"kind": "output", "id": "1", "volume": .8}),
                         ["set-sink-volume", "1", "40.000%", "80.000%"])
        self.assertEqual(build("setChannelVolumes", {"kind": "playback", "id": "4",
                                                     "volumes": [.2, .6]}),
                         ["set-sink-input-volume", "4", "20.000%", "60.000%"])
        self.assertEqual(build("moveStream", {"kind": "recording", "id": "5", "device": "2"}),
                         ["move-source-output", "5", "source.a"])
        self.assertEqual(build("moveStream", {"kind": "recording", "id": "5", "device": "3"}),
                         ["move-source-output", "5", "sink.a.monitor"])
        self.assertEqual(build("setLatencyOffset", {"id": "7", "port": "analog", "offset": 500}),
                         ["set-port-latency-offset", "card.a", "analog", "500"])
        self.assertEqual(build("setLatencyOffset", {"id": "7", "port": "analog", "offset": 5_000_000}),
                         ["set-port-latency-offset", "card.a", "analog", "5000000"])
        self.assertEqual(build("setFormats", {"kind": "output", "id": "1",
                                              "formats": ["pcm", "ac3-iec61937"]}),
                         ["set-sink-formats", "1", "pcm;ac3-iec61937"])
        self.assertEqual(build("killStream", {"kind": "playback", "id": "4"}),
                         ["kill-sink-input", "4"])
        self.assertEqual(build("killStream", {"kind": "recording", "id": "5"}),
                         ["kill-source-output", "5"])
        for action, args in [
            ("setVolume", {"kind": "output", "id": "1", "volume": float("nan")}),
            ("setVolume", {"kind": "output", "id": "1", "volume": 2}),
            ("setMute", {"kind": "input", "id": "2", "mute": "toggle"}),
            ("setPort", {"kind": "output", "id": "1", "port": "missing"}),
            ("setProfile", {"id": "7", "profile": "missing"}),
            ("setDefault", {"kind": "playback", "id": "4"}),
            ("setFormats", {"kind": "input", "id": "2", "formats": ["pcm"]}),
            ("setFormats", {"kind": "output", "id": "1", "formats": []}),
            ("setFormats", {"kind": "output", "id": "1", "formats": ["pcm", "pcm"]}),
            ("setFormats", {"kind": "output", "id": "1", "formats": ["pcm;evil"]}),
            ("killStream", {"kind": "output", "id": "1"}),
            ("setLatencyOffset", {"id": "7", "port": "analog", "offset": 5_000_001}),
        ]:
            with self.subTest(action=action, args=args), self.assertRaises(ValueError):
                build(action, args)
        self.state["outputs"][0]["canSetFormats"] = False
        with self.assertRaises(ValueError):
            build("setFormats", {"kind": "output", "id": "1", "formats": ["pcm"]})

    def test_rename_validation_and_dispatch(self):
        self.assertEqual(audio.rename_request({"kind": "output", "id": "1", "description": " Desk "}, self.state),
                         ("sink:sink.a", "Desk"))
        self.assertEqual(audio.rename_request({"kind": "input", "id": "2", "description": "Mic"}, self.state),
                         ("source:source.a", "Mic"))
        for args in ({"kind": "playback", "id": "4", "description": "App"},
                     {"kind": "output", "id": "88", "description": "Ghost"},
                     {"kind": "output", "id": "1", "description": " "},
                     {"kind": "output", "id": "1", "description": "A" * 257},
                     {"kind": "output", "id": "1", "description": "Bad\nName"}):
            with self.subTest(args=args), self.assertRaises(ValueError):
                audio.rename_request(args, self.state)
        bridge = audio.Bridge.__new__(audio.Bridge)
        bridge.state = self.state
        bridge.pending = [("renameDevice", {"kind": "output", "id": "1", "description": "Desk"})]
        bridge.mark_dirty = lambda: None
        messages = []
        with patch.object(audio_pulse, "rename_device") as rename, patch.object(audio, "emit", messages.append):
            bridge.flush_actions()
        rename.assert_called_once_with("sink:sink.a", "Desk")
        self.assertEqual([message["type"] for message in messages], ["busy", "busy"])

    def test_pulse_operation_lifecycle(self):
        class FakePulse:
            def __init__(self, succeeds=True):
                self.cleaned = []
                self.values = None
                self.succeeds = succeeds

            def pa_mainloop_new(self): return 1
            def pa_mainloop_get_api(self, _loop): return 2
            def pa_context_new(self, _api, _name): return 3
            def pa_context_connect(self, *_): return 0
            def pa_context_get_state(self, _context): return 4
            def pa_context_errno(self, _context): return 1
            def pa_strerror(self, _code): return b"Not supported"
            def pa_ext_device_manager_set_device_description(self, _context, key, label, callback, _data):
                self.values = key, label
                callback(None, int(self.succeeds), None)
                return 4
            def pa_operation_unref(self, _operation): self.cleaned.append("operation")
            def pa_context_disconnect(self, _context): self.cleaned.append("disconnect")
            def pa_context_unref(self, _context): self.cleaned.append("context")
            def pa_mainloop_free(self, _loop): self.cleaned.append("loop")

        fake = FakePulse()
        with patch.object(audio_pulse, "_library", return_value=fake):
            audio_pulse.rename_device("sink:sink.a", "Música")
        self.assertEqual(fake.values, (b"sink:sink.a", "Música".encode("utf-8")))
        self.assertEqual(fake.cleaned, ["operation", "disconnect", "context", "loop"])
        unsupported = FakePulse(False)
        with patch.object(audio_pulse, "_library", return_value=unsupported), self.assertRaisesRegex(RuntimeError, "Not supported"):
            audio_pulse.rename_device("sink:sink.a", "Desk")
        self.assertEqual(unsupported.cleaned, ["operation", "disconnect", "context", "loop"])

    def test_meter_failure_keeps_snapshot_visible(self):
        bridge = audio.Bridge.__new__(audio.Bridge)
        bridge.state = None
        bridge.meters = {}
        bridge.wanted_meters = {"sink.a.monitor"}
        bridge.set_meters = lambda _: (_ for _ in ()).throw(OSError("parec unavailable"))
        messages = []
        with patch.object(audio, "snapshot", return_value=self.state), patch.object(audio, "emit", messages.append):
            bridge.update()
        self.assertEqual([message["type"] for message in messages], ["snapshot", "error"])
        self.assertEqual(bridge.state["defaultOutput"], "sink.a")

    def test_direction_changes_in_one_batch_accumulate(self):
        self.state["cards"] = [{"id":"7", "name":"card.a", "activeProfile":"duplex", "profiles":[
            {"name":"duplex","sinks":1,"sources":1}, {"name":"input","sinks":0,"sources":1},
            {"name":"output","sinks":1,"sources":0}, {"name":"off","sinks":0,"sources":0}]}]
        bridge = object.__new__(audio.Bridge)
        bridge.state = self.state
        bridge.pending = [("setDeviceEnabled", {"id":"7", "direction":direction, "enabled":False})
                          for direction in ("output","input")]
        bridge.dirty_started = bridge.dirty_at = 0
        with patch.object(audio, "command") as execute, patch.object(audio, "emit"):
            bridge.flush_actions()
        self.assertEqual([call.args[0] for call in execute.call_args_list],
                         [["set-card-profile","7","input"], ["set-card-profile","7","off"]])
        self.assertFalse(bridge.state["cards"][0]["outputEnabled"])
        self.assertFalse(bridge.state["cards"][0]["inputEnabled"])

    def test_protocol_errors_refresh_and_shutdown(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            data = fixture()
            (tmp_path / "fixture.json").write_text(json.dumps(data))
            fake = tmp_path / "pactl"
            fake.write_text("""#!/usr/bin/env python3
import json,os,sys,time
from pathlib import Path
data=json.loads(Path(os.environ['AUDIO_FIXTURE']).read_text())
args=sys.argv[1:]
if args==['subscribe']:
    sys.stdout.write("Event 'change' on sink #1\\n"*50);sys.stdout.flush();time.sleep(3)
elif args[:2]==['-f','json']:
    key={'sink-inputs':'sink-inputs','source-outputs':'source-outputs'}.get(args[-1],args[-1])
    if key=='info':
        with open(os.environ['AUDIO_CALLS'],'a') as log: log.write('snapshot\\n')
    if key=='list':
        print(json.dumps({name.replace('-','_'):value for name,value in data.items() if name!='info'}))
    else: print(json.dumps(data[key]))
elif args[:2]==['set-sink-mute','1']:
    print('simulated failure',file=sys.stderr);sys.exit(1)
elif args[0] in ('set-sink-volume','set-sink-formats','kill-sink-input','kill-source-output'):
    with open(os.environ['AUDIO_COMMANDS'],'a') as log: log.write(' '.join(args)+'\\n')
else:
    print('unexpected command',file=sys.stderr);sys.exit(1)
""")
            fake.chmod(0o755)
            env = {**os.environ, "PATH": str(tmp_path) + ":" + os.environ["PATH"],
                   "AUDIO_FIXTURE": str(tmp_path / "fixture.json"),
                   "AUDIO_CALLS": str(tmp_path / "calls"),
                   "AUDIO_COMMANDS": str(tmp_path / "commands")}
            proc = subprocess.Popen([sys.executable, str(BRIDGE)], stdin=subprocess.PIPE,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                                    bufsize=1, env=env)
            try:
                first = self.read_line(proc)
                self.assertEqual(first["type"], "snapshot")
                self.assertEqual(first["defaultOutput"], "sink.a")
                self.assertEqual(self.read_line(proc)["type"], "snapshot")
                time.sleep(.2)
                self.assertEqual((tmp_path / "calls").read_text().count("snapshot"), 2)
                proc.stdin.write('{"action":"setMute","args":{"kind":"output","id":"1","mute":true}}\n')
                proc.stdin.flush()
                messages = [self.read_line(proc) for _ in range(3)]
                self.assertEqual([m["type"] for m in messages], ["busy", "error", "busy"])
                self.assertIn("simulated failure", messages[1]["message"])
                proc.stdin.write('{"action":"refresh"}\n')
                proc.stdin.flush()
                self.assertEqual(self.read_line(proc)["type"], "snapshot")
                batch = "".join(json.dumps({"action": "setVolume", "args": {
                    "kind": "output", "id": "1", "volume": volume}}) + "\n"
                    for volume in (.2, .4, .6))
                proc.stdin.write(batch)
                proc.stdin.flush()
                self.assertEqual([self.read_line(proc)["type"] for _ in range(2)],
                                 ["busy", "busy"])
                self.assertEqual((tmp_path / "commands").read_text().splitlines(),
                                 ["set-sink-volume 1 30.000% 60.000%"])
                self.assertEqual(self.read_line(proc)["type"], "snapshot")
                proc.stdin.write('{"action":"setFormats","args":{"kind":"output","id":"1","formats":["pcm","ac3-iec61937"]}}\n')
                proc.stdin.write('{"action":"killStream","args":{"kind":"playback","id":"4"}}\n')
                proc.stdin.flush()
                self.assertEqual([self.read_line(proc)["type"] for _ in range(2)],
                                 ["busy", "busy"])
                self.assertEqual(self.read_line(proc)["type"], "snapshot")
                self.assertEqual((tmp_path / "commands").read_text().splitlines()[-2:],
                                 ["set-sink-formats 1 pcm;ac3-iec61937", "kill-sink-input 4"])
            finally:
                proc.stdin.close()
                proc.wait(timeout=5)
                self.assertEqual(proc.returncode, 0, proc.stderr.read())
                proc.stdout.close()
                proc.stderr.close()

    def read_line(self, proc):
        deadline = time.monotonic() + 3
        while b"\n" not in self.output:
            ready, _, _ = select.select([proc.stdout], [], [], max(0, deadline - time.monotonic()))
            self.assertTrue(ready, "bridge timed out")
            chunk = os.read(proc.stdout.fileno(), 65536)
            self.assertTrue(chunk, "bridge closed stdout")
            self.output += chunk
        line, self.output = self.output.split(b"\n", 1)
        return json.loads(line)


if __name__ == "__main__":
    unittest.main()
