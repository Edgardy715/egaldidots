import QtQuick
import QtTest
import Quickshell
import "components"
import "Singletons"

// Tidemark, Fase 0: tokens, SpringValue y LevelStroke. Estado final, interrupción
// con memoria de velocidad, reduceMotion y oculto = quieto. Offscreen no es QA visual.
ShellRoot {
    settings.watchFiles: false
    Window {
        id: win
        visible: true; width: 300; height: 200; color: Theme.background
        SpringValue { id: sv; manualStep: true; spring: Motion.strokeSpring.wave }
        SpringValue { id: svFast; manualStep: true; spring: Motion.strokeSpring.level }
        VolumeGlyph { id: glyph; size: 24; y: 60 }
        PlayPauseGlyph { id: pp; size: 24; y: 100 }
        LockGlyph { id: lock; size: 24; y: 140 }
        BatteryIndicator { id: bat; s: 2; level: 0.6; x: 200; y: 60 }
        PlusCheckGlyph { id: plusCheck; size: 24; x: 100; y: 100 }
        RadioGlyph { id: radio; kind: "wifi"; size: 24; x: 140; y: 100 }
        RadioGlyph { id: radioBt; kind: "bluetooth"; size: 24; x: 180; y: 100 }
        RadioGlyph { id: radioKind; kind: "wifi"; on: false; size: 24; x: 220; y: 100 }
        MediaTransportButton { id: transport; primary: true; iconName: "play_arrow"; x: 240; y: 100 }
        TimeRing { id: ring; y: 180; active: false }
        LevelDial { id: dial; x: 60; y: 60; diameter: 30 }
        Row {
            spacing: 20
            LevelStroke { id: line; width: 96; height: 8; tide: true; head: true }
            LevelStroke { id: arc; shape: "arc"; width: 48; height: 48 }
        }
        TestCase {
            name: "Tidemark"; when: win.visible
            function advance(spring, seconds) {
                for (let i = 0; i < seconds * 60; ++i) spring.step(1 / 60)
            }
            function test_tokens() {
                compare(Theme.signalSuccess.toString(), "#32d975")
                compare(Theme.signalError.toString(), "#ff4d61")
                compare(Motion.strokeDraw, Motion.standard)
                compare(Motion.strokeErase, Motion.fast)
                for (const k of ["wave","cone","mute","level","tide","split","lift","swing","seat","hole","morph","radio"]) {
                    verify(Motion.strokeSpring[k].omega > 0, k)
                    verify(Motion.strokeSpring[k].zeta > 0, k)
                }
                completed++
            }
            function test_spring_settles() {
                Config.update({appearance:{reduceMotion:false}})
                sv.snap(0); sv.target = 1
                verify(sv.integrating)
                advance(sv, 0.1)
                verify(sv.value > 0 && sv.value < 1, "en vuelo: " + sv.value)
                advance(sv, 3)
                compare(sv.value, 1); compare(sv.velocity, 0)
                verify(!sv.integrating)
                completed++
            }
            function test_spring_interrupt_keeps_velocity() {
                sv.snap(0); sv.target = 1
                advance(sv, 0.12)
                const x = sv.value, v = sv.velocity
                verify(v > 0)
                sv.target = 0                    // cambia de destino a mitad
                compare(sv.value, x); compare(sv.velocity, v) // parte del estado actual
                sv.step(1 / 240)
                verify(sv.value > x - 0.0001, "la inercia sigue un instante hacia el destino viejo")
                advance(sv, 4)
                compare(sv.value, 0)
                completed++
            }
            function test_reduce_motion_and_hidden() {
                Config.update({appearance:{reduceMotion:true}}); wait(20)
                sv.target = 0.5
                compare(sv.value, 0.5); verify(!sv.integrating)
                Config.update({appearance:{reduceMotion:false}}); wait(20)
                sv.active = false
                sv.target = 0.9
                compare(sv.value, 0.9); verify(!sv.integrating)
                sv.kick(5); verify(!sv.integrating)
                sv.active = true
                completed++
            }
            function test_level_stroke() {
                Config.update({appearance:{reduceMotion:false}}); wait(20)
                line.value = 0.8
                wait(40)
                verify(line.shown > 0 && line.shown < 0.8, "sigue al valor con muelle: " + line.shown)
                verify(line.leading, "la cabeza acompaña mientras crece")
                wait(900)
                verify(Math.abs(line.shown - 0.8) < 0.002)
                verify(!line.leading)
                line.value = 0.2
                wait(60)
                verify(line.tideShown > line.shown, "la marca de marea queda arriba")
                verify(!line.leading)
                wait(Motion.strokeTideHold + 3500)
                verify(Math.abs(line.tideShown - 0.2) < 0.01, "la marca baja: " + line.tideShown)
                arc.value = 0.5; wait(900)
                verify(Math.abs(arc.shown - 0.5) < 0.002)
                compare(arc.value, 0.5)
                completed++
            }
            function test_level_stroke_reduced_and_hidden() {
                Config.update({appearance:{reduceMotion:true}}); wait(20)
                line.value = 1
                compare(line.shown, 1); compare(line.tideShown, 1)
                line.value = 0.3
                compare(line.shown, 0.3); compare(line.tideShown, 0.3)
                Config.update({appearance:{reduceMotion:false}}); wait(20)
                line.visible = false
                line.value = 0.9
                compare(line.shown, 0.9) // oculto: sin animación
                verify(line.value === 0.9)
                line.visible = true
                completed++
            }
            function test_volume_glyph_mute() {
                Config.update({appearance:{reduceMotion:false}}); wait(20)
                glyph.muted = false; glyph.level = 0.9; wait(1000)
                for (let i = 0; i < 3; ++i) verify(glyph.waveExtent(i) > 0.98, "onda " + i)
                compare(glyph.muteAmount, 0)
                glyph.muted = true; wait(60)
                verify(glyph.muteAmount > 0 && glyph.muteAmount < 1, "mute a mitad: " + glyph.muteAmount)
                wait(1000)
                verify(Math.abs(glyph.muteAmount - 1) < 0.01)
                glyph.muted = false; wait(60)
                verify(glyph.muteAmount > 0 && glyph.muteAmount < 1, "vuelve a onda: " + glyph.muteAmount)
                wait(1000)
                compare(glyph.muteAmount, 0)
                completed++
            }
            function test_volume_glyph_thresholds_and_reduce() {
                glyph.level = 0.2; wait(1000)
                verify(glyph.waveExtent(0) > 0.98); verify(glyph.waveExtent(1) < 0.02); verify(glyph.waveExtent(2) < 0.02)
                Config.update({appearance:{reduceMotion:true}}); wait(20)
                glyph.level = 0.9
                compare(glyph.waveExtent(2), 1) // reduceMotion: estado final directo
                glyph.muted = true
                compare(glyph.muteAmount, 1)
                glyph.muted = false
                Config.update({appearance:{reduceMotion:false}}); wait(20)
                glyph.visible = false
                glyph.level = 0.2
                compare(glyph.waveExtent(2), 0) // oculto: sin animación
                glyph.visible = true
                dial.level = 0.5; wait(900)
                verify(Math.abs(dial.shown - 0.5) < 0.002)
                completed++
            }
            function test_play_pause_split() {
                Config.update({appearance:{reduceMotion:false}}); wait(20)
                compare(pp.t, 0)
                pp.playing = true; wait(60)
                const mid = pp.t
                verify(mid > 0.02 && mid < 0.98)
                pp.playing = false; wait(20) // interrupción: parte del valor actual, no salta
                verify(Math.abs(pp.t - mid) < 0.5)
                wait(900); compare(pp.t, 0)
                pp.playing = true; wait(900); compare(pp.t, 1)
                Config.update({appearance:{reduceMotion:true}}); wait(20)
                pp.playing = false
                compare(pp.t, 0) // reduceMotion: estado final directo
                Config.update({appearance:{reduceMotion:false}}); wait(20)
                pp.visible = false
                pp.playing = true
                compare(pp.t, 1) // oculto: sin animación
                pp.visible = true; pp.playing = false; wait(900)
                completed++
            }
            function busy(item) {
                return item.children.some(c => c.integrating === true)
            }
            function test_play_pause_geometry() {
                Config.update({appearance:{reduceMotion:false}}); wait(20)
                pp.playing = false; wait(900)
                for (let i = 0; i < 2; ++i) for (let j = 0; j < 4; ++j) {
                    compare(pp.quad(i)[j][0], pp.play[i][j][0]); compare(pp.quad(i)[j][1], pp.play[i][j][1])
                }
                pp.playing = true; wait(900)
                for (let i = 0; i < 2; ++i) for (let j = 0; j < 4; ++j) {
                    compare(pp.quad(i)[j][0], pp.pause[i][j][0]); compare(pp.quad(i)[j][1], pp.pause[i][j][1])
                }
                // Rebote pause -> play: la punta nunca cruza sus y (sin grumo en el vértice).
                pp.playing = false
                for (let k = 0; k < 40; ++k) {
                    const q = pp.quad(1)
                    verify(q[1][1] - q[2][1] <= 1e-6)
                    wait(16)
                }
                wait(900)
                verify(!busy(pp)) // reposo: ningún muelle integrando
                completed++
            }
            function test_bolt_fill() {
                Config.update({appearance:{reduceMotion:false}}); wait(20)
                const bolt = bat.children.filter(c => c.objectName === "batteryBolt")[0]
                bat.charging = false; wait(900)
                compare(bat.boltFill, 0); verify(!bolt.visible)
                bat.charging = true; wait(60)
                bat.charging = false; wait(20) // enchufar y desenchufar a mitad
                wait(900); compare(bat.boltFill, 0); verify(!bolt.visible)
                bat.charging = true; wait(900)
                compare(bat.boltFill, 1)
                compare(bolt.data[0].fillColor.a, 1) // reposo conectado: relleno pleno
                compare(bolt.data[1].strokeColor.a, 0) // y contorno retirado
                verify(!busy(bat))
                Config.update({appearance:{reduceMotion:true}}); wait(20)
                bat.charging = false
                compare(bat.boltFill, 0) // reduceMotion: estado final directo
                Config.update({appearance:{reduceMotion:false}}); wait(20)
                bat.charging = true; wait(900)
                completed++
            }
            function test_idle_springs() {
                glyph.level = 0.2; wait(900)
                glyph.level = 0.9; wait(900)
                lock.open = true; wait(1200)
                lock.open = false; wait(1500)
                verify(!busy(lock)) // el "clac" ya asentó
                verify(!busy(glyph)) // el cono del volumen ya asentó
                completed++
            }
            function test_lock_chain() {
                compare(lock.l, 0); compare(lock.sx, 1)
                lock.open = true; wait(80)
                verify(lock.l > 0.05 && lock.l <= 1.2)
                wait(1200)
                verify(Math.abs(lock.l - 1) < 0.01); verify(Math.abs(lock.sx - 0.25) < 0.01)
                lock.open = false; wait(60)
                verify(lock.l > 0.1) // el cierre nace del estado actual
                wait(1500)
                verify(Math.abs(lock.l) < 0.01); verify(Math.abs(lock.sx - 1) < 0.01)
                lock.open = true; wait(120); lock.open = false; wait(1500) // interrupción a mitad del giro
                verify(Math.abs(lock.l) < 0.01); verify(Math.abs(lock.sx - 1) < 0.01)
                Config.update({appearance:{reduceMotion:true}}); wait(20)
                lock.open = true
                verify(Math.abs(lock.l - 1) < 0.001); verify(Math.abs(lock.sx - 0.25) < 0.001)
                lock.open = false
                verify(Math.abs(lock.l) < 0.001); verify(Math.abs(lock.sx - 1) < 0.001)
                Config.update({appearance:{reduceMotion:false}}); wait(20)
                lock.visible = false
                lock.open = true
                verify(Math.abs(lock.l - 1) < 0.001) // oculto: sin animación
                lock.open = false; lock.visible = true
                completed++
            }
            function test_time_ring() {
                ring.active = true; ring.progress = 0.5; ring.running = true; wait(1400)
                verify(Math.abs(ring.drawn - 0.5) < 0.02)
                ring.running = false; ring.active = false; ring.completed = true; wait(100)
                verify(ring.glowing) // un único brillo: dura un tiempo corto
                wait(800)
                compare(ring.drawn, 1)
                wait(Motion.strokeTideHold + 200)
                compare(ring.glowing, false)
                ring.completed = false; wait(900)
                verify(ring.drawn < 0.2) // espera: respira cerca de cero
                Config.update({appearance:{reduceMotion:true}}); wait(20)
                ring.active = true; ring.progress = 0.8
                wait(50)
                verify(Math.abs(ring.drawn - 0.8) < 0.001)
                Config.update({appearance:{reduceMotion:false}}); wait(20)
                ring.active = false
                completed++
            }
            function test_plus_check_morph() {
                Config.update({appearance:{reduceMotion:false}}); wait(20)
                compare(plusCheck.t, 0)
                plusCheck.checked = true; wait(60)
                const mid = plusCheck.t
                verify(mid > 0.02 && mid < 0.98, "en vuelo: " + mid)
                plusCheck.checked = false; wait(20) // interrupción: parte del valor actual
                verify(Math.abs(plusCheck.t - mid) < 0.5)
                wait(900); compare(plusCheck.t, 0)
                plusCheck.checked = true; wait(900); compare(plusCheck.t, 1)
                Config.update({appearance:{reduceMotion:true}}); wait(20)
                plusCheck.checked = false
                compare(plusCheck.t, 0) // reduceMotion: estado final directo
                Config.update({appearance:{reduceMotion:false}}); wait(20)
                plusCheck.visible = false
                plusCheck.checked = true
                compare(plusCheck.t, 1) // oculto: sin animación
                plusCheck.visible = true; plusCheck.checked = false; wait(900)
                completed++
            }
            function test_radio_glyph() {
                Config.update({appearance:{reduceMotion:false}}); wait(20)
                compare(radio.d, 1); compare(radio.off, 0)
                compare(radio.waveExtent(2), 1)
                radio.on = false; wait(70)
                const mid = radio.d
                verify(mid > 0.02 && mid < 0.98, "en vuelo: " + mid)
                // Al apagar la onda exterior se borra antes que la cercana al punto.
                verify(radio.waveExtent(2) <= radio.waveExtent(0))
                radio.on = true; wait(20) // interrupción: parte del valor actual
                verify(Math.abs(radio.d - mid) < 0.5)
                wait(900); compare(radio.d, 1)
                radio.on = false; wait(900)
                compare(radio.d, 0); compare(radio.waveExtent(0), 0)
                compare(radio.barExtent, 1)
                radio.on = true; wait(900)
                Config.update({appearance:{reduceMotion:true}}); wait(20)
                radio.on = false
                compare(radio.d, 0) // reduceMotion: estado final directo
                radioBt.on = false
                compare(radioBt.barExtent, 1)
                Config.update({appearance:{reduceMotion:false}}); wait(20)
                radio.visible = false
                radio.on = true
                compare(radio.d, 1) // oculto: sin animación
                radio.visible = true; radioBt.on = true; wait(900)
                completed++
            }
            function test_plus_check_rest_and_radio_kind() {
                Config.update({appearance:{reduceMotion:false}}); wait(20)
                plusCheck.checked = false; wait(900)
                verify(!busy(plusCheck)) // reposo: ningún muelle integrando
                plusCheck.checked = true; wait(900)
                verify(!busy(plusCheck)); compare(plusCheck.t, 1)
                plusCheck.checked = false; wait(900)
                radio.on = true; radioBt.on = true; wait(900)
                verify(!busy(radio)); verify(!busy(radioBt))
                radio.on = false; wait(900)
                verify(!busy(radio)); compare(radio.d, 0)
                radio.on = true; wait(900)
                // Cambiar de radio en caliente salta al estado final, sin animar.
                compare(radioKind.d, 0); compare(radioKind.barExtent, 1)
                radioKind.kind = "bluetooth"; wait(30)
                compare(radioKind.d, 0); compare(radioKind.barExtent, 1)
                radioKind.on = true; wait(60)
                const mid = radioKind.d
                verify(mid > 0.02 && mid < 0.98, "en vuelo: " + mid)
                wait(900); compare(radioKind.d, 1)
                radioKind.on = false; wait(900)
                radioKind.on = true; wait(40) // a mitad de trayecto...
                verify(radioKind.d > 0.01 && radioKind.d < 0.99)
                radioKind.kind = "wifi"; wait(30) // ...cambiar de kind resuelve al final (1)
                compare(radioKind.d, 1); compare(radioKind.off, 0)
                verify(!busy(radioKind))
                radioKind.kind = "wifi"; radioKind.on = false; wait(900)
                completed++
            }
            function test_media_transport_glyph() {
                const g = transport.contentItem.children.filter(c => c.objectName === "mediaPlayPauseGlyph")[0]
                verify(g, "glifo mediaPlayPauseGlyph")
                Config.update({appearance:{reduceMotion:false, mediaTransitions:true}}); wait(20)
                transport.playing = false; wait(900)
                verify(transport.moving); verify(g.animate)
                compare(g.t, 0)
                transport.playing = true; wait(60)
                const mid = g.t
                verify(mid > 0.02 && mid < 0.98, "en vuelo: " + mid)
                compare(g.playing, true) // sigue a transport.playing
                wait(900); compare(g.t, 1); verify(!busy(g))
                // Sin transiciones multimedia: animate = false y salta al estado final.
                Config.update({appearance:{mediaTransitions:false}}); wait(20)
                verify(!transport.moving); compare(g.animate, false)
                transport.playing = false
                compare(g.t, 0)
                transport.playing = true
                compare(g.t, 1)
                Config.update({appearance:{mediaTransitions:true, reduceMotion:true}}); wait(20)
                transport.playing = false
                compare(g.t, 0) // reduceMotion: también inmediato
                Config.update({appearance:{reduceMotion:false}}); wait(20)
                transport.playing = false
                completed++
            }
            // Un compare/verify fallido aborta la función sin informar: PASS sólo si todas llegaron al final.
            property int completed: 0
            function cleanupTestCase() {
                if (completed !== 18) {
                    console.log("FAIL: sólo " + completed + " de 18 funciones llegaron al final")
                    Qt.exit(1)
                    return
                }
                console.log("PASS: Tidemark tokens, SpringValue (final, interrupción, reduceMotion, oculto), LevelStroke, volumen, play/pause, candado, anillo de tiempo, más/check y radio")
                Qt.quit()
            }
        }
    }
}
