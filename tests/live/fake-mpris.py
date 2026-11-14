#!/usr/bin/env python3
"""A pretend MPRIS player for the nested tests: playing, with a title, an
artist, a cover and a moving position.

    fake-mpris.py <title> <artist> <length-seconds> [cover-path]
    fake-mpris.py <title> <artist> <length> [cover] -- <title> <artist> <length> [cover] …

Several at once: FAKE_MPRIS_NAME=<bus name suffix> FAKE_MPRIS_IDENTITY=<name>.
With several tracks (split by --) Next and Previous walk through them, each
with its own artist, length and cover, the position starting over.
"""
import os
import sys
import time

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

ROOT, PLAYER, PROPS = "org.mpris.MediaPlayer2", "org.mpris.MediaPlayer2.Player", "org.freedesktop.DBus.Properties"


class Player(dbus.service.Object):
    def __init__(self, bus, tracks):
        super().__init__(bus, "/org/mpris/MediaPlayer2")
        self.start = time.monotonic()
        self.held = 0.0            # the position while paused
        self.playing = True
        self.tracks = tracks
        if len(tracks) == 1:       # one track: the old three titles
            t = tracks[0]
            self.tracks = [t, dict(t, title="A much longer title for the next track, to change the width"), dict(t, title="Short")]
        self.track = 0
        self.meta = self._meta()

    def _meta(self):
        t = self.tracks[self.track]
        return dbus.Dictionary({
            "mpris:trackid": dbus.ObjectPath("/vitrum/track/%d" % (self.track + 1)),
            "mpris:length": dbus.Int64(int(t["length"] * 1e6)),
            "xesam:title": t["title"], "xesam:artist": dbus.Array([t["artist"]], signature="s"),
            "xesam:album": "Test", "mpris:artUrl": ("file://" + t["cover"]) if t["cover"] else "",
        }, signature="sv")

    def _pos(self):
        return (time.monotonic() - self.start) if self.playing else self.held

    def _go(self, step):
        self.track = (self.track + step) % len(self.tracks)
        self.start, self.held = time.monotonic(), 0.0
        self.meta = self._meta()
        self.PropertiesChanged(PLAYER, {"Metadata": self.meta}, [])
        self.Seeked(0)

    def _props(self, iface):
        if iface == ROOT:
            return {"Identity": os.environ.get("FAKE_MPRIS_IDENTITY", "Fake player"), "CanQuit": False, "CanRaise": False, "HasTrackList": False,
                    "SupportedUriSchemes": dbus.Array([], signature="s"), "SupportedMimeTypes": dbus.Array([], signature="s")}
        return {"PlaybackStatus": "Playing" if self.playing else "Paused", "Metadata": self.meta, "Volume": 1.0,
                "Position": dbus.Int64(int(self._pos() * 1e6)),
                "Rate": 1.0, "MinimumRate": 1.0, "MaximumRate": 1.0, "LoopStatus": "None", "Shuffle": False,
                "CanGoNext": True, "CanGoPrevious": True, "CanPlay": True, "CanPause": True, "CanSeek": True, "CanControl": True}

    @dbus.service.method(PROPS, in_signature="ss", out_signature="v")
    def Get(self, iface, prop):
        return self._props(iface)[prop]

    @dbus.service.method(PROPS, in_signature="s", out_signature="a{sv}")
    def GetAll(self, iface):
        return self._props(iface)

    @dbus.service.method(PROPS, in_signature="ssv")
    def Set(self, iface, prop, value):
        pass

    @dbus.service.signal(PROPS, signature="sa{sv}as")
    def PropertiesChanged(self, iface, changed, invalidated):
        pass

    @dbus.service.method(PLAYER)
    def PlayPause(self):
        if self.playing:
            self.held = self._pos()
        else:
            self.start = time.monotonic() - self.held
        self.playing = not self.playing
        self.PropertiesChanged(PLAYER, {"PlaybackStatus": "Playing" if self.playing else "Paused"}, [])

    @dbus.service.method(PLAYER)
    def Pause(self):
        if self.playing:
            self.PlayPause()

    @dbus.service.method(PLAYER)
    def Play(self):
        if not self.playing:
            self.PlayPause()

    @dbus.service.method(PLAYER)
    def Next(self):
        self._go(1)

    @dbus.service.method(PLAYER)
    def Previous(self):
        self._go(-1)

    @dbus.service.method(PLAYER, in_signature="x")
    def Seek(self, offset):
        self._seek(self._pos() + offset / 1e6)

    @dbus.service.method(PLAYER, in_signature="ox")
    def SetPosition(self, track, position):
        self._seek(position / 1e6)

    def _seek(self, seconds):
        seconds = max(0.0, seconds)
        self.start, self.held = time.monotonic() - seconds, seconds
        self.Seeked(dbus.Int64(int(seconds * 1e6)))

    @dbus.service.signal(PLAYER, signature="x")
    def Seeked(self, pos):
        pass


def main():
    tracks, args = [], sys.argv[1:]
    while args:
        cut = args.index("--") if "--" in args else len(args)
        one, args = args[:cut], args[cut + 1:]
        tracks.append({"title": one[0], "artist": one[1], "length": float(one[2]), "cover": one[3] if len(one) > 3 else ""})
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    # FAKE_MPRIS_NAME: another bus name, for several at once; FAKE_MPRIS_IDENTITY: what it calls itself.
    name = dbus.service.BusName("org.mpris.MediaPlayer2." + os.environ.get("FAKE_MPRIS_NAME", "vitrumfake"), bus)  # noqa: F841
    Player(bus, tracks)
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
