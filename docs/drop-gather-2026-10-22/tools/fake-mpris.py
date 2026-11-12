# Silent fake MPRIS player for visual QA: no audio, only D-Bus state.
import gi, time
gi.require_version('Gio', '2.0')
from gi.repository import Gio, GLib
XML = """<node>
<interface name="org.mpris.MediaPlayer2">
 <method name="Raise"/><method name="Quit"/>
 <property name="CanQuit" type="b" access="read"/><property name="CanRaise" type="b" access="read"/>
 <property name="HasTrackList" type="b" access="read"/><property name="Identity" type="s" access="read"/>
 <property name="DesktopEntry" type="s" access="read"/>
 <property name="SupportedUriSchemes" type="as" access="read"/><property name="SupportedMimeTypes" type="as" access="read"/>
</interface>
<interface name="org.mpris.MediaPlayer2.Player">
 <method name="Next"/><method name="Previous"/><method name="Pause"/><method name="PlayPause"/>
 <method name="Stop"/><method name="Play"/>
 <method name="Seek"><arg direction="in" name="Offset" type="x"/></method>
 <method name="SetPosition"><arg direction="in" name="TrackId" type="o"/><arg direction="in" name="Position" type="x"/></method>
 <method name="OpenUri"><arg direction="in" name="Uri" type="s"/></method>
 <signal name="Seeked"><arg name="Position" type="x"/></signal>
 <property name="PlaybackStatus" type="s" access="read"/><property name="LoopStatus" type="s" access="readwrite"/>
 <property name="Rate" type="d" access="readwrite"/><property name="Shuffle" type="b" access="readwrite"/>
 <property name="Metadata" type="a{sv}" access="read"/><property name="Volume" type="d" access="readwrite"/>
 <property name="Position" type="x" access="read"/><property name="MinimumRate" type="d" access="read"/>
 <property name="MaximumRate" type="d" access="read"/><property name="CanGoNext" type="b" access="read"/>
 <property name="CanGoPrevious" type="b" access="read"/><property name="CanPlay" type="b" access="read"/>
 <property name="CanPause" type="b" access="read"/><property name="CanSeek" type="b" access="read"/>
 <property name="CanControl" type="b" access="read"/>
</interface></node>"""
t0 = time.monotonic()
def props():
    return {
        "CanQuit": GLib.Variant("b", False), "CanRaise": GLib.Variant("b", False),
        "HasTrackList": GLib.Variant("b", False), "Identity": GLib.Variant("s", "Isla Sim"),
        "DesktopEntry": GLib.Variant("s", "islasim"),
        "SupportedUriSchemes": GLib.Variant("as", []), "SupportedMimeTypes": GLib.Variant("as", []),
        "PlaybackStatus": GLib.Variant("s", "Playing"), "LoopStatus": GLib.Variant("s", "None"),
        "Rate": GLib.Variant("d", 1.0), "Shuffle": GLib.Variant("b", False), "Volume": GLib.Variant("d", 1.0),
        "Metadata": GLib.Variant("a{sv}", {
            "mpris:trackid": GLib.Variant("o", "/org/islasim/track/1"),
            "mpris:length": GLib.Variant("x", 214_000_000),
            "xesam:title": GLib.Variant("s", "Canción simulada"),
            "xesam:artist": GLib.Variant("as", ["Isla QA"]),
            "xesam:album": GLib.Variant("s", "Prueba visual")}),
        "Position": GLib.Variant("x", int((time.monotonic() - t0) * 1e6)),
        "MinimumRate": GLib.Variant("d", 1.0), "MaximumRate": GLib.Variant("d", 1.0),
        "CanGoNext": GLib.Variant("b", True), "CanGoPrevious": GLib.Variant("b", True),
        "CanPlay": GLib.Variant("b", True), "CanPause": GLib.Variant("b", True),
        "CanSeek": GLib.Variant("b", False), "CanControl": GLib.Variant("b", True)}
node = Gio.DBusNodeInfo.new_for_xml(XML)
def call(conn, sender, path, iface, method, params, inv):
    if method == "Get":
        inv.return_value(GLib.Variant("(v)", (props()[params[1]],)))
    elif method == "GetAll":
        inv.return_value(GLib.Variant("(a{sv})", (props(),)))
    else:
        inv.return_value(None)
def get_prop(conn, sender, path, iface, name):
    return props()[name]
def on_bus(conn, name):
    for i in node.interfaces:
        conn.register_object("/org/mpris/MediaPlayer2", i, call, get_prop, None)
Gio.bus_own_name(Gio.BusType.SESSION, "org.mpris.MediaPlayer2.islasim", 0, on_bus, None, None)
GLib.MainLoop().run()
