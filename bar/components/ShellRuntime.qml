import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../Singletons"

// Desktop services are adapted here; SurfaceRouter keeps navigation state only.
Item {
    id: root
    required property SurfaceRouter router

    Binding {
        target: root.router; property: "focusedMonitorName"
        value: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    }
    Binding { target: root.router; property: "reduceMotion"; value: Flags.reduceMotion }
    Binding { target: root.router; property: "resultsDuration"; value: Motion.standard }
    Binding { target: root.router; property: "morphDuration"; value: Motion.morph }

    Connections {
        target: root.router
        function onAuthCloseRequested() {
            if (Auth.sudoActive) Auth.cancelSudo()
            if (Auth.active) Auth.cancel()
        }
        function onOpenSurfaceChanged() {
            WinMap.active = root.router.openSurface === "overview"
            if (WinMap.active) WinMap.updateAll()
            Notifs.centerOpen = root.router.openSurface === "notifs"
        }
    }

    Component.onCompleted: {
        // Hyprland loads its models on connection; an initial refresh can race it.
        Config.loaded
        Brightness.available
        Session.lockCmd
        Auth.active
        KeepAwake.enabled
    }

    Binding {
        target: Auth; property: "polkitFeedbackDuration"
        value: Flags.reduceMotion ? 220 : Math.max(750, Motion.morph + Motion.iconSwap + Motion.fast)
    }
    Binding {
        target: Auth; property: "sudoFeedbackDuration"
        value: Flags.reduceMotion ? 220 : Math.max(1100, Motion.morph + Motion.iconSwap + Motion.fast)
    }

    // Polkit and the sudo askpass bridge present through the same router.
    Connections {
        target: Auth
        function openAuthSurface() {
            var mon = Hyprland.focusedMonitor
            if (!mon && Quickshell.screens.length > 0)
                mon = Quickshell.screens[0]
            root.router.present(mon ? mon.name : "", "auth")
            console.log("[Auth] surface monitor:", root.router.openMon)
        }
        function onAuthenticationRequestStarted() {
            openAuthSurface()
        }
        function onSudoRequestStarted() {
            console.log("[Auth] opening sudo surface")
            openAuthSurface()
        }
        function onPresentingChanged() {
            if (Auth.presenting) {
                if (root.router.openSurface !== "auth") openAuthSurface()
            } else if (root.router.openSurface === "auth") root.router.close()
        }
    }

    // Only raw events that change rendered state require a model refresh.
    readonly property var refreshEvents: ({
        workspace: true, workspacev2: true,
        createworkspace: true, createworkspacev2: true,
        destroyworkspace: true, destroyworkspacev2: true,
        moveworkspace: true, moveworkspacev2: true,
        renameworkspace: true, activespecial: true,
        focusedmon: true, focusedmonv2: true,
        openwindow: true, closewindow: true,
        movewindow: true, movewindowv2: true,
        fullscreen: true,
        monitoradded: true, monitoraddedv2: true, monitorremoved: true
    })

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!root.refreshEvents[event.name]) return
            Hyprland.refreshMonitors()
            Hyprland.refreshWorkspaces()
            Hyprland.refreshToplevels()
        }
    }
}
