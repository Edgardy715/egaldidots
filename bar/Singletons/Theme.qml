pragma Singleton
import QtQuick
import Quickshell

/** Semantic Material You roles from Matugen, composed with Isla glass/motion. */
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

    // Neutral tonal elevation keeps the glass coherent across wallpaper changes.
    readonly property color cardTop: IslaPalette.colors.surface_container_high
    readonly property color cardBot: IslaPalette.colors.surface_container_low
    readonly property color border: Qt.alpha(IslaPalette.colors.outline_variant, 0.55)
    readonly property color sheen: Qt.alpha(IslaPalette.foreground, alphaFaint)
    readonly property color hair: Qt.alpha(IslaPalette.colors.outline, 0.3)
    readonly property color glassShadow: Qt.rgba(0, 0, 0, alphaCritical)

    readonly property color accent: IslaPalette.accent
    readonly property color accentStrong: IslaPalette.accentStrong
    readonly property color accentSoft: IslaPalette.accentSoft
    readonly property color accentAlt: IslaPalette.accentAlt
    readonly property color onGlow: accent
    readonly property color dim: IslaPalette.dim
    readonly property color foreground: IslaPalette.foreground
    readonly property color background: IslaPalette.background
    readonly property color error: IslaPalette.colors.error
    readonly property color errorContent: IslaPalette.colors.on_error
    readonly property color errorContainer: IslaPalette.colors.error_container
    readonly property color errorContainerContent: IslaPalette.colors.on_error_container
    readonly property color primaryContent: IslaPalette.colors.on_primary
    readonly property color accentContainer: IslaPalette.colors.primary_container
    readonly property color accentContainerContent: IslaPalette.colors.on_primary_container
    readonly property color secondaryContainer: IslaPalette.colors.secondary_container
    readonly property color secondaryContainerContent: IslaPalette.colors.on_secondary_container
    readonly property color tertiaryContainer: IslaPalette.colors.tertiary_container
    readonly property color tertiaryContainerContent: IslaPalette.colors.on_tertiary_container
    readonly property color surface: IslaPalette.colors.surface
    readonly property color surfaceContainer: IslaPalette.colors.surface_container
    readonly property color surfaceContainerHighest: IslaPalette.colors.surface_container_highest
    readonly property color outline: IslaPalette.colors.outline
    readonly property color iconPrimary: foreground
    readonly property color iconSecondary: IslaPalette.colors.on_surface_variant
    readonly property color iconMuted: Qt.alpha(iconSecondary, alphaDisabled)
    readonly property color iconOnAccent: primaryContent

    readonly property real shadowOpacity: 0.55
    readonly property real rSmall: Motion.rSmall * Flags.radiusScale
    readonly property real rTile:  Motion.rTile * Flags.radiusScale

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
    readonly property real spacingXxs:   1 * Flags.spacingScale // hairline (chip↔icono)
    readonly property real spacingXs:    2 * Flags.spacingScale // micro (entre elementos muy juntos)
    readonly property real spacingSm:    4 * Flags.spacingScale // gaps cortos en RowLayout densos
    readonly property real spacingMd:    8 * Flags.spacingScale // gaps estándar (el más común)
    readonly property real spacingLg:   10 * Flags.spacingScale // gaps amplios dentro de tarjetas
    readonly property real spacingXl:   12 * Flags.spacingScale // separación entre secciones
    readonly property real spacingXxl:  16 * Flags.spacingScale // separación entre cards

    // ---- Radius (esquinas redondeadas) ----
    // Concentrados en una escala corta. rSmall/rTile vienen de Motion.qml
    // y se usan en lugares críticos — no los duplicamos.
    readonly property real radiusXs:    4 * Flags.radiusScale // pills internos, chips muy compactos
    readonly property real radiusSm:    8 * Flags.radiusScale // botones, tiles pequeños
    readonly property real radiusMd:    9 * Flags.radiusScale // sliders, botones medianos
    readonly property real radiusLg:   10 * Flags.radiusScale // tarjetas estándar
    readonly property real radiusXl:   12 * Flags.radiusScale // tarjetas grandes (session, mixer)
    readonly property real radiusXxl:  16 * Flags.radiusScale // modales, dialogs
    readonly property real radiusFull: 18 * Flags.radiusScale // esquinas casi totales para paneles anchos

    // ---- FontSize (jerarquía tipográfica, base a s=1.0) ----
    // Consolida los 10 niveles que aparecen en surfaces. hCaption/hSmall/
    // hBody/hTitle/hHead ya existían — los respetamos y añadimos los que faltan
    // para llegar al 100% de cobertura.
    // IMPORTANTE: todos `real` (no `int`) — los callers hacen `Theme.fontSizeX * s`
    // y el resultado de multiplicar int por real es double, que Qt no puede asignar
    // a una property `int` (Warning: Unable to assign double to int).
    readonly property real fontSizeCaption:    9 * Flags.fontScale // mono pequeño (URGENTE, timestamps)
    readonly property real fontSizeLabel:     10 * Flags.fontScale // chips, contadores (countTxt)
    readonly property real fontSizeSmall:      11 * Flags.fontScale // body small, secundarios
    readonly property real fontSizeBody:      12 * Flags.fontScale // body estándar, NotifCard body
    readonly property real fontSizeBodyLg:    13 * Flags.fontScale // body destacado (hSmall original)
    readonly property real fontSizeTitle:     15 * Flags.fontScale // títulos de surface (hTitle original)
    readonly property real fontSizeTitleLg:   16 * Flags.fontScale // títulos grandes, valores numéricos
    readonly property real fontSizeHeadline:  17 * Flags.fontScale // clock, headlines
    readonly property real fontSizeHead:      18 * Flags.fontScale // hHead original, iconos grandes
    readonly property real fontSizeDisplay:   20 * Flags.fontScale // cover art label, media chrome
    readonly property real fontSizeDisplayLg: 22 * Flags.fontScale // cifras grandes (counter, score)
    readonly property real fontSizeIcon:      28 * Flags.fontScale // iconos grandes (notif genericBadge)
    readonly property real fontSizeHero:      24 * Flags.fontScale // hero title (WallpaperSurface)
    readonly property real fontSizeCalendar:  30 * Flags.fontScale // calendar day number (MediaSurface)
    readonly property real fontSizeHeroLg:    34 * Flags.fontScale // calendar huge number
    readonly property real fontSizePreview:   40 * Flags.fontScale // OverviewScreen preview label
    readonly property real fontSizeCover:     52 * Flags.fontScale // cover art text overlay
    // legacy aliases — respetan los nombres previos para no romper callers
    readonly property real hCaption: fontSizeCaption
    readonly property real hSmall:   fontSizeSmall
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
    readonly property real marginXs:   10 * Flags.spacingScale // wallpapersurface (panel ancho)
    readonly property real marginSm:   14 * Flags.spacingScale // surfaces pequeñas (session, utils)
    readonly property real marginMd:   16 * Flags.spacingScale // la más común (calendar, mixer, notifs)
    readonly property real marginLg:   18 * Flags.spacingScale // surfaces grandes (calendar con eventos)
    readonly property real marginXl:   20 * Flags.spacingScale // mixer ancho, surfaces con teclado

    // ---- Hover/Pulse scale (microinteracciones) ----
    readonly property real scaleHover:   1.03   // wash + lift sutil
    readonly property real scaleActive:  1.05   // pressed, click feedback
    readonly property real scaleNudge:   1.10   // emphasis (keepAwake toggled)

    // ---- tipografía ----
    // Google Sans Flex (instalada en ~/.local/share/fonts, variable completa
    // GRAD,ROND,opsz,slnt,wdth,wght) = la headline de caelestia. Rubik para el
    // reloj/monospaciado display. Adwaita Sans como fallback real instalada.
    readonly property string font: Flags.fontFamily
    readonly property string fontFallback: "Adwaita Sans"
    readonly property string fontMono: Flags.fontMonoFamily
    // display/tabular — reloj, porcentajes, contadores (Rubik, fuente "clock"
    // de caelestia). Cae a Inter si no está instalada.
    readonly property string fontDisplay: Flags.fontDisplayFamily
    readonly property string fontMedia: Flags.fontMediaFamily

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
    }
}
