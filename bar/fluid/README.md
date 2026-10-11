# Fluid Island

Fluid Island renders Isla's connected droplets and their transitions. The
engine lives in `FluidEngine.qml`; media and session composition connect it to
the shell through `FluidMediaCompanion.qml` and `IslandOverlay.qml`.

Run the isolated demo from the repository root:

```sh
quickshell -p bar/fluid-demo.qml
```

The engine uses springs, Bézier bridges and hysteresis to keep bodies connected
until the neck breaks. Changing a destination retains the current motion;
reduced motion resolves the state directly. See [the motion contract](MOTION_LANGUAGE.md)
for geometry and interaction rules.

When changing it, check separation, expansion, absorption and interrupted
transitions. Clicks outside the bodies and controls should reach the desktop.
See [tests](../TESTING.md) and [shell architecture](../../docs/SHELL_ARCHITECTURE.md).

## References

- [Vídeo de Quickshell Dynamic Island](https://youtu.be/Ob98KFByTec)
- [FluidKit, `tension.ts`](https://github.com/runvendo/fluidkit/blob/main/src/liquid/tension.ts)
- [`Droplets.tsx`](https://github.com/runvendo/fluidkit/blob/main/src/components/Droplets.tsx)
- [QuickLiquid, `packages/quick-liquid/src/animations/spring.ts`](https://github.com/amarnath3003/quickLiquid/blob/main/packages/quick-liquid/src/animations/spring.ts)
- [`gestures.ts`](https://github.com/amarnath3003/quickLiquid/blob/main/packages/quick-liquid/src/animations/gestures.ts)
- [GLSL Playground, `metaball-search.html`](https://github.com/aaaa-zhen/glsl-playground/blob/main/metaball-search.html)
- [Interactive Metaballs, `index.html`](https://github.com/sigco3111/interactive-metaballs/blob/main/index.html)
- [Apple, “Meet Liquid Glass”](https://developer.apple.com/videos/play/wwdc2025/219/)
- [Motion HIG](https://developer.apple.com/design/human-interface-guidelines/motion)
