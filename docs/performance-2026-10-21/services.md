# Service performance baseline and audio rebind

## Pipewire status observers

The baseline `bar/Singletons/DesktopStatus.qml` compared default sink/source and
their audio objects every 500 ms while `monitorServices` was enabled. The
Pipewire type metadata installed at
`/usr/lib/qt6/qml/Quickshell/Services/Pipewire/quickshell-service-pipewire.qmltypes`
declares `defaultAudioSinkChanged` and `defaultAudioSourceChanged` notifications
(properties at lines 49–65). `PwNode.audio` is constant for its node (lines
450–458); its `properties` changes notify separately, and `PwNodeAudio.volume`
and `muted` notify through `volumesChanged` and `mutedChanged` (lines 327–367).

`DesktopStatus.qml` now binds each default node and its audio interface directly
to those properties. Its `Connections` targets follow the bindings, so device
replacement and removal retarget observers immediately. OSD reads and volume
adjustments use the same bound node. `PwObjectTracker` and the
`monitorServices` gate remain in place.

The removed 500 ms timer had a deterministic schedule of two callbacks per
second whenever services were monitored. The new audio rebind path has no
periodic callbacks; this is a count derived from the old/new code, not a CPU,
power, or end-to-end latency measurement. Caps Lock polling remains unchanged.

`bar/desktop-status-audio-rebind-regression.qml` uses mock QObject nodes and
audio objects to cover mute/volume events, sink/source replacement, disconnect,
and disabled/re-enabled observers without using the host audio server.
Offscreen regression passed. Real Pipewire device hotplug and physical audio
hardware were not exercised.
