# 03 · Auditoría del lenguaje visual

Leyenda de evidencia: **[V]** verificado · **[I]** inferencia · **[X]** experimental.

## 1. ¿Qué identidad tiene hoy Eshell?

**Tiene una identidad clara en el núcleo y difusa en la periferia.**

**Núcleo propio y reconocible [V]:**

- Una pill central que se transforma en todas las surfaces sin cambiar de ventana.
- Muelles retargetables con un overshoot de ~3 %.
- Gotas que se desprenden y un cuello líquido entre pill y gota.
- El cuerpo de agua (SDF).
- Un reloj odómetro (`ClockReel`).

La metáfora es *materia líquida que se reorganiza*. Ninguna otra shell de Quickshell la lleva tan lejos.

**Periferia prestada [V]:**

- Los controles (toggle, slider, combo y pestañas) y los tokens usan nombres y proporciones de Material 3, iOS e Hyprland a la vez.
- `Theme.qml` se describe como "Semantic Material You roles from Matugen".
- `Motion.qml` mezcla `emphasizedDecel` (M3), `bounceCurve`/`slingCurve` (Hyprland) y presets de muelle tipo Apple.

**Diagnóstico:** el usuario reconoce Eshell **en movimiento** y **no en reposo**. Una captura fija de cualquier surface (mezclador, conectividad) podría pasar por un panel de GNOME o de Material.

## 2. Tokens actuales

| Área | Estado | Problema |
|---|---|---|
| **Espaciado** | 1/2/4/8/10/12/16 | El 10 rompe la rejilla de 4. El comentario dice "Material 3" [V] |
| **Radios** | Xs 4 · Sm 8 · **Md 8** · Lg 12 · **Xl 12** · Xxl 16 · Full 20 | Dos pares duplicados (Sm=Md, Lg=Xl); en la práctica la escala tiene 5 pasos. Hay 30+ radios literales (13, 10, 16…) [V] |
| **Tipografía** | Rediseño 11/05: escala de 6 pasos (11·13·15·20·28·40); `Theme` sigue exponiendo 11/13/15/17/20/28/34/40/52 | Los alias colapsan, pero quedan 9 valores accesibles y 60+ `pixelSize` literales (MediaView 48/22, SessionView 21, OverviewView 19) [V] |
| **Alfa** | 19 tokens de 0.04 a 0.85 | Demasiados pasos para distinguirlos; varios están a menos de 0.02 de distancia [V] |
| **Familias** | Google Sans Flex (texto), Rubik (display), Adwaita Sans (respaldo), `fontMedia` | Cuatro familias más Material Symbols. El comentario atribuye Google Sans Flex a "headline de caelestia" [V] |
| **Escala de interacción** | `scaleHover` 1.03 · `scaleActive` 1.05 · pulsación 0.96/0.975/0.965 | Coherente; tres escalas de pulsación casi iguales [V] |
| **Color** | Roles Matugen + `tonalFill` 0.055/0.07 + `stateInk` (selecciona tinta por contraste) | Base sólida. Hay literales de sistema fuera de los tokens (`#30d158`, `#ff9f0a`, `#8e8e93`, rojos/verdes de Auth) [V] |

## 3. Coherencia observada en capturas [V]

- **Bien.** Cabecera grande DemiBold en Sonido, Conectividad y Ajustes rápidos: la jerarquía es consistente.
- **Bien.** Tarjetas tonales sin sombra; el acento lila aparece una sola vez por zona (día actual, botón activo, slider).
- **Mal.** Mezclamos formatos de hora en la misma pantalla: la pill muestra "9:16 PM" y el calendario "21:18". Es deliberado (`Settings.js:37`: "la pill no cambia"), pero el resultado se lee como un error.
- **Mal.** Mayúsculas inconsistentes en el calendario: "DO LU MA" y "VIERNES" en mayúsculas, "vie sáb dom" en minúsculas en el pronóstico.
- **Mal.** Tarjeta dentro de tarjeta en el mezclador: la tarjeta de dispositivo contiene el slider, un combo con borde y un botón con fondo. Son tres niveles de contenedor.
- **Mal.** El glifo del estado vacío de Wi-Fi es una barra diagonal sola, sin forma reconocible de onda. Puede ser intencional o un glifo que falta [I].
- **Regular.** La barra superior combina tres formas de contenedor: círculo (apps), cápsula (workspaces y estado) y círculo (avatar). Funciona, pero no comparte material con la pill.

## 4. Mapa de influencias

| Influencia | Dónde se ve | ¿Aporta o diluye? |
|---|---|---|
| **Dynamic Island (Apple)** | Pill central que se transforma, notificaciones inline y actividades | Aporta en lo conceptual, y Eshell ya la supera en materia (gotas y cuello). Hay riesgo de copia literal en las proporciones de reposo y en el "Live Activity" |
| **iOS / HIG** | Toggle 40×24, rubber band, muelles críticos, cabeceras grandes | Aporta en física y diluye en los controles: el toggle es casi idéntico al de iOS |
| **Material 3 / Material You** | Roles de color, escala de espaciado, curvas `emphasized`, combo con borde, estado "off" del toggle | Ver §5 |
| **Hyprland** | `bounceCurve`/`slingCurve`, overshoot de entrada en lockscreen (`OutBack` 1.6) | Diluye: el rebote fuerte contradice el principio "~3 % overshoot" |
| **caelestia / end-4 (ecosistema Quickshell)** | Tipografía y estructura de servicios | Neutral; es la raíz técnica del proyecto |
| **Swiftify (media)** | Botón festoneado, portada circular y espectro radial | Excepción aprobada; es la zona más expresiva |

## 5. Sección Material You

### 5.1 Lo que conviene **conservar** de Material You

1. **Color dinámico desde el fondo (Matugen).** Es la pieza más valiosa: Eshell se ve distinto en cada fondo sin dejar de ser coherente.
2. **Roles semánticos** (`primary`, `onPrimary`, `surfaceContainer*`, `outline`, `error`). Son la API de color estable que permite cambiar de paleta sin tocar componentes.
3. **Elevación tonal en vez de sombra** (cada nivel es una superficie un poco más clara). Ya está aplicada (`tonalFill`) y encaja con el principio "profundidad por tono".
4. **Contraste garantizado por rol** (`on*`). `stateInk` lo complementa bien.
5. **Escala de estado** (hover 8 %, pulsación 12 %, foco). Se puede expresar con los alfas existentes.

### 5.2 Lo que conviene **adaptar**

1. **Curvas `emphasized`.** Sirven para fundidos y desplazamientos de contenido, no para la geometría de la pill, que debe seguir en muelles.
2. **Rejilla de 4 dp.** Hay que mantenerla y retirar el 10.
3. **Escala tipográfica M3** (display/headline/title/body/label). Eshell ya la redujo a 6 pasos; los nombres deberían ser propios, no `DisplayLg`.

### 5.3 Lo que conviene **evitar**

1. **Formas expresivas M3 ("Material 3 Expressive")** fuera de media: festones, polígonos redondeados y contenedores con forma morfológica. Compiten con la gota, que es la única forma expresiva de Eshell.
2. **Combo y campos con borde de contorno** (estilo "outlined"). En la captura del mezclador el borde del combo crea un cuarto nivel visual. Hay que preferir un relleno tonal sin borde.
3. **Toggle con pulgar pequeño gris y contorno en "off".** Es el patrón M3; mezclado con la proporción iOS no es ni lo uno ni lo otro.
4. **Ripple** (onda radial desde el punto de pulsación). Ya está evitado; mantenerlo así.
5. **FAB y chips de filtro M3** como patrones.

### 5.4 ¿Es dependencia o compatibilidad?

Es **compatibilidad con Matugen**, que es buena, **más una dependencia nominal** que conviene cortar:

- Los nombres de tokens (`fontSizeDisplayLg`, `emphasizedDecel`, `radiusXl`) y los comentarios ("match Material 3") hacen que cualquier contribución nueva tire hacia M3.
- Hay que renombrar a un vocabulario propio (doc 07) sin tocar los roles de color que entrega Matugen.

### 5.5 ¿Cómo se ve Eshell sin parecer Material You?

1. **Formas:** solo tres familias geométricas (cápsula, gota y rectángulo concéntrico). Nada de festones fuera de media.
2. **Superficies:** vidrio oscuro con tinte del acento a un 3–6 %, no `surfaceContainerHigh` plano.
3. **Controles:** pista gruesa y "líquida" (el tubo del slider de ajustes ya va en esa dirección) en vez de pista fina con pulgar.
4. **Movimiento:** muelles en todo lo geométrico; las curvas solo para opacidad.
5. **Acento:** un acento por surface y nunca en grandes rellenos.

## 6. ¿El lenguaje está unificado?

**Parcialmente.** El rediseño del 2026-11-05 unificó cabeceras, escala tipográfica y radios concéntricos en las surfaces principales [V]. Quedan:

- 4 sliders, 5 botones y pestañas en línea.
- Literales en Wallpaper, Overview, Session, Media y Auth.
- Formato de hora y mayúsculas.
- Rebote fuerte (`OutBack` 1.6) en el lockscreen.
- `IslandCompanion` fuera del sistema de movimiento.
