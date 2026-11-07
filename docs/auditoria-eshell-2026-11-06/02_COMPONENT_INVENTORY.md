# 02 · Inventario de componentes

Auditoría ESHELL · 2026-11-06 · rama `feat/hyprland-glass-keybinds` con cambios locales sin publicar.
Solo lectura: ningún archivo funcional se modificó.

**Leyenda de evidencia**

- **[V]** verificado en código (`archivo:línea`) o en captura real del 2026-11-06.
- **[I]** inferencia razonada; falta comprobarla.
- **[X]** idea experimental.

**Método**

- Se recorrió `bar/` excluyendo `*regression*`, `*demo*`, `*stage*`, `*filmstrip*` y `tests/`.
- Los conteos salen de `rg`/`grep -c` por línea (una línea con dos apariciones cuenta una vez).
- Las capturas se hicieron con `grim` tras abrir surfaces por IPC (`qs -c bar ipc call island <surface> DP-1`), en DP-1 a 1920×1080 y 240 Hz.
- Las capturas **no** se guardan en el repo porque contienen datos personales (ventanas de fondo, dispositivos, avatar). Quedan en el scratchpad de la sesión.

---

## 1. Mapa general

La shell tiene unos 120 componentes en `bar/components/`, 15 wrappers en `bar/surfaces/`, 16 archivos de ajustes en `bar/settings/`, 6 de lockscreen y 5 del motor Cuerpo/Agua (`bar/body/`).

```
shell.qml
 └─ IslandOverlay (852 L, ventana por monitor)
     ├─ barra superior: TopBarModules → TopWorkspaceRail · TopAppStrip · TopSystemStatus · TopUserStatus
     └─ Pill (941 L)
         ├─ PillMorphMotion (muelles por eje) ← PillGeometry (objetivos)
         ├─ PillMaterial (sombra, arte, vidrio, bordes) / PillBody + BodyShader (SDF)
         ├─ PillHeaderView · IslandRestStatus · IslandNotification · IslandMediaSummary
         ├─ FluidCompanion (gotas) + FluidNeck (cuello GPU)
         └─ PillSurfaceHost → Loader → 15 surfaces → *View.qml
```

## 2. Inventario por familia

### 2.1 Pill e isla (núcleo de identidad)

| Componente | Líneas | Rol | Observación |
|---|---|---|---|
| `Pill.qml` | 941 | estado, geometría, surfaces, morph de notificación | El archivo más grande del núcleo; concentra demasiada lógica [V] |
| `PillMorphMotion.qml` | 274 | muelles retargetables (omega/zeta por eje, presets open/resize/close) | Conserva velocidad al redirigir [V]; `dt` limitado a 1/30 alarga el movimiento a menos de 30 fps (ya reportado el 2026-10-26) [V] |
| `PillMaterial.qml` | 251 | sombra, arte, vidrio, bordes | Sombra `Qt.rgba(0,0,0,0.72)` literal en :76 [V]; borde de respiración de notificación en :190 [V] |
| `PillSurfaceHost.qml` | 220 | aloja la surface y su materialización (blur, escala) | El Loader se activa con `displayedSurface.length > 0` (:151) [V] |
| `PillHeaderView.qml` | 176 | reposo y cabecera del launcher | — |
| `PillPullGesture.qml` | 331 | gesto de tirar | — |
| `IslandCompanion.qml` | 534 | "rostro" propio de la isla | Sigue en uso tras retirar las mascotas: lo importan `Pill.qml` e `IslandActivityChip.qml` [V]. Tiene 63 duraciones y 53 curvas literales [V] |
| `FluidCompanion.qml` | 778 | motor compartido de gotas (muelle analítico) | — |
| `body/*` | ~950 | Cuerpo/Agua: SDF del cuerpo, cuello y decoraciones | `BodyShader.qml` no menciona `reduceMotion` [V]; queda por ver si `BodyEngine` congela el tiempo [I] |

### 2.2 Superficies (15)

Auth, Calendar, Clipboard, Connectivity, Focus, Launcher, Media, Mixer, Notifs, Overview, Recording, Session, Settings, Utils y Wallpaper. Son wrappers de 6 a 75 líneas sobre vistas de 200 a 800 líneas.

Las vistas más grandes son WallpaperView (794), ClipboardView (715), CalendarView (685), ConnectivityView (603), QuickControlsView (491), LauncherView (473) y MediaView (462).

### 2.3 Controles base

| Familia | Implementaciones | Dónde | Estado |
|---|---|---|---|
| **Botón circular / icono** | 5 | `CtrlBtn.qml`, `MotionButton.qml`, `settings/EdotsButton.qml`, `lockscreen/LockButton.qml`, `audio/AudioButton.qml` | Gramática de pulsación compartida (`InteractionMotion`), pero 5 APIs distintas [V] |
| **Área interactiva** | 1 primitiva + MouseArea sueltas | `MotionArea.qml` | Primitiva buena: rol accesible, Espacio/Intro, lavado de hover y foco [V] |
| **Slider** | 4 | `components/Slider.qml` (custom), `audio/AudioFader.qml` (Controls.Basic), `settings/SettingRow.qml:393` (Controls con tubo propio), `lockscreen/LockMedia.qml:79` (Controls) | Fragmentación confirmada [V] |
| **Switch** | 1 | `Toggle.qml` (40×24, pulgar 20 px) | Híbrido iOS/M3 (ver doc 03) [V] |
| **Segmented / pestañas** | 0 componentes, ≥2 en línea | `MixerView.qml:94-131` (4 pestañas), `ConnectivityView` (Wi-Fi/Bluetooth) | Visto en captura [V]. Cada vista implementa su indicador y su teclado |
| **Campo de texto** | 3 | `IslaTextField.qml`, `settings/EdotsTextField.qml`, campo del lockscreen | — |
| **ComboBox** | 1 | `settings/EdotsComboBox.qml` (Popup) | Se usa también en el mezclador (captura) [V] |
| **Selección** | 1 | `LiquidSelection.qml` | Bordes líderes y finales con `Behavior` independientes; pierde velocidad al redirigir rápido [I] |
| **Tooltip** | 0 propios | `ToolTip` adjunto en SettingRow:188, AuthPromptView:199, BodyMessenger:199 | Sin estilo de la casa [V] |
| **Estados vacío/carga/error** | 0 componentes | Dentro de cada vista (`ErrorShake`, `ConfirmationIndicator`, `WallpaperApplyFeedback`) | Estado vacío de conectividad visto en captura [V] |

### 2.4 Superficies de contenido (tarjetas)

| Componente | Uso |
|---|---|
| `GlassCard.qml` (63 L) | Tarjeta canónica (`Theme.radiusLg`, `Theme.tonalFill`). Solo la usan QuickControlsView y las previews [V] |
| `NotifCardView.qml` (447 L) | Tarjeta propia; capa `layer.enabled: true` permanente en :131 [V] |
| `DeviceMomentCard.qml`, `UpdateSourceCard.qml`, `ClipboardEntryRow.qml`, tarjeta de dispositivo del mezclador | Tarjetas propias, cada una con su radio y relleno [V] |

### 2.5 Media

MediaView (462), SwiftMediaTimeline (198), LyricsView (274), MediaTransportButton (130), IslandMediaCover (205), MediaAmbient (57) y LockMedia (126).

Es la excepción visual aprobada en DESIGN.md (referencia Swiftify: Material Symbols Rounded rellenos, botón festoneado, portada circular con espectro radial).

### 2.6 Barra superior (capturada en reposo) [V]

- **Izquierda:** botón circular de cuadrícula de apps, una pequeña mancha tenue (posible gota o indicador sin etiqueta) [I], y el riel de workspaces con indicador "pacman" lila seguido de puntos.
- **Centro:** la pill en reposo con "9:16 PM".
- **Derecha:** cápsula de estado con dos iconos de bandeja, separador, volumen, red cableada y batería, más un avatar circular aparte.

## 3. Duplicados y huecos (resumen accionable)

1. **Slider ×4** con anatomía, tamaño de pulgar (16, 14 y nativo), teclado y accesibilidad distintos. El `Slider.qml` propio no tiene `Accessible`, `Keys` ni rueda; QuickControlsView:287 los añade a mano [V].
2. **Botones ×5**, cada uno con su API (`glyph`/`iconName`/`text`/`primary`/`dim`).
3. **Segmented ×N en línea** sin componente (Mixer, Connectivity) [V]. Overview y Clipboard tienen selectores propios [I].
4. **Tarjetas ×5+**: GlassCard existe pero casi no se usa.
5. **Cabeceras:** `SurfaceHeader` cubre 9 vistas. Calendar, Launcher, Media, Overview, Recording, Auth y Lyrics no lo usan [V]. Que no tengan cabecera propia es un hallazgo negativo de búsqueda por nombre [I].

## 4. Deuda de tokens (literales)

| Tipo | Peores archivos | Total aproximado |
|---|---|---|
| `radius: <número>` | OverviewView 4, ActivityView 4, WallpaperView 3, MixerView 3, AuthPromptView 3 | 30+ en components |
| `font.pixelSize: <número>` | WallpaperView 10, SessionView 6, OverviewView 6, MediaView 6, AuthPromptView 5 | 60+ |
| Colores `"#…"`/`Qt.rgba` | PillMaterial 5, BatteryIndicator 4 (`#30d158`, `#8e8e93`), PrivacyDots 3 (`#ff9f0a`), AuthPromptView 3 | 98 `"#"` + 21 `Qt.rgba` fuera de Singletons |
| Duraciones literales | IslandCompanion 63 | 106 frente a 350 referencias a `Motion` |
| Curvas literales | IslandCompanion 53 | 101 frente a 263 |

Algunos literales son decisiones legítimas (colores de sistema como el verde de carga o el naranja de privacidad, o media con su excepción). La recomendación del doc 07 es convertirlos en **tokens con nombre**, no eliminarlos.

## 5. Mapa de interacción y accesibilidad (top)

| Archivo | MouseArea | MotionArea | `Accessible.` | Tab | `Keys.on` |
|---|---|---|---|---|---|
| QuickControlsView | 1 | 3 | 11 | 1 | 2 |
| CalendarView | 0 | 7 | 4 | 0 | 0 |
| WallpaperView | 1 | 5 | 0 | 0 | 0 |
| OverviewView | 0 | 2 | **0** | 0 | **0** |
| NotifCardView | 0 | 4 | 0 | 0 | 0 |
| Slider | 1 | 0 | **0** | **0** | **0** |
| Pill | 1 | 0 | **0** | 0 | 0 |
| SettingRow | — | — | 21 | **0** | — |

`MotionArea` aporta rol, nombre y teclado cuando recibe `accessibleName`. Las vistas que la usan sin nombre (WallpaperView, NotifCardView y OverviewView, según los conteos) no exponen nada al lector de pantalla [I].

## 6. Observaciones de captura (2026-11-06) [V]

| Surface | Lo visto |
|---|---|
| Utils ("Ajustes rápidos") | Cabecera con chip "Apariencia", dos tiles: "Mantener activa" y "Actividades". Compacta y clara |
| Sonido (mezclador) | Pestañas Salida/Entrada/Aplicaciones/Hardware; tarjeta de dispositivo con slider, combo y botón "Canales" dentro de la tarjeta (tarjeta dentro de tarjeta); chip "Hasta 150 %" abajo |
| Calendario | Fecha "VIERNES 6" y reloj **21:18 (24 h)** mientras la pill muestra **9:16 PM (12 h)**; columna de clima con pronóstico y barras de rango |
| Conectividad | Pestañas Wi-Fi/Bluetooth; toggle "Desactivado"; estado vacío "Wi-Fi desactivado" con glifo de barra diagonal |
| Launcher | Reloj y campo "Buscar aplicaciones..." con borde de acento; sin lista visible antes de escribir (la captura llegó a 1,2 s, puede que antes de que aparezca la lista) [I] |
| Media | Sin reproductor activo la surface no se abrió; solo se vio la pill en reposo. **No se pudo auditar el reproductor en vivo** |

No se capturaron Overview, Wallpaper, Clipboard, Notifs, Session, Focus, Recording ni Lockscreen. Settings se auditó en [11](11_SETTINGS_APP_AUDIT.md) (6 de 10 páginas capturadas). El lockscreen exige bloquear la sesión, y las demás surfaces muestran datos personales. Su auditoría en este informe es de código.
