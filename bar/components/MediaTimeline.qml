/*
 * Copyright (C) 2022 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * Adapted for Isla/QML from Android 16 SystemUI: SquigglyProgress.kt
 * and SeekBarObserver.kt (android16-release, frameworks/base/packages/SystemUI).
 * Changes: QML geometry/animation, desktop input, Theme roles and MPRIS integration.
 * License: docs/pixel-media-timeline-2026-10-14/LICENSE-AOSP.txt.
 */

pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../Singletons"

Item {
    id: root
    property real s: 1
    property bool active: false
    property bool playing: false
    property bool dragging: false
    property real progress: 0
    property real position: 0
    property real length: 0
    property string displayTime: ""
    signal seekRequested(real position)
    signal dragStarted(real fraction)
    signal dragMoved(real fraction)
    signal dragCommitted(real fraction)
    signal dragCanceled()

    readonly property real boundedProgress: isFinite(progress) ? Math.max(0, Math.min(1, progress)) : 0
    property real displayedProgress: 0
    readonly property real trackInset: 7 * s
    readonly property real trackWidth: Math.max(1, width - 2 * trackInset)
    readonly property real cursorX: trackInset + trackWidth * displayedProgress
    // Android 16 SystemUI SquigglyProgress / SeekBarObserver (seekable track).
    readonly property real wavelength: 20 * s
    readonly property real amplitude: 1.5 * s
    readonly property real strokeWidth: 2 * s
    readonly property real phaseSpeed: 8 * s
    readonly property bool motionAllowed: active && visible && !Flags.reduceMotion
    readonly property bool moving: motionAllowed && playing && !dragging
    property real waveOffset: 0
    property real waveAmount: 0
    function fractionAt(x) { return Math.max(0, Math.min(1, (x - trackInset) / trackWidth)) }
    function updateProgress() {
        if (dragging || !motionAllowed || length <= 0) {
            progressReset.stop()
            displayedProgress = boundedProgress
        } else if (boundedProgress * length <= 0.25 && displayedProgress * length > 0.25) {
            progressReset.stop()
            progressReset.from = displayedProgress
            progressReset.to = Math.min(1, boundedProgress + 0.75 / length)
            progressReset.start()
        } else if (!progressReset.running) displayedProgress = boundedProgress
    }
    onBoundedProgressChanged: {
        if (dragging || !motionAllowed) updateProgress()
        // MPRIS commits update dragging and position in the same event turn.
        else Qt.callLater(updateProgress)
    }
    onDraggingChanged: {
        progressReset.stop()
        displayedProgress = boundedProgress
    }
    NumberAnimation {
        id: progressReset
        target: root
        property: "displayedProgress"
        duration: 750
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.05, 0, 0.133333, 0.06, 0.166666, 0.4,
            0.208333, 0.82, 0.25, 1, 1, 1]
        onFinished: root.displayedProgress = root.boundedProgress
    }

    function updateWave() {
        amplitudeDelay.stop()
        amplitudeAnimation.stop()
        if (!motionAllowed) waveAmount = 0
        else if (moving) amplitudeDelay.start()
        else animateAmplitude()
    }
    function animateAmplitude() {
        amplitudeAnimation.from = waveAmount
        amplitudeAnimation.to = moving ? 1 : 0
        amplitudeAnimation.duration = moving ? 800 : 550
        amplitudeAnimation.easing.bezierCurve = moving ? Motion.emphasizedDecelCurve : Motion.standardDecelCurve
        amplitudeAnimation.start()
    }
    onMovingChanged: updateWave()
    onMotionAllowedChanged: if (!motionAllowed) { updateWave(); updateProgress() }
    Component.onCompleted: { displayedProgress = boundedProgress; updateWave() }
    Timer {
        id: amplitudeDelay
        interval: 60
        onTriggered: root.animateAmplitude()
    }
    NumberAnimation {
        id: amplitudeAnimation
        target: root
        property: "waveAmount"
        easing.type: Easing.BezierSpline
    }
    FrameAnimation {
        running: root.moving
        onTriggered: root.waveOffset = (root.waveOffset + frameTime * root.phaseSpeed) % root.wavelength
    }
    Rectangle {
        anchors.fill: parent
        radius: 8 * root.s
        color: "transparent"
        border.width: input.activeFocus ? Theme.borderHairline : 0
        border.color: Theme.accent
    }
    Rectangle {
        x: root.cursorX
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, root.width - root.trackInset - x)
        height: root.strokeWidth
        radius: height / 2
        color: Qt.alpha(Theme.accent, 77 / 255)
    }
    Item {
        x: root.trackInset
        width: Math.max(0, root.cursorX - x)
        height: parent.height
        clip: true
        Shape {
            y: parent.height / 2
            width: root.trackWidth + 1.5 * root.wavelength
            height: 1
            preferredRendererType: Shape.CurveRenderer
            transform: Translate { x: -root.waveOffset - root.wavelength / 2 }
            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.accent
                strokeWidth: root.strokeWidth
                capStyle: ShapePath.RoundCap
                PathSvg {
                    // Geometry changes only while amplitude settles; phase uses translation.
                    path: {
                        const wave = root.wavelength
                        const amplitude = root.amplitude * root.waveAmount
                        let result = "M 0 0"
                        let currentAmp = amplitude
                        for (let x = 0; x < root.trackWidth + 1.5 * wave; x += wave / 2) {
                            const nextAmp = -currentAmp
                            const mid = x + wave / 4
                            result += " C " + mid + " " + currentAmp
                                + " " + mid + " " + nextAmp + " " + (x + wave / 2) + " " + nextAmp
                            currentAmp = nextAmp
                        }
                        return result
                    }
                }
            }
        }
    }
    Rectangle {
        // Restore the rounded start cap removed by the progress clip, as in AOSP.
        x: root.trackInset - width / 2
        y: root.height / 2 + Math.cos((root.waveOffset + root.wavelength / 2)
            / root.wavelength * Math.PI * 2) * root.amplitude * root.waveAmount - height / 2
        width: root.strokeWidth
        height: width
        radius: width / 2
        color: Theme.accent
    }
    Rectangle {
        layer.enabled: root.visible && root.enabled
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.alpha(Theme.accent, 0.75)
            shadowBlur: 0.7
            blurMax: 12
        }
        x: root.cursorX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 4 * root.s
        height: 16 * root.s
        radius: width / 2
        color: Theme.foreground
    }
    MouseArea {
        id: input
        objectName: "mediaSeek"
        anchors.fill: parent
        hoverEnabled: true
        activeFocusOnTab: true
        Accessible.role: Accessible.Slider
        Accessible.name: qsTr("Posición de reproducción")
        Accessible.description: root.displayTime
        Accessible.onIncreaseAction: root.seekRequested(root.position + 5)
        Accessible.onDecreaseAction: root.seekRequested(root.position - 5)
        Keys.onLeftPressed: root.seekRequested(root.position - 5)
        Keys.onRightPressed: root.seekRequested(root.position + 5)
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Home) root.seekRequested(0)
            else if (event.key === Qt.Key_End) root.seekRequested(root.length)
            else return
            event.accepted = true
        }
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => { forceActiveFocus(); root.dragStarted(root.fractionAt(mouse.x)) }
        onPositionChanged: mouse => { if (root.dragging) root.dragMoved(root.fractionAt(mouse.x)) }
        onReleased: mouse => root.dragCommitted(root.fractionAt(mouse.x))
        onCanceled: root.dragCanceled()
    }
}
