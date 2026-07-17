# Recvel — Contexto para IAs Colaboradoras

> Este documento explica a otras IAs (o a ti mismo en el futuro) qué estamos construyendo, cómo está organizado el proyecto, qué decisiones ya se tomaron y cómo contribuir sin romper la compilación.

---

## 1. Visión del producto

Recvel es una app iOS de salud y bienestar **local-first**, inspirada en Bevel y WHOOP, que lee datos de Apple HealthKit y los convierte en scores, gráficos e insights accionables. No hay backend, no hay cuentas, no hay suscripción premium. El objetivo es que se sienta como una startup de $1B: diseño oscuro, **Liquid Glass** (réplica 1:1 del sistema de Apple de iOS 26, replicado en iOS 17/18), animaciones fluidas y utilidad real.

### Restricciones duras
- **No backend propio.** Todos los cálculos y almacenamiento son locales.
- **No versión premium.** La app es completamente gratuita.
- **Apple Watch opcional pero prioritario.** La app funciona con datos de HealthKit; en el futuro tendrá app de reloj.
- **Siempre debe compilar.** Cada entrega debe dejar el proyecto buildable.
- Para builds y UITests, usar siempre el simulador `iPhone 16 Pro` con `iOS 18.6` ya existente en la Mac. Evitar crear simuladores nuevos o descargar runtimes innecesarios.

---

## 2. Estructura del proyecto

```
Recvel/
├── Recvel/
│   ├── App/
│   │   ├── RecvelApp.swift       # Punto de entrada, container SwiftData
│   │   ├── Info.plist            # Permisos HealthKit y metadata
│   │   └── ...
│   ├── Models/
│   │   └── HealthModels.swift    # DailyHealthSnapshot, WellnessScore, MealLog, etc.
│   ├── Services/
│   │   ├── HealthDataProvider.swift   # Autorización y lectura de HealthKit
│   │   ├── BaselineEngine.swift       # Líneas base personales (mediana, confianza)
│   │   ├── ScoreEngine.swift          # Cálculo de Recovery, Strain, Sleep, Energy
│   │   ├── InsightEngine.swift        # Generación de insights/recomendaciones
│   │   ├── NutritionEstimator.swift   # Estimación local de calorías/macros
│   │   └── LocalStore.swift           # Guardado en SwiftData
│   ├── Views/
│   │   ├── ContentView.swift     # TabView principal
│   │   ├── DashboardView.swift   # Dashboard con scores y métricas
│   │   ├── TrendsView.swift      # Gráficos de tendencias
│   │   ├── NutritionView.swift   # Log de comidas
│   │   ├── SettingsView.swift    # Ajustes y permisos
│   │   └── GlassComponents.swift # Componentes reutilizables de diseño
│   ├── Assets.xcassets/
│   └── Recvel.entitlements       # Capability HealthKit
├── Recvel.xcodeproj/
├── video.mp4 / video2.mp4        # Referencias de diseño
├── README_APP.md
├── README_COMPETIDORES.md
└── README_IA_CONTEXT.md          # Este archivo
```

---

## 3. Estado actual (snapshot)

### Lo que ya funciona
- Proyecto SwiftUI local-first con SwiftData, HealthKit y persistencia editable.
- Onboarding de cinco pasos, perfil/horarios, dashboard narrativo, Plan, Journal, Trends y nutrición por texto/foto con confirmación de porción.
- `HealthDataProvider` consulta 14 días, selecciona fuente preferida, une intervalos de sueño solapados y carga workouts/FC. El modo demo solo se activa explícitamente; cero datos produce una vista vacía.
- Sueño con duración, Core/Deep/REM, despertares, eficiencia, latencia, consistencia y siestas; workouts con cinco zonas y carga cardiovascular.
- `BaselineEngine` usa mediana y filtro MAD. `ScoreEngine` maneja datos faltantes y confianza baja sin convertir ausencia en cero fisiológico.
- Sistema Liquid Glass con materiales, reflejos, tintes semánticos, animaciones accesibles y barra flotante. En SDK 26 usa las APIs nativas disponibles; iOS 17/18 conserva fallback.
- Notificaciones locales para briefing y sueño; edición/borrado de comidas, Journal y datos locales.
- Targets `RecvelTests` y `RecvelUITests` cubren motores, onboarding, estado vacío y recorridos principales.
- Cuando ejecutes `xcodebuild` o `RecvelUITests`, apunta al simulador `iPhone 16 Pro` con `iOS 18.6`. No uses nombres genéricos de dispositivo si puedes evitarlo.

### Lo que falta implementar
- Validación en dispositivo real de HealthKit, precedencia de fuentes, FC de workout, batería y notificaciones.
- Companion Apple Watch, widgets y Live Activities.
- Ampliar Journal/tags, ciclo, fuerza estructurada y tendencias longitudinales.
- Versionar y validar científicamente las fórmulas antes de claims de producción.
- Coach on-device y edad biológica solo después de validar el núcleo.

### 3.1 Componentes existentes — *Completed but refactor needed* (Liquid Glass 1:1)

> Los siguientes componentes ya existen y funcionan, pero **no cumplen** el estándarLiquid Glass / Bevel 1:1 en look & feel (UI + animaciones). Deben refactorizarse manteniendo compatibilidad y sin romper las vistas que los usan.

| Componente | Archivo | Estado actual | Refactor requerido para Liquid Glass / Bevel 1:1 |
|---|---|---|---|
| **`AppBackground`** | `GlassComponents.swift` | Fondo oscuro animado con gradiente que drift lentamente. | Considerar `MeshGradient` en iOS 18 y que el gradiente responda sutilmente al scroll (luz ambiental que alimenta el glass). |
| **`LiquidGlassCard`** | `GlassComponents.swift` | Ya existe con `.ultraThinMaterial`, highlight, inner shadow, tint, `cornerRadius` por defecto 8. | Subir `cornerRadius` por defecto a 20-28 en dashboards; añadir morph con `matchedGeometryEffect`; mejorar legibility adaptativo muestreando luminancia del backdrop; refracción opcional con `distortionEffect`. |
| **`platformGlass`** | `GlassComponents.swift` | Detecta iOS 26 y usa `glassEffect` nativo; fallback `.liquidGlass`. | Validar visualmente en iOS 26 beta que el tint y la interactividad se vean Bevel; ajustar opacidades del fallback. |
| **`GlassCardLinkStyle`** / **`LiquidGlassButtonStyle`** | `GlassComponents.swift` | Press con `scaleEffect(0.96-0.97)` y `.snappy`. | Añadir intensificación del highlight al press, leve aumento de blur, y morph a forma expandida en long press. |
| **`HeroScoreRing`** / **`ArcGauge`** | `GlassComponents.swift` | Anillos con `AngularGradient`, animación spring, glow. | Están bastante avanzados; asegurar que el glass que los contenga tenga corner radius orgánico y que el glow no se corte. |
| **`MetricCard`** | `GlassComponents.swift` | Tarjeta de métrica con icono, valor, referencia y chevron. | Considerar versión cápsula (`LiquidGlassMetricPill`) para rails horizontales; animar transición de valor. |
| **`LiquidGlassTabBar`** | `GlassComponents.swift` | Cápsula flotante con fallback; iOS 26 usa `GlassEffectContainer`. | Añadir separadores **lollipop** entre items; morph a search field; highlight del item seleccionado más "líquido". |
| **`DashboardView`** | `DashboardView.swift` | Hero de Recovery fluido, score rail, plan de hoy, drivers, activación. | **Rediseñar 1:1 al video2 de Bevel**: saludo personalizado, strip de calendario horizontal (Sun-Thu), tarjeta "Calorie Burn" con barra degradada, tarjetas 2×2 (Sleep waveform, Heart Rate min/avg/max, Weight), widgets flotantes de macros/agua/progreso. |
| **`FluidRecoveryHero`** | `DashboardView.swift` | Canvas con olas animadas y score grande. | Muy cercano a Bevel; validar que el glass refracte correctamente y que las olas no distorsionen el texto. |
| **`TrendsView`** | `TrendsView.swift` | Charts con `LiquidGlassCard`, barras/líneas. | Animar barras/líneas al aparecer; añadir edge highlights con scroll; considerar diseño más cercano a los videos (tarjetas grandes, menos padding). |
| **`NutritionView`** | `NutritionView.swift` | Resumen con anillos concéntricos, input y estimate todavía usan `GlassCard` (antiguo). | Migrar `inputCard` y `estimateCard` a `LiquidGlassCard`; `MacroValue` a cápsula glass; transición morph entre estimate y guardado; animación de conteo de calorías. Arreglar test fallido del stepper. |
| **`SettingsView`** | `SettingsView.swift` | **BUG CRÍTICO:** el archivo contiene también `PlanView` y `JournalView` (duplicados). | Separar: `PlanView` y `JournalView` deben vivir solo en sus propios archivos. `SettingsView` debe usar `LiquidGlassButton`/toggles glass y agrupar secciones. |
| **`PlanView`** | `PlanView.swift` / `SettingsView.swift` | Existe en dos archivos; el de `SettingsView.swift` parece ser el que compila. | Consolidar en `PlanView.swift`; eliminar duplicado. |
| **`JournalView`** | `JournalView.swift` / `SettingsView.swift` | Existe en dos archivos; el de `SettingsView.swift` parece ser el que compila. | Consolidar en `JournalView.swift`; eliminar duplicado. |
| **`ScoreEngine`** | `ScoreEngine.swift` | Ya usa baseline con desviaciones y confianza. | Documentar/mostrar fuentes científicas en la UI; ajustar umbrales con referencias (HRV, RHR, FR, sueño); validar fórmulas de strain (TRIMP). |
| **`InsightEngine`** | `InsightEngine.swift` | Genera `DailyBrief` e insights por recovery. | Añadir citas de estudios (PubMed/NIH) a las recomendaciones; generar múltiples insights contextuales con iconografía. |
| **`HealthDataProvider`** | `HealthDataProvider.swift` | Lee historial HealthKit, fuentes preferidas, sueño, workouts, activación. `vo2Max` esta en `readTypes` pero **aun no se consulta** (julio 2026). | Implementar query VO2 + SpO2; background delivery; temperatura de muñeca; ver plan en [README_StressAndBio.md](README_StressAndBio.md). |
| **`TrainingLoadEngine`** | `ScoreEngine.swift` | Zonas de FC y carga cardiovascular. | Validar contra literatura de TRIMP; considerar sRPE manual post-workout. |

### Checklist de refactor (orden sugerido)
1. Crear `LiquidGlassCard`, `LiquidGlassButton`, `GlassEffectContainerReplica`, `LollipopSeparator` en `GlassComponents.swift` con detección `if #available(iOS 26.0, *)`.
2. Migrar `GlassCard` → `LiquidGlassCard` en todas las vistas (mantener API compatible temporalmente si hace falta).
3. Migrar `MetricPill` → `LiquidGlassMetricPill`.
4. Reemplazar `TabView` nativo por `LiquidGlassTabBar`.
5. Añadir animaciones spring/morph a `ScoreRing` y entradas escalonadas en `DashboardView`.
6. Animar gráficos en `TrendsView`.
7. Refactor `ScoreEngine` + `BaselineEngine` para que los scores sean científicos.
8. Ampliar `InsightEngine` con fuentes y variantes.
9. Verificar build + correr en simulador tras cada paso.

---

## 4. Convenciones de código

### Swift
- Usa Swift 5 y SwiftUI.
- iOS 17.0+, Xcode 16+.
- `@MainActor` para clases que publican estado (`ObservableObject`).
- Preferir `structs` para motores puros (`ScoreEngine`, `BaselineEngine`).
- Usar `async/await` para llamadas a HealthKit.

### Nombres
- Vistas: `*View`.
- Servicios/engines: `*Provider`, `*Engine`, `*Store`.
- Modelos: nombres descriptivos (`DailyHealthSnapshot`, `WellnessScore`).

### Strings
- El idioma de la app es **español**, pero los nombres de scores clave se mantienen en inglés (`Recovery`, `Strain`, `Sleep`, `Energy`) por alineación con competidores.
- Usa tildes y eñes en textos visibles.

### Datos
- HealthKit es de solo lectura por ahora (excepto posible escritura de nutrición más adelante).
- SwiftData guarda: `MealLog` y futuras entidades de journal/configuración.

---

## 5. Sistema de diseño — Liquid Glass

> **Regla de oro:** No uses glassmorphism clásico. Toda superficie translúcida debe comportarse como **Liquid Glass**: blur + refracción + highlights especulares + inner shadow + tint adaptativo + morph fluido. En iOS 26 usar el sistema nativo; en iOS 17/18 replicar 1:1 con los componentes aquí descritos.

### 5.1 Qué es Liquid Glass y por qué lo usamos
Apple introdujo Liquid Glass en WWDC25 (iOS 26). Es un material "vivo" que transmite y refracta la luz del contenido detrás, reacciona al movimiento/touch y morph entre estados. Bevel ya usa esta estética; por eso la replicamos.

Diferencia con `.ultraThinMaterial` (iOS 13+):
| | `.ultraThinMaterial` | Liquid Glass |
|---|---|---|
| Base | Blur + tint | Blur + **refracción** + tint + highlight especular + sombra interior |
| Reacción al contenido | Estática | **Dinámica** (legibility en tiempo real) |
| Bordes | Rectos/sin highlight | Borde "orgánico" con highlight superior y sombra inferior |
| Tint | Fijo por color scheme | Hereda accent color, mezcla en `multiply` (stained glass) |
| Morphing | No | `matchedGeometryEffect` integrado |

### 5.2 Colores (basado en videos y competidores)
- **Fondo:** casi negro `#0A0A0A`–`#121212`.
- **Recovery:** verde menta/cian `#34D399` / `#22D3EE`.
- **Strain:** rojo/naranja `#FB923C` / `#F87171`.
- **Sleep:** púrpura/lavanda `#A855F7` / `#C084FC`.
- **Energy:** ámbar/amarillo `#FBBF24`.
- **Texto primario:** blanco. **Texto secundario:** gris medio.
- **Tint del glass:** hereda `AccentColor` o `.tint(_:)` jerárquico.

### 5.3 Componentes base actuales (en `GlassComponents.swift`)
- `AppBackground`: fondo oscuro con gradiente sutil.
- `GlassCard`: tarjeta con `.ultraThinMaterial`, borde blanco tenue, esquinas continuas. **(Debe refactorizarse a `LiquidGlassCard`).**
- `ScoreRing`: anillo de progreso con número central.
- `MetricPill`: valor + etiqueta + icono.

### 5.4 Componentes Liquid Glass a crear
Refactorizar `GlassComponents.swift` y añadir:

| Componente | Descripción | Fallback iOS 17/18 |
|---|---|---|
| `LiquidGlassCard` | Tarjeta contenedora con glass, bloques `.continuous`, padding 16-24. | `.ultraThinMaterial` + highlight superior + inner shadow inferior + borde hairline. |
| `LiquidGlassButton` | Botón cápsula con glass + press morph. | `Capsule` + `.ultraThinMaterial` + `scaleEffect(0.96)` al press + highlight. |
| `GlassEffectContainerReplica` | Agrupa N glass elements para compartir un solo blur. | Un único `.background(.ultraThinMaterial)` en el contenedor; los hijos usan `Color.clear` + overlays. |
| `LiquidGlassTabBar` | Tab bar tipo iOS 26 (cápsula flotante, morph a search). | `HStack` en `Capsule` + `.ultraThinMaterial` + separadores `Path` lollipop. |
| `LiquidGlassSheet` | Sheet con fondo glass. | `.ultraThinMaterial` en `background` del sheet. |
| `LollipopSeparator` | Separador con forma "piruleta" entre cápsulas. | `Path` Bezier custom. |
| `LiquidGlassMetricPill` | Métrica en cápsula glass. | `Capsule` + `.ultraThinMaterial` + highlight. |
| `LiquidGlassScoreRing` | Anillo dentro de glass card con tint adaptativo. | `Circle().trim` + `AngularGradient` sobre `LiquidGlassCard`. |

### 5.5 Detección de versión y fallback

```swift
var isLiquidGlassAvailable: Bool {
    if #available(iOS 26.0, *) { return true } else { return false }
}

struct LiquidGlassSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduce
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // iOS 26: usar APIs nativas
            content.glassEffect(.regular, in: .capsule)
        } else {
            // iOS 17/18: réplica
            if reduce {
                content.background(Color(.systemBackground).opacity(0.92))
            } else {
                content
                    .background(.ultraThinMaterial)
                    .overlay { highlightTopEdge }
                    .overlay { innerShadowBottom }
                    .overlay { hairlineBorder }
                    .overlay { tintOverlay }
            }
        }
    }
}
```

### 5.6 Técnicas SwiftUI para la réplica en iOS 17/18

#### Highlight superior (especular)
```swift
RoundedRectangle(cornerRadius: 20, style: .continuous)
    .stroke(
        LinearGradient(
            colors: [.white.opacity(0.55), .white.opacity(0)],
            startPoint: .top, endPoint: .center
        ), lineWidth: 1.2
    )
    .blendMode(.screen)
```

#### Inner shadow inferior
```swift
extension View {
    func innerShadow<S: Shape>(_ shape: S, radius: CGFloat = 4, color: Color = .black.opacity(0.18)) -> some View {
        overlay {
            shape.stroke(color, lineWidth: radius)
                .blur(radius: radius)
                .mask(shape)
                .blendMode(.multiply)
        }
        .clipShape(shape)
    }
}
```

#### Borde hairline
```swift
RoundedRectangle(cornerRadius: 20, style: .continuous)
    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
```

#### Tint adaptativo (stained glass)
```swift
struct TintOverlay: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduce
    let tint: Color
    func body(content: Content) -> some View {
        let base = tint
            .opacity(scheme == .dark ? 0.22 : 0.16)
        content.overlay(base.blendMode(.multiply))
    }
}
// Highlight superior siempre en blanco/screen (preserva lectura "cristal")
```

#### Morph entre estados
```swift
@Namespace private var ns
// usar matchedGeometryEffect(id:in:) con
// .spring(response: 0.42, dampingFraction: 0.72)
```

#### Refracción (limitada, no backdrop-aware real)
```swift
// iOS 17 distortionEffect sobre snapshot del layer:
content.distortionEffect(
    ShaderLibrary.lensing(.float3(0.5, 0.5, 0.15)),
    maxSampleOffset: 8
)
// NOTA: en iOS 17 no se puede refractar el backdrop real; solo el contenido
// de la propia capa. Aceptado como tradeoff.
```

### 5.7 Behaviors a implementar
- **Press:** `scaleEffect(0.96)` + intensifica highlight + aumenta blur; spring `.snappy`.
- **Long press:** morph a forma expandida con `matchedGeometryEffect`.
- **Edge highlights que cambian con scroll:** muestrear `ScrollView` content offset (iOS 18: `.onScrollGeometryChange`) y dibujar gradiente superior proporcional.
- **Legibility adaptativo:** muestrear luminancia del backdrop (`UIColor` sampled) y cambiar texto primario/secundario.
- **Lollipop separators:** `Path` Bezier entre cápsulas.

### 5.8 Accesibilidad obligatoria
- `accessibilityReduceTransparency` → fallback a `Color(.systemBackground).opacity(0.92)` sin blur, mismo radio y highlight mínimo.
- `accessibilityReduceMotion` → desactivar morph/scale press; usar `.snappy` linear corto.
- `accessibilityDifferentiateWithoutColor` → añadir label/ícono de respaldo.
- Contraste **WCAG AA (4.5:1)** en texto sobre glass: muestrear fondo y elegir texto primario/secundario.
- Combinar elementos para VoiceOver con `.accessibilityElement(children: .combine)` y `.accessibilityLabel`.
- Usar Dynamic Type (`Font.body`, `Font.headline`, etc.); no fijar alturas.

### 5.9 Rendimiento
- **No anidar `.ultraThinMaterial`** (blur sobre blur = coste x2 + artefactos).
- Agrupa glass elements en un `GlassEffectContainerReplica` con un único `.background(.ultraThinMaterial)` en el contenedor.
- Limita glass elements simultáneos (≤5) en A12/A13.
- No animar el radio de blur.
- Usar `.drawingGroup()` con cuidado en vistas complejas.
- Metal para refracción solo cuando sea estrictamente necesario; ofreció refracción del backdrop es la principal limitación en iOS 17/18.

### 5.10 Limitaciones irreproducibles en iOS 17/18
- Refracción backdrop-aware real del wallpaper/widgets (solo Metal integrado del SO en iOS 26).
- Morph a search del tab bar con animación del system.
- Integración con materiales del sistema en sheets nativos.
- Todo lo demás es replicable con alta fidelidad.

---

## 6. Arquitectura de datos y algoritmos

### Flujo de datos
```
Apple HealthKit
      ↓
HealthDataProvider (queries)
      ↓
DailyHealthSnapshot
      ↓
BaselineEngine (línea base personal)
      ↓
ScoreEngine (scores 0–100)
      ↓
InsightEngine (recomendaciones)
      ↓
Dashboard / Trends / Insights
```

### Scores
| Score | Inputs | Fórmula orientativa |
|---|---|---|
| Recovery | HRV, RHR, sueño, FR | Desviación vs baseline personal |
| Strain | FC zonas, duración, active energy | TRIMP simplificado |
| Sleep | Duración, eficiencia, consistencia, FC/FR | Ponderación holística |
| Energy | Recovery + Sleep + carga previa | Combinación ponderada |

### Confianza de datos
- `BaselineEngine.confidence(sampleCount:)`:
  - `≥21` días → alta.
  - `7–20` días → media.
  - `<7` días → baja.

### Fundamentación científica
Ver `README_APP.md` sección 5 para estudios y referencias. Cada algoritmo debe poder justificarse con al menos una referencia indexada.

---

## 7. Cómo agregar una nueva funcionalidad

1. **Modelo:** define structs/clases en `Models/` si es necesario.
2. **Servicio:** si requiere lógica, crea un engine en `Services/`.
3. **Vista:** crea la vista en `Views/` y agrégala a `ContentView` si va en una tab.
4. **Diseño:** usa `GlassCard`, `AppBackground` y la paleta existente.
5. **Permisos:** si lees nuevo tipo de HealthKit, agrégalo en `HealthDataProvider` y en `Info.plist`.
6. **Compilación:** ejecuta build antes de terminar.

### Checklist antes de entregar
- [ ] El proyecto compila en Xcode sin errores.
- [ ] No hay force unwraps nuevos innecesarios.
- [ ] Se respetan los permisos de HealthKit.
- [ ] Las vistas funcionan en modo oscuro.
- [ ] Se considera `accessibilityReduceTransparency`.
- [ ] No se introducen dependencias de backend.

---

## 8. HealthKit

### Tipos ya solicitados
- FC, RHR, HRV, FR, SpO2, active energy, steps, VO2max, sleep analysis, workouts.

### Tipos a considerar en el futuro
- `HKQuantityTypeIdentifierAppleSleepingWristTemperature`
- `HKQuantityTypeIdentifierHeartRateRecoveryOneMinute`
- `HKQuantityTypeIdentifierWalkingHeartRateAverage`
- `HKQuantityTypeIdentifierEnvironmentalAudioExposure`
- `HKCategoryTypeIdentifierSleepApneaEvent`
- `HKDataTypeIdentifierStateOfMind`

### Entitlements
Actualmente solo `com.apple.developer.healthkit`. Si se añaden registros clínicos o background delivery, se debe actualizar `Recvel.entitlements` y justificarlo en App Review.

---

## 9. Privacidad

- No recolectar identificadores de usuario.
- No usar servicios de analytics externos (Firebase, Mixpanel, etc.).
- Si en el futuro se usa un modelo de ML remoto para nutrición, documentarlo explícitamente y ofrecer alternativa local.
- Todo disclaimer médico debe ser claro: "Recvel no diagnostica".

---

## 10. Recursos útiles

- `README_APP.md`: visión del producto, funcionalidades, ciencia.
- `README_COMPETIDORES.md`: análisis de competidores.
- Videos `video.mp4` y `video2.mp4`: referencias de diseño.
- Documentación de Apple: HealthKit, SwiftData, Swift Charts, VisionKit.
