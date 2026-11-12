#!/usr/bin/env python3
"""Dependency-free virtual pointer for native Wayland QA (zwlr_virtual_pointer_v1).

Speaks the Wayland wire protocol directly, so QA can press, drag, release and scroll
on real layer surfaces without ydotool/uinput. Coordinates are layout pixels.

    python bar/tests/vpointer.py script.json      # list of steps (see below)
    python bar/tests/vpointer.py drag 960 18 960 400 --ms 300

Steps: {"move":[x,y]}, {"down":1}, {"up":1}, {"wait":ms},
       {"scroll":dy, "finger":true}  (finger = touchpad-like continuous axis), {"scrollend":1}
"""
import json, os, socket, struct, sys, time

def _str(s):
    b = s.encode() + b"\0"
    return struct.pack("<I", len(b)) + b + b"\0" * ((4 - len(b) % 4) % 4)

def _fixed(v):
    return struct.pack("<i", int(round(v * 256)))

class Wl:
    def __init__(self):
        path = os.path.join(os.environ["XDG_RUNTIME_DIR"], os.environ.get("WAYLAND_DISPLAY", "wayland-0"))
        self.s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.s.connect(path)
        self.next_id = 2
        self.buf = b""
        self.globals = {}

    def new_id(self):
        i = self.next_id; self.next_id += 1; return i

    def send(self, obj, op, payload=b""):
        self.s.sendall(struct.pack("<II", obj, ((8 + len(payload)) << 16) | op) + payload)

    def roundtrip(self):
        cb = self.new_id()
        self.send(1, 0, struct.pack("<I", cb))  # wl_display.sync
        while True:
            obj, op, body = self.read()
            if obj == self.registry and op == 0:  # global
                name, = struct.unpack_from("<I", body, 0)
                ln, = struct.unpack_from("<I", body, 4)
                iface = body[8:8 + ln - 1].decode()
                ver, = struct.unpack_from("<I", body, 8 + ((ln + 3) & ~3))
                self.globals[iface] = (name, ver)
            elif obj == 1 and op == 0:  # wl_display.error
                raise RuntimeError("wayland error: %r" % body)
            elif obj == cb and op == 0:
                return

    def read(self):
        while len(self.buf) < 8 or len(self.buf) < (struct.unpack_from("<I", self.buf, 4)[0] >> 16):
            chunk = self.s.recv(65536)
            if not chunk: raise RuntimeError("compositor closed the connection")
            self.buf += chunk
        obj, word = struct.unpack_from("<II", self.buf, 0)
        size = word >> 16
        body = self.buf[8:size]; self.buf = self.buf[size:]
        return obj, word & 0xffff, body

    def bind(self, iface, version):
        name, ver = self.globals[iface]
        i = self.new_id()
        self.send(self.registry, 0, struct.pack("<I", name) + _str(iface) + struct.pack("<II", min(ver, version), i))
        return i

class Pointer:
    BTN_LEFT = 0x110
    def __init__(self):
        self.wl = Wl()
        self.wl.registry = self.wl.new_id()
        self.wl.send(1, 1, struct.pack("<I", self.wl.registry))  # get_registry
        self.wl.roundtrip()
        if "zwlr_virtual_pointer_manager_v1" not in self.wl.globals:
            raise SystemExit("compositor lacks zwlr_virtual_pointer_manager_v1")
        mgr = self.wl.bind("zwlr_virtual_pointer_manager_v1", 1)
        self.p = self.wl.new_id()
        self.wl.send(mgr, 0, struct.pack("<II", 0, self.p))  # create_virtual_pointer(seat=null)
        self.wl.roundtrip()
        self.extent = self._layout()

    @staticmethod
    def _layout():
        import subprocess
        mons = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"]))
        w = max(m["x"] + int(m["width"] / m["scale"]) for m in mons)
        h = max(m["y"] + int(m["height"] / m["scale"]) for m in mons)
        return w, h

    def t(self): return int(time.monotonic() * 1000) & 0xffffffff

    def move(self, x, y):
        self.wl.send(self.p, 1, struct.pack("<IIIII", self.t(), int(x), int(y), *self.extent))
        self.frame()

    def button(self, down):
        self.wl.send(self.p, 2, struct.pack("<III", self.t(), self.BTN_LEFT, 1 if down else 0))
        self.frame()

    def scroll(self, dy, finger=True):
        if finger: self.wl.send(self.p, 5, struct.pack("<I", 1))  # axis_source finger
        self.wl.send(self.p, 3, struct.pack("<II", self.t(), 0) + _fixed(dy))
        self.frame()

    def scroll_end(self):
        self.wl.send(self.p, 5, struct.pack("<I", 1))
        self.wl.send(self.p, 6, struct.pack("<II", self.t(), 0))  # axis_stop
        self.frame()

    def frame(self):
        self.wl.send(self.p, 4)
        self.wl.roundtrip()

def run(steps):
    p = Pointer()
    for st in steps:
        if "move" in st: p.move(*st["move"])
        elif "down" in st: p.button(True)
        elif "up" in st: p.button(False)
        elif "wait" in st: time.sleep(st["wait"] / 1000)
        elif "scroll" in st: p.scroll(st["scroll"], st.get("finger", True))
        elif "scrollend" in st: p.scroll_end()

def drag(x0, y0, x1, y1, ms=300, hz=120, hold=0):
    steps = [{"move": [x0, y0]}, {"wait": 60}, {"down": 1}]
    n = max(1, int(ms * hz / 1000))
    for i in range(1, n + 1):
        k = i / n
        steps += [{"move": [x0 + (x1 - x0) * k, y0 + (y1 - y0) * k]}, {"wait": 1000 / hz}]
    if hold: steps.append({"wait": hold})
    steps.append({"up": 1})
    return steps

if __name__ == "__main__":
    a = sys.argv[1:]
    if a and a[0] == "drag":
        ms = int(a[a.index("--ms") + 1]) if "--ms" in a else 300
        hold = int(a[a.index("--hold") + 1]) if "--hold" in a else 0
        run(drag(*map(float, a[1:5]), ms=ms, hold=hold))
    elif a:
        run(json.load(open(a[0])))
    else:
        print(__doc__)
