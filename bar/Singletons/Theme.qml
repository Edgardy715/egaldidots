pragma Singleton
import QtQuick
import Quickshell

/**
 * Isla · Theme. Mapea la paleta pywal viva (IslaPalette singleton) → los tokens de
 * vidrio de Ricelin (cardTop/cardBot/border/sheen/shadow/accent). Sin inventar
 * colores: cardTop = lift sutil del fondo (dimensión vertical del gradiente),
 * border/sheen toman los exactos del waybar del usuario (foreground @0.08/0.06)
 * para coherencia total. Los acentos vienen directo de pywal.
 *
 * Además de los colores, expone un sistema de tokens numéricos (Spacing / Radius
 * / FontSize / Border / Alpha / SurfaceMargin) que centraliza los valores
 * mágicos repetidos por las 12 surfaces — antes había un caos de `10*s`, `12*s`,
 * `8*s` y `Qt.alpha(..., 0.06)` regados por todos lados; ahora los surfaces los
 * toman de aquí (los valores se siguen multiplicando por `s` en el sitio de uso
 * para respetar el escalado).
 */
Singleton {
    // ORDEN DE DECLARACIÓN IMPORTA: las properties aquí abajo que referencian
    // tokens (Theme.alpha.X, Theme.spacing.X) deben declararse DESPUÉS de los
    // tokens. En QML las properties se inicializan top-down; leer una property
    // no inicializada devuelve `undefined` y rompe la cadena.

    // ---- ALPHA tokens (declarados PRIMERO para evitar forward-reference) ----
    // Escala perceptual: 0.0 (transparente total) → 0.92 (icono casi opaco sobre accent)
    readonly property real alphaTransparent: 0.00   // sentinel para animaciones (from/to 0)
    readonly property real alphaGhost:      0.04   // wash muy sutil, casi invisible
    readonly property real alphaFaint:      0.06   // sheen, divisores suaves
    readonly property real alphaHair:       0.08   // border de tarjeta estándar
    readonly property real alphaHairline:  0.13   // hairline medio (definición interna de Theme.hair, idéntico a waybar)
    readonly property real alphaSoft:       0.10   // bg de controles no-hover
    readonly property real alphaWash:       0.12   // wash de hover ligero
    readonly property real alphaGlow:       0.16   // glow crítico muy suave
    readonly property real alphaSubtle:     0.18   // track de slider
    readonly property real alphaWashStrong: 0.20   // hover wash fuerte
    readonly property real alphaChip:       0.22   // fill de chip accent
    readonly property real alphaEmphasis:   0.25   // emphasis state
    readonly property real alphaMid:        0.30   // mid emphasis
    readonly property real alphaSelected:   0.35   // bg selected / active
    readonly property real alphaStrong:     0.40   // border emphasis
    readonly property real alphaDisabled:   0.45   // text/icono deshabilitado
    readonly property real alphaCritical:   0.55   // critical border
    readonly property real alphaIconSec:    0.70   // icon secondary (legible)
    readonly property real alphaIconOnAcc:  0.85   // icono sobre accent

    // ---- vidrio (puente Ricelin ↔ waybar) ----
    // La guarda `IslaPalette.ready ? ... : "#literal"` elimina la race de creación
    // de singleton (ver IslaPalette.qml). Qt.lighter/Qt.alpha de un color válido
    // nunca dan undefined, así que esos tokens no la necesitan.
    readonly property color cardTop: Qt.lighter(IslaPalette.ready ? IslaPalette.background : "#0e0c1b", 1.18)
    readonly property color cardBot: IslaPalette.ready ? IslaPalette.background : "#0e0c1b"
    readonly property color border:  Qt.alpha(IslaPalette.ready ? IslaPalette.foreground : "#c2c2c6", alphaHair)       // == waybar island
    readonly property color sheen:   Qt.alpha(IslaPalette.ready ? IslaPalette.foreground : "#c2c2c6", alphaFaint)      // == waybar catch-light
    readonly property color hair:    Qt.alpha(IslaPalette.ready ? IslaPalette.foreground : "#c2c2c6", alphaHairline)   // idéntico a waybar foreground @ 0.13
    readonly property color glassShadow: Qt.rgba(0, 0, 0, alphaCritical)

    // ---- acentos vivos (pywal) ----
    readonly property color accent: IslaPalette.ready ? IslaPalette.accent : "#D3A3A0"            // color4
    readonly property color accentStrong: IslaPalette.ready ? IslaPalette.accentStrong : "#B66B67" // color1
    readonly property color accentSoft: IslaPalette.ready ? IslaPalette.accentSoft : "#E5BAB7"   // color5
    readonly property color accentAlt: IslaPalette.ready ? IslaPalette.accentAlt : "#E7C1BD"       // color6
    readonly property color onGlow: IslaPalette.ready ? IslaPalette.accent : "#D3A3A0"            // respiración
    readonly property color dim: IslaPalette.ready ? IslaPalette.dim : "#5d5b6f"                   // color8
    readonly property color foreground: IslaPalette.ready ? IslaPalette.foreground : "#c2c2c6"
    readonly property color background: IslaPalette.ready ? IslaPalette.background : "#0e0c1b"

    // ── Iconos (Material 3) ────────────────────────────────────────────────
    // `dim` es demasiado oscuro para iconos (contraste 2.9:1). Material 3 separa:
    //   · onSurface      → iconos primarios/activos   (fg completo)
    //   · onSurfaceVariant → iconos secundarios        (fg ~70%, legible)
    //   · outline         → SOLO bordes, nunca contenido
    readonly property color iconPrimary: foreground
    readonly property color iconSecondary: Qt.alpha(foreground, alphaIconSec)    // 5.75:1
    readonly property color iconMuted: Qt.alpha(foreground, alphaDisabled)        // 3.4:1 (deshabilitado)
    readonly property color iconOnAccent: Qt.rgba(0, 0, 0, alphaIconOnAcc)        // sobre chips accent

    readonly property real shadowOpacity: 0.55
    readonly property real rSmall: Motion.rSmall
    readonly property real rTile:  Motion.rTile

    // ──────────────────────────────────────────────────────────────────────
    // Sistema de tokens numéricos (valores BASE — multiplicar por `s` en el sitio)
    // ──────────────────────────────────────────────────────────────────────
    //
    // Los números aquí abajo son la fuente de verdad para toda la UI.
    // Antes había `10*s`, `12*s`, `8*s` y `Qt.alpha(fg, 0.06)` regados por
    // todos lados; ahora los callers hacen `spacing: Theme.spacing.md * s`
    // o `color: Qt.alpha(Theme.foreground, Theme.alpha.medium)`.
    //
    // Si necesitas un valor que no está, agrégalo aquí (no metas un literal
    // en la surface — la consistencia se rompe en cuanto hay 2 lugares con
    // el mismo número mágico).

    // ---- Spacing (gaps entre elementos / padding interno de tarjetas) ----
    // Escala t-shirt clásica (1, 2, 3, 4, 6, 8, 10, 12, 16) — coincide con
    // Material 3 spacing tokens. Los sites usan siempre `Theme.spacing.X * s`.
    readonly property real spacingNone:  0
    readonly property real spacingXxs:   1   // hairline (chip↔icono)
    readonly property real spacingXs:    2   // micro (entre elementos muy juntos)
    readonly property real spacingSm:    4   // gaps cortos en RowLayout densos
    readonly property real spacingMd:    8   // gaps estándar (el más común)
    readonly property real spacingLg:   10   // gaps amplios dentro de tarjetas
    readonly property real spacingXl:   12   // separación entre secciones
    readonly property real spacingXxl:  16   // separación entre cards

    // ---- Radius (esquinas redondeadas) ----
    // Concentrados en una escala corta. rSmall/rTile vienen de Motion.qml
    // y se usan en lugares críticos — no los duplicamos.
    readonly property real radiusXs:    4   // pills internos, chips muy compactos
    readonly property real radiusSm:    8   // botones, tiles pequeños
    readonly property real radiusMd:    9   // sliders, botones medianos
    readonly property real radiusLg:   10   // tarjetas estándar
    readonly property real radiusXl:   12   // tarjetas grandes (session, mixer)
    readonly property real radiusXxl:  16   // modales, dialogs
    readonly property real radiusFull: 18   // esquinas casi totales para paneles anchos

    // ---- FontSize (jerarquía tipográfica, base a s=1.0) ----
    // Consolida los 10 niveles que aparecen en surfaces. hCaption/hSmall/
    // hBody/hTitle/hHead ya existían — los respetamos y añadimos los que faltan
    // para llegar al 100% de cobertura.
    // IMPORTANTE: todos `real` (no `int`) — los callers hacen `Theme.fontSizeX * s`
    // y el resultado de multiplicar int por real es double, que Qt no puede asignar
    // a una property `int` (Warning: Unable to assign double to int).
        readonly property real fontSizeCaption:    9   // mono pequeño (URGENTE, timestamps)
    readonly property real fontSizeLabel:     10   // chips, contadores (countTxt)
    readonly property real fontSizeSmall:      11   // body small, secundarios
    readonly property real fontSizeBody:      12   // body estándar, NotifCard body
    readonly property real fontSizeBodyLg:    13   // body destacado (hSmall original)
    readonly property real fontSizeTitle:     15   // títulos de surface (hTitle original)
    readonly property real fontSizeTitleLg:   16   // títulos grandes, valores numéricos
    readonly property real fontSizeHeadline:  17   // clock, headlines
    readonly property real fontSizeHead:      18   // hHead original, iconos grandes
    readonly property real fontSizeDisplay:   20   // cover art label, media chrome
    readonly property real fontSizeDisplayLg: 22   // cifras grandes (counter, score)
    readonly property real fontSizeIcon:      28   // iconos grandes (notif genericBadge)
    readonly property real fontSizeHero:      24   // hero title (WallpaperSurface)
    readonly property real fontSizeCalendar:  30   // calendar day number (MediaSurface)
    readonly property real fontSizeHeroLg:    34   // calendar huge number
    readonly property real fontSizePreview:   40   // OverviewScreen preview label
    readonly property real fontSizeCover:     52   // cover art text overlay
    // legacy aliases — respetan los nombres previos para no romper callers
    readonly property real hCaption: fontSizeCaption
    readonly property real hSmall:   11
    readonly property real hBody:    fontSizeBodyLg
    readonly property real hTitle:   fontSizeTitle
    readonly property real hHead:    fontSizeHead

    // ---- Border width ----
    readonly property real borderHairline: 1     // borde estándar (67 ocurrencias)
    readonly property real borderEmphasis: 2     // borde destacado (10 ocurrencias)
    readonly property real borderHairlineSoft: 1.5  // borde sutil (glows críticos, anillos de notif)
    readonly property real borderEmphasisSoft: 2.5  // borde destacado soft (notif glow)

    // ---- SurfaceMargin (padding interno de PillSurface.mTop/Left/Right/Bottom) ----
    // Antes los valores iban de 10 a 22 sin sistema; ahora una escala corta.
    // 0/10 son válidos (sin margen / margen compacto) y se mantienen como tokens.
    readonly property real marginNone:  0
    readonly property real marginXs:   10   // wallpapersurface (panel ancho)
    readonly property real marginSm:   14   // surfaces pequeñas (session, utils)
    readonly property real marginMd:   16   // la más común (calendar, mixer, notifs)
    readonly property real marginLg:   18   // surfaces grandes (calendar con eventos)
    readonly property real marginXl:   20   // mixer ancho, surfaces con teclado

    // ---- Hover/Pulse scale (microinteracciones) ----
    readonly property real scaleHover:   1.03   // wash + lift sutil
    readonly property real scaleActive:  1.05   // pressed, click feedback
    readonly property real scaleNudge:   1.10   // emphasis (keepAwake toggled)

    // ---- tipografía ----
    // Google Sans Flex (instalada en ~/.local/share/fonts, variable completa
    // GRAD,ROND,opsz,slnt,wdth,wght) = la headline de caelestia. Rubik para el
    // reloj/monospaciado display. Adwaita Sans como fallback real instalada.
    readonly property string font: "Google Sans Flex"
    readonly property string fontFallback: "Adwaita Sans"
    readonly property string fontMono: "JetBrainsMono Nerd Font"
    // display/tabular — reloj, porcentajes, contadores (Rubik, fuente "clock"
    // de caelestia). Cae a Inter si no está instalada.
    readonly property string fontDisplay: "Rubik"

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
    }
}
