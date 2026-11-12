import dbus,dbus.service,sys
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
DBusGMainLoop(set_as_default=True)
name=sys.argv[1]; mode=sys.argv[2]
bus=dbus.SessionBus(); bus_name=dbus.service.BusName("org.mpris.MediaPlayer2."+name,bus)
M={"normal":{"xesam:title":"Tema normal","xesam:artist":["Artista"],"mpris:length":dbus.Int64(180_000_000)},
"noinfo":{},
"zero":{"xesam:title":"Duración cero","mpris:length":dbus.Int64(0)},
"huge":{"xesam:title":"T"*3000+"‮rtl","xesam:artist":["A"*2000],"xesam:album":"Al\"b'${x}%s","mpris:length":dbus.Int64(2**62)},
"neg":{"xesam:title":"Negativa","mpris:length":dbus.Int64(-5)},
"badart":{"xesam:title":"Arte roto","mpris:artUrl":"file:///no/existe.png","mpris:length":dbus.Int64(60_000_000)}}
md=M[mode]
class P(dbus.service.Object):
    pos=0; st="Playing"
    def __init__(s): super().__init__(bus_name,"/org/mpris/MediaPlayer2")
    @dbus.service.method("org.freedesktop.DBus.Properties",in_signature="ss",out_signature="v")
    def Get(s,i,p): return s.GetAll(i)[p]
    @dbus.service.method("org.freedesktop.DBus.Properties",in_signature="s",out_signature="a{sv}")
    def GetAll(s,i):
        if i=="org.mpris.MediaPlayer2": return {"CanQuit":True,"CanRaise":False,"HasTrackList":False,"Identity":"QA "+name,"SupportedUriSchemes":["file"],"SupportedMimeTypes":["audio/mpeg"]}
        return {"PlaybackStatus":s.st,"Metadata":dbus.Dictionary(md,signature="sv"),"Position":dbus.Int64(s.pos),"Rate":1.0,"Volume":1.0,"CanPlay":True,"CanPause":True,"CanSeek":True,"CanGoNext":True,"CanGoPrevious":True,"CanControl":True,"MinimumRate":1.0,"MaximumRate":1.0}
    @dbus.service.method("org.freedesktop.DBus.Properties",in_signature="ssv")
    def Set(s,i,p,v): pass
    @dbus.service.signal("org.freedesktop.DBus.Properties",signature="sa{sv}as")
    def PropertiesChanged(s,i,c,inv): pass
    @dbus.service.method("org.mpris.MediaPlayer2.Player")
    def PlayPause(s): s.st="Paused" if s.st=="Playing" else "Playing"; s.PropertiesChanged("org.mpris.MediaPlayer2.Player",{"PlaybackStatus":s.st},[])
    @dbus.service.method("org.mpris.MediaPlayer2.Player")
    def Next(s): pass
    @dbus.service.method("org.mpris.MediaPlayer2.Player")
    def Previous(s): pass
    @dbus.service.method("org.mpris.MediaPlayer2.Player")
    def Play(s): pass
    @dbus.service.method("org.mpris.MediaPlayer2.Player")
    def Pause(s): pass
    @dbus.service.method("org.mpris.MediaPlayer2.Player",in_signature="x")
    def Seek(s,o): s.pos+=o
    @dbus.service.method("org.mpris.MediaPlayer2.Player",in_signature="ox")
    def SetPosition(s,t,p): s.pos=p
    @dbus.service.method("org.mpris.MediaPlayer2")
    def Quit(s): loop.quit()
P(); loop=GLib.MainLoop(); loop.run()
