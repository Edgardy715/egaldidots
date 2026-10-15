#!/usr/bin/env python3
"""Check the session-only driver bridge and normal launch after reboot."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

source = Path(__file__).resolve().parents[2] / "scripts/start-isla.sh"
with tempfile.TemporaryDirectory(prefix="isla-nvidia-launch-") as directory:
    root = Path(directory)
    module = root / "version"
    system = root / "libEGL_nvidia.so.0"
    launcher = root / "start.sh"
    launcher.write_text(source.read_text().replace("/sys/module/nvidia/version", str(module))
                        .replace("/usr/lib/libEGL_nvidia.so.0", str(system)))
    mock = root / "qs"
    mock.write_text("#!/usr/bin/env python3\nimport json,os,sys\n"
                    "print(json.dumps({'args':sys.argv[1:],'env':dict(os.environ)}))\n")
    mock.chmod(0o755)
    env = dict(os.environ, PATH=f"{root}:{os.environ['PATH']}", XDG_DATA_HOME=str(root))
    keys = ("LD_LIBRARY_PATH", "__EGL_VENDOR_LIBRARY_FILENAMES", "GBM_BACKENDS_PATH")
    for key in keys:
        env.pop(key, None)

    def run():
        result = json.loads(subprocess.check_output(["sh", str(launcher), "--verbose"],
                                                   env=env, text=True))
        assert result["args"] == ["-c", "bar", "--no-duplicate", "--verbose"]
        return result["env"]

    # Missing driver/cache preserves normal launch, rather than forcing another GPU.
    assert not any(key in run() for key in keys)
    module.write_text("615.71.09\n")
    assert not any(key in run() for key in keys)
    compat = root / "isla/nvidia-compat/615.71.09"
    library = compat / "usr/lib/libEGL_nvidia.so.615.71.09"
    library.parent.mkdir(parents=True)
    library.touch()
    assert not any(key in run() for key in keys)
    for path in (compat / "usr/share/glvnd/egl_vendor.d/10_nvidia.json",
                 compat / "usr/lib/gbm/nvidia-drm_gbm.so"):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.touch()
    env["LD_LIBRARY_PATH"] = "/existing"
    active = run()
    assert active["LD_LIBRARY_PATH"] == f"{compat}/usr/lib:/existing"
    assert active["GBM_BACKENDS_PATH"] == f"{compat}/usr/lib/gbm"
    assert active["__EGL_VENDOR_LIBRARY_FILENAMES"] == f"{compat}/usr/share/glvnd/egl_vendor.d/10_nvidia.json"
    system.symlink_to("/usr/lib/libEGL_nvidia.so.615.71.09")
    assert run()["LD_LIBRARY_PATH"] == "/existing"
    assert "__EGL_VENDOR_LIBRARY_FILENAMES" not in run()
    module.write_text("615.78.08\n")
    assert run()["LD_LIBRARY_PATH"] == "/existing"

print("PASS: missing driver/cache, partial cache, mismatch, matching driver, reboot and forwarded args")
