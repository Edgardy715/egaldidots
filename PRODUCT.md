# Isla

<!-- impeccable:product-schema 1 -->

## Platform

Linux/Wayland nativo. Quickshell con Qt Quick/QML; no es una interfaz web.
Esta plataforma queda fuera de la enumeración web/ios/android/adaptive de
Impeccable: su detector web no acredita la implementación ni su accesibilidad.

## Product Purpose

La pill central integra información y controles del escritorio; abre superficies
para tareas concretas y vuelve al reposo conservando continuidad.

## Operating Context

Shell personal existente bajo Hyprland. El código, AGENTS.md,
PROJECT_MEMORY.md y docs/SHELL_ARCHITECTURE.md documentan sus contratos.
La validación visual ocurre en la sesión Wayland real.

## Capabilities and Constraints

Conservar funciones, datos y cambios ajenos. Reutilizar componentes existentes.
Los servicios se conectan desde composición; las hojas reciben propiedades.
Config.update/discard/save gobierna ajustes; probar persistencia con ISLA_CONFIG
temporal. No añadir dependencias ni funciones por motivos de acabado.

## Brand Commitments

Isla/Fluid Island. El brief del 2026-10-08 pide una estética Apple-like adaptada
a Isla: jerarquía clara, material sobrio, controles precisos y movimiento continuo.

## Evidence on Hand

Theme.qml, Motion.qml, bar/fluid/MOTION_LANGUAGE.md y componentes reales.
docs/PILL_INTERFACE_AUDIT.md registra hallazgos, capturas y límites verificables.
No hay estudio de audiencia ni pruebas con lectores de pantalla; no inferirlos.

## Product Principles

- Proteger lectura y control sin romper la continuidad de la pill.
- Mantener los contratos de arquitectura y las preferencias del usuario.
- Distinguir pruebas automatizadas, QA visual nativo y aspectos no verificados.

## Accessibility & Inclusion

El brief exige foco, teclado, Escape, regiones de entrada y accesibilidad.
Los nombres accesibles y la navegación deben servir a tareas reales; la
conformidad completa requiere evaluación adicional con tecnología de asistencia.

Contexto extraído del brief explícito y del repositorio; no añade decisiones
sobre audiencia, distribución ni nuevas capacidades.
