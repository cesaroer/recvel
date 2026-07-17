# Investigación: comportamiento nativo de Liquid Glass navbar + implementación en Recvel

Fecha: 2026-07-13 (actualizado: morph minimize + FAB Bevel)

## Limitación del entorno

El proyecto compila con Xcode 16.x / deployment iOS 17. No siempre hay SDK iOS 26, así que las APIs nativas (`GlassEffectContainer`, `glassEffect`, `tabBarMinimizeBehavior`) van detrás de `#if compiler(>=6.2)` / `@available(iOS 26.0, *)`. En el resto de dispositivos se emula el **comportamiento observable**.

## Qué NO es Liquid Glass (error de la iteración previa)

Solo hacer `opacity` + `offset` para “quitar” la barra al hacer scroll **no** replica Liquid Glass ni Bevel. El sistema nativo **minimiza / morph**, no desaparece:

| Aspecto | iOS 26 nativo | Bevel (videos del repo) | Recvel ahora |
| --- | --- | --- | --- |
| Scroll down | `tabBarMinimizeBehavior(.onScrollDown)` → barra se encoge | Cápsula → **dos círculos** (tab activo izq. + `+` der.) | `Mode.minimized` + morph `matchedGeometryEffect` |
| Scroll up / top | Re-expande | Vuelve la cápsula + FAB | `Mode.expanded` |
| FAB lateral | Search role / bottom accessory | Círculo `+` al mismo nivel que la cápsula | FAB glass siempre visible; `+` ↔ `xmark` |
| Menú del FAB | — | Menú visual de acciones | Fan de cápsulas glass (Comida, Journal, Ayuno, Actividad, Plan, Ajustes) |
| Detalle (push) | Tab bar ausente | Barra fuera de pantalla | `Mode.hidden` (slide off) |

Referencias: WWDC25 “Build a SwiftUI app with the new design”, `tabBarMinimizeBehavior`, Donny Wals Liquid Glass tab bars; frames de `Bevel_ref_2.mp4` / `bevel_reference.mp4`.

## Archivos clave

- `Recvel/Services/TabBarVisibility.swift` — modos `expanded` / `minimized` / `hidden` + `wantsSettings`.
- `Recvel/Views/GlassComponents.swift` — `LiquidGlassTabBar`, `TabQuickAction`, morph + menú.
- `Recvel/Views/ContentView.swift` — host a pantalla completa (el scrim del menú no cabe en `safeAreaInset`).
- `Recvel/Views/DashboardView.swift` — abre Ajustes cuando el FAB lo pide.
- `RecvelUITests/RecvelUITests.swift` — compact-on-scroll, FAB menú, hide on detail.

## Identifiers de accesibilidad

- `tabbar`, `tab.<name>`, `tab.compact.<name>`
- `tabbar.fab.open` / `tabbar.fab.close`
- `tabbar.menu`, `tabbar.action.<meal|journal|fasting|fitness|plan|settings>`

## Build

Verificado: `xcodebuild … -destination 'generic/platform=iOS Simulator' build` → **BUILD SUCCEEDED**.
