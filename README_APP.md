# Recvel — App de Salud y Bienestar Local-First

> **Visión:** Ser la app de salud más completa, privada y visualmente premium para usuarios de Apple Watch. Inspirada en Bevel, WHOOP y el ecosistema de wearables, pero sin backend, sin cuentas y sin suscripción premium. Todos los datos se procesan localmente en el dispositivo.

---

## 1. Propuesta de valor

Recvel toma los datos que ya genera tu Apple Watch (y otras apps compatibles con Apple Health), los combina con algoritmos respaldados por literatura científica y te los presenta en un dashboard tipo *health coach* con diseño glassmorphism de startup de $1B.

- **Todo local:** sin servidores propios, sin analytics externos, sin cuentas.
- **Científica:** cada score e insight se apoya en estudios indexados (PubMed/NIH).
- **Moderna:** dark-first, glassmorphism, animaciones fluidas, widgets y Apple Watch.
- **Útil:** no solo muestra datos, sino que traduce tus señales corporales en recomendaciones accionables.

---

## 2. Referencias de diseño (videos del repositorio)

Los dos videos de referencia (`video.mp4` y `video2.mp4`) definen el lenguaje visual:

### Estética general
- Fondo casi negro (`#0A0A0A` a `#121212`).
- Tarjetas redondeadas (`cornerRadius: 20–28`) con fondo translúcido oscuro y bordes tenues.
- Acentos de neón: verde menta/cian para recovery, naranja/ámbar para sleep, azul para strain, rojo/fuego para calorías.
- Tipografía SF Pro/SF Pro Rounded, números grandes y pesados, etiquetas secundarias en gris.
- Animaciones suaves en anillos, barras y transiciones de tarjetas.

### Pantallas observadas
1. **Dashboard principal (video1)**
   - Header con avatar, fecha "Today" e indicador de reloj/batería.
   - Tres anillos grandes: Sleep, Recovery, Strain.
   - Tarjetas de métricas: "Within range", "Medium" (stress), Steps, Heart Rate.
   - Sección "My Day" con botón flotante `+`.
   - Detalle de métrica con gráfico de líneas (Respiratory Rate) y barras (Sleep Performance).

2. **Dashboard tipo Bevel (video2)**
   - Header personalizado: "Hello Sara! Welcome back! 👋".
   - Strip de calendario horizontal (Sun–Thu).
   - Tarjeta "Calorie Burn" con barra de progreso degradada (azul → verde → naranja → rojo).
   - Tarjetas 2×2: Sleep con waveform, Heart Rate con min/avg/max, Weight con línea.
   - Widgets flotantes: macros ring, water gauge, notificaciones de progreso.
   - Tab bar: Home, Activity, Nutrition, Coach.

### Principios de diseño: Liquid Glass (estilo Bevel)

> **Filosofía:** No usamos glassmorphism clásico. Usamos **Liquid Glass**, el lenguaje de Apple introducido en iOS 26 (WWDC25), replicado 1:1 en iOS 17/18. El cristal no es un overlay estático: es un material vivo que **transmite y refracta la luz**, reacciona al movimiento/touch y morph entre estados con fluidez.

#### ¿Por qué Liquid Glass y no glassmorphism tradicional?
Bevel usa una estética de "cristal líquido" que coincide con el nuevo sistema de Apple. Frente al `.ultraThinMaterial` de iOS 13+ (blur + tint estáticos), Liquid Glass añade:
- **Refracción óptica real** del contenido detrás (efecto lente convexa + aberración cromática sutil).
- **Highlights especulares en bordes** que se mueven con el contenido/scroll.
- **Adaptación de contraste en tiempo real** (legibility engine) para garantizar legibilidad.
- **Morphing fluido** entre formas/estados.
- **Tinting adaptativo** que hereda el accent color y se mezcla en modo `multiply` (stained glass).

#### Características visuales a replicar
1. **Translucidez real:** los colores del contenido detrás "tiñen" el cristal; no es solo blur.
2. **Refracción / distorsión:** los píxeles del backdrop se desplazan hacia el centro del glass (lente convexa) con separación cromática leve rojo/azul de ~1-2px en @3x.
3. **Highlights especulares en bordes:** gradiente lineal de ~1-2pt en el borde superior + hairline de luz (blanco @ 60-80% en dark, ~30% en light). El highlight se intensifica con contenido claro detrás y se atenúa con contenido oscuro.
4. **Bordes orgánicos:** esquinas `.continuous` (superellipse suave, sin hard corners). En tab bars/sidebars, separadores con forma "lollipop" (círculo unido por cuello a cápsulas).
5. **Adaptación dinámica:** re-muestrea la luminancia del backdrop y ajusta opacidad del tint, intensidad del highlight y saturación del blur. Dark mode → tint gris carbón; light mode → blanco translúcido.
6. **Sombra interior (inner shadow):** hairline oscuro en borde inferior para dar profundidad.
7. **Tinting adaptativo:** hereda `AccentColor` o `.tint(_:)`, se aplica en `blendMode(.multiply)` (stained glass, no rectángulo de color).
8. **Efectos líquidos:** morph entre formas con `matchedGeometryEffect` y spring fluida; press → escala 0.96-0.98 + intensifica highlight; long press → expansión absorbiendo contenido vecino.

#### Behaviors / motion
- **Legibility adaptativo:** el texto sobre el glass cambia de claro/oscuro según el fondo detrás (sampling de luminancia).
- **Lensing / magnificación:** el contenido bajo el glass se distorsiona hacia el centro (lente convexa) vía shader de distorsión.
- **Press:** `scaleEffect(0.96-0.98)` + intensifica inner highlight + aumenta blur. Spring `.snappy`.
- **Morph:** entre estados con `.spring(response: 0.42, dampingFraction: 0.72)`.
- **Edge highlights con scroll:** el borde superior se ilumina donde el scroll llega al borde del material.
- **Lollipop separators:** entre elementos de tab bar/sidebar.

#### Componentes de iOS 26 que se replican
- `GlassEffectContainer` → agrupa glass elements para compartir blur (1 sample, no N).
- `GlassButton` → botón con glass + press/morph automáticos.
- TabBar liquid → `.tabBarStyle(.liquid)`, cápsula flotante que morph a search.
- NavigationBar / sidebar con separadores lollipop.
- Sheets / popovers con fondo glass.
- Search field glass.
- Widgets con refracción del wallpaper.

#### Réplica en iOS 17/18 (estrategia técnica)
Detección con `if #available(iOS 26.0, *)` y fallback:

```swift
var isLiquidGlassAvailable: Bool {
  if #available(iOS 26.0, *) { return true } else { return false }
}
```

**En iOS 26+:** usar APIs nativas (`GlassEffectContainer`, `.glassEffect(.regular, in:)`, `.glassEffectTint(_:)`, `.tabBarStyle(.liquid)`, `GlassSeparatorShape.lollipop`).

**En iOS 17/18 (réplica):** apilar manualmente:
- `.ultraThinMaterial` como base de blur.
- Highlight superior: `LinearGradient` blanco → transparente con `blendMode(.screen)`.
- Inner shadow inferior: `strokeBorder` oscuro con `blur` + `mask` + `blendMode(.multiply)`.
- Borde hairline: `stroke(Color.white.opacity(0.1), lineWidth: 0.5)`.
- Tint adaptativo con `blendMode(.multiply)` heredando `.tint`.
- Refracción: `distortionEffect(ShaderLibrary.lensing(...))` sobre snapshot del layer (no backdrop-aware real, limitación aceptada).
- Morph: `matchedGeometryEffect` con `.spring(response: 0.42, dampingFraction: 0.72)`.
- Reduce Transparency: fallback a `Color(.systemBackground).opacity(0.92)` sin blur.

#### Limitaciones irreproducibles en iOS 17/18
- Refracción backdrop-aware real del wallpaper/widgets (soloMetal integrado del SO lo logra).
- Morph a search del tab bar con animación del system.
- Integración con materiales del sistema en sheets nativos.
- Lo demás es replicable con alta fidelidad (blur + highlight + innerShadow + tint + morph + reduceTransparency).

#### Rendimiento
- Agrupa glass elements en un único container con `.ultraThinMaterial` (no anidar blurs).
- Limita glass elements simultáneos (≤5) para evitar cuellos de GPU en A12/A13.
- No animar el radio de blur.
- Usar `.drawingGroup()` con cuidado en vistas complejas.

#### Accesibilidad
- `accessibilityReduceTransparency` → fallback a fill opaco con mismo radio y highlight mínimo.
- `accessibilityReduceMotion` → desactivar morph/scale press; usar `.snappy` linear corto.
- Contraste WCAG AA (4.5:1) muestreando luminancia del backdrop.
- VoiceOver: combinar elementos y añadir `accessibilityLabel`.

Ver `README_IA_CONTEXT.md` sección "Sistema de diseño Liquid Glass" para la implementación técnica completa y los componentes a crear.

---

## 3. Funcionalidades principales

### 3.1 Scores diarios
| Score | Descripción | Inputs de Apple Health |
|---|---|---|
| **Recovery** | Qué tan recuperado estás para el día. | HRV nocturna, FC en reposo, sueño, FR nocturna |
| **Strain** | Carga cardiovascular y muscular acumulada. | FC durante entrenamientos, active energy, duración |
| **Sleep** | Calidad y cantidad del descanso. | Etapas de sueño, duración, FC/FR nocturna |
| **Energy** | Energía estimada combinando recovery y sleep. | Recovery, sleep, carga previa |

### 3.2 Señales vitales
- HRV (SDNN)
- Frecuencia cardíaca en reposo
- Frecuencia respiratoria nocturna
- SpO2
- Pasos y distancia
- Calorías activas / totales
- VO2 max estimado
- Temperatura de muñeca nocturna (Apple Watch Series 8+)

### 3.3 Entrenamientos
- Lista de workouts de Apple Health.
- Detalle: duración, calorías, zonas de FC, distancia, ritmo.
- Strain por sesión (TRIMP simplificado).
- Tendencias semanales/mensuales.

### 3.4 Sueño
- Score de sueño ponderado por duración, eficiencia y consistencia horaria.
- Etapas: REM, Core, Deep, Awake.
- Tendencias de 7/30 días.
- Recomendaciones de horario de acostarse.

### 3.5 Nutrición con IA local
- Estimación de calorías y macros por texto (reglas locales + NLP).
- Análisis de foto con VisionKit/Core ML on-device.
- Referencia de porción mediante objeto conocido (mano, plato).
- Historial de comidas guardado en SwiftData.
- Opcional: escribir `dietaryEnergyConsumed` en HealthKit.

### 3.6 Journal / Tags
Registro manual de hábitos para correlacionar con recovery/sueño:
- Cafeína (hora y cantidad)
- Alcohol
- Hidratación
- Menstruación / ciclo
- Viaje / jet lag
- Enfermedad / síntomas
- Notas de texto libre

### 3.7 Insights y coaching
- Insight principal del día basado en el score más bajo.
- Recomendaciones contextuales con iconografía y fuentes científicas.
- Detección de anomalías: HRV/FR fuera de baseline, posible sobreentrenamiento.

### 3.8 Fitness
- Tab principal con ventana móvil de 30 días.
- Calendario de consistencia y resumen de minutos desde HealthKit + actividad manual.
- Strain diario comparado con un objetivo modulado por Recovery.
- Carga cardio por zonas de FC; duración como fallback explícito cuando faltan muestras.
- Foco cardio: aeróbico bajo (Z1-Z2), aeróbico alto (Z3-Z4) y anaeróbico (Z5).
- Heart Rate Recovery al minuto 1 calculada sólo cuando HealthKit contiene FC al terminar y alrededor de 60 segundos después.
- Fuerza: sesiones/minutos de HealthKit y volumen muscular únicamente confirmado por el usuario.
- Plantillas y actividades manuales persistidas localmente con SwiftData.
- Tendencias pasa a Home como bloque navegable; no se elimina su detalle longitudinal.

Los detalles de Fitness explican cómo leer cada métrica y evitan lenguaje diagnóstico. HRR se usa como tendencia contextual: calor, postura, hidratación y protocolo de finalización pueden alterar la medición.

### 3.8 Tendencias
- Gráficos de líneas, barras y anillos con Swift Charts.
- Comparativas vs baseline personal.
- Exportación de datos (XML de Health o CSV propio).

### 3.9 Widgets y Apple Watch
- Widgets de Home Screen y Lock Screen.
- Complicaciones de Apple Watch.
- App para Apple Watch (futuro): iniciar entrenamientos y ver scores.

---

## 4. Fuentes de datos

### Apple HealthKit (principal)
La app lee los siguientes tipos de `HKObjectType`:

- `HKQuantityTypeIdentifierHeartRate`
- `HKQuantityTypeIdentifierRestingHeartRate`
- `HKQuantityTypeIdentifierHeartRateVariabilitySDNN`
- `HKQuantityTypeIdentifierRespiratoryRate`
- `HKQuantityTypeIdentifierOxygenSaturation`
- `HKQuantityTypeIdentifierActiveEnergyBurned`
- `HKQuantityTypeIdentifierBasalEnergyBurned`
- `HKQuantityTypeIdentifierStepCount`
- `HKQuantityTypeIdentifierVO2Max`
- `HKQuantityTypeIdentifierAppleSleepingWristTemperature`
- `HKCategoryTypeIdentifierSleepAnalysis` (REM, Core, Deep, Awake)
- `HKWorkoutTypeIdentifier` + `HKWorkoutRouteTypeIdentifier`

### Otras fuentes locales
- SwiftData para comidas, journal y configuración.
- `CMSensorRecorder` / `CMBatchedSensorManager` para acelerómetro del Apple Watch (limitado).
- VisionKit para análisis de imágenes de comida.

### Fuentes abiertas de calibración (no integradas en runtime)
- **PhysioNet:** MIMIC, Sleep-EDF, WESAD, PPG-DaLiA.
- **NIH/NHANES:** datos poblacionales.
- **Compendio de Actividades Físicas 2024:** METs por actividad.

---

## 5. Algoritmos y respaldo científico

### 5.1 Recovery Score
Combina desviaciones respecto al baseline personal:

```
recovery = f(ΔHRV, ΔRHR, sleepScore, ΔRespiratoryRate)
```

- **HRV:** valores bajos respecto a baseline indican mayor fatiga/estrés (Manresa-Rocamora et al., 2021; Flatt & Esco, 2023).
- **RHR:** elevaciones >5–10 lpm sobre la media sugieren recuperación incompleta (Czeisler & Buxton, 1985; Hynynen et al., 2019).
- **FR nocturna:** aumentos sostenidos >2–3 resp/min pueden indicar estrés fisiológico o infección (Natarajan et al., 2021; Mishra et al., 2022).

### 5.2 Strain Score
Basado en Training Impulse (TRIMP) simplificado:

```
strain = Σ tiempoEnZona_i × factorIntensidad_i
```

Zonas de FC personalizadas por edad/condición física.
Referencias: Bourdon et al. (2017), Haddad et al. (2017).

### 5.3 Sleep Score
Ponderación holística:

```
sleepScore = 0.35×duración + 0.25×eficiencia + 0.20×consistenciaHoraria + 0.20×estabilidadFC/FR
```

- Los wearables son útiles para tendencias longitudinales, no para diagnóstico (Chinoy et al., 2021; de Zambotti et al., 2022).

### 5.4 Calorías
Modelo híbrido:

```
calorías = MET × peso(kg) × tiempo(h) × factorIntensidadFC
```

Referencias: Herrmann et al. (2024) Compendio de Actividades; O'Driscoll et al. (2020).

### 5.5 IA de nutrición
- Detección de alimentos con CNN/Vision.
- Estimación de volumen con referencia de escala.
- Estado del arte tiene errores del 10–30% en porciones (Dalakleidi et al., 2022; Lu et al., 2020).

### 5.6 Hábitos y HRV/Sueño
- Cafeína 6 h antes de dormir reduce calidad del sueño (Drake et al., 2013).
- Alcohol fragmenta el sueño y suprime REM (Colrain et al., 2014).
- Ciclo menstrual modula HRV 3–9 %; la fase lútea suele mostrar menor HRV (de Jager et al., 2026).

---

## 6. Privacidad y seguridad

- **Local-first:** todos los cálculos y almacenamiento ocurren en el dispositivo.
- **Sin cuentas:** no hay login, email ni identificador de usuario.
- **Sin backend propio:** no enviamos datos a servidores de Recvel.
- **HealthKit:** el usuario controla granularmente qué datos comparte desde Ajustes de iOS.
- **Disclaimer:** Recvel es una herramienta de bienestar. No diagnostica ni sustituye el consejo médico profesional.

---

## 7. Stack tecnológico

- **Lenguaje:** Swift 5
- **UI:** SwiftUI, iOS 17+
- **Datos:** SwiftData, HealthKit
- **Gráficos:** Swift Charts
- **On-device ML:** VisionKit, NaturalLanguage, Create ML (futuro)
- **Watch:** watchOS 10+ (futuro)

---

## 8. Roadmap

### MVP (ahora)
- [x] READMEs completos.
- [x] Consultas reales de HealthKit (lectura de HRV, RHR, FR, SpO2, energía, pasos, sueño, workouts; fallback a demo).
- [x] Baseline engine con mediana robusta (MAD), desviación y confianza.
- [x] Score engine con fórmulas ponderadas (Recovery, Strain, Sleep, Energy).
- [x] Insights básicos (`InsightEngine.briefing`, `primaryInsight`).
- [x] Detalle de Recovery, Sleep, Strain, Energy con gráficos.
- [x] Journal/tags con `HabitLog` y correlaciones personales básicas.
- [x] Nutrición por texto + foto local (Vision classify + reglas + porción).
- [x] Onboarding multi-paso.
- [x] Tab bar Liquid Glass (cápsula flotante con fallback iOS 17/18).
- [x] Componentes Liquid Glass base (`LiquidGlassCard`, `liquidGlass`, `platformGlass`, `HeroScoreRing`, `ArcGauge`).
- [ ] Dashboard estilo Bevel/video2 1:1 (falta: saludo personalizado, strip de calendario horizontal, tarjeta "Calorie Burn" con barra degradada, tarjetas 2×2 con waveform de sueño, widgets flotantes).
- [ ] Insights contextualizados con **fuentes científicas citadas** en la UI.
- [ ] Animaciones Liquid Glass 1:1 (morph, edge highlights con scroll, press más profundo, lollipop separators).
- [ ] Corregir duplicación de `PlanView`/`JournalView` y tests de UI fallidos.

### Corto plazo
- [ ] Widgets Home Screen / Lock Screen.
- [ ] Exportación de datos.
- [ ] Smart alarm / bedtime reminders integrados con HealthKit.
- [ ] Mejorar algoritmo de IA de nutrición (detección de porciones, más alimentos).

### Mediano plazo
- [ ] App para Apple Watch.
- [ ] Complicaciones y Live Activities.
- [ ] Entrenamientos guiados.
- [ ] Edad biológica / Healthspan score.

### Sugerencias Grok

Prioridades para ser competitiva como mejor app del mercado (uso personal / local-first). Detalle y contexto en `README.md` sección **Sugerencias Grok**.

#### P0 — Hábito diario y confianza nutricional
- [ ] Widgets Home Screen / Lock Screen (Recovery, Strain, Sleep).
- [ ] Morning Report rico al despertar (Recovery + sueño + acción del día + margen Strain).
- [ ] Clasificador Food-101 Core ML (reemplazar Vision genérico).
- [ ] Reglas de seguridad clínica 12.10 en nutrición (screening, disclaimers, sin streaks punitivos).
- [ ] Validación en Apple Watch real (zonas, batería, notificaciones).

#### P1 — Scores memorables, aprendizaje y coaching local
- [ ] Batería de energía continua (nombre propio; sube/baja en el día).
- [ ] Journal más rico: agua, cafeína con hora, alcohol con cantidad; correlación ayuno ↔ Recovery/HRV.
- [ ] Coach Q&A local (reglas + Foundation Models; sin nube de salud).
- [ ] Fuentes científicas citadas en la UI de insights.
- [ ] Export CSV / respaldo de comidas, journal y scores.

#### P2 — Paridad de mercado
- [ ] Companion watchOS + complicaciones.
- [ ] Live Activities / Dynamic Island (ayuno o workout).
- [ ] Edad biológica / healthspan opt-in (wellness, no clínico; detalle en [README_StressAndBio.md](README_StressAndBio.md) — no PhenoAge sin labs).
- [ ] Ciclo menstrual × HRV/sueño (HealthKit).
- [ ] Strength builder (series × reps × peso).
- [ ] Snapshot bajo demanda (~2 min).
- [ ] Smart alarm / haptic bedtime.
- [ ] VO2 max y SpO2 con tendencia y contexto en UI (**VO2: auth sí, query aún no** — ver StressAndBio).
- [ ] Seccion Home **Stress** (bandas Excelente/Normal/Atencion/Sobrecarga).

No priorizar: multi-wearable cloud, paywall, backend, bloodwork clínico ni promesa de calorías exactas desde foto sola.

---

## 9. Notas de compilación

El proyecto debe compilar y ejecutarse en Xcode 16+ con iOS 17.0+. La capability **HealthKit** ya está activada y los permisos están declarados en `Info.plist`.

Cada entrega de código debe mantener la app compilable. Antes de subir cambios, ejecutar build en simulador o dispositivo.

### UI tests (verificación de diseño)

El proyecto incluye el target **RecvelUITests** (XCUITest) que valida que el dashboard estilo Bevel contiene sus secciones clave, que la tab bar Liquid Glass navega correctamente y que el flujo de estimación de nutrición funciona. Cada test adjunta screenshots para revisión visual del diseño.

Regla operativa para compilación y UITests: usar siempre el simulador `iPhone 16 Pro` con `iOS 18.6` ya disponible en la Mac. No crear simuladores nuevos ni descargar runtimes innecesarios salvo que el usuario lo pida expresamente.

```bash
# Correr los UI tests
xcodebuild -project Recvel.xcodeproj -scheme Recvel \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6' \
  -resultBundlePath resultados.xcresult test

# Exportar los screenshots capturados
xcrun xcresulttool export attachments --path resultados.xcresult --output-path capturas/
```

Toda entrega que toque UI debe dejar estos tests en verde y revisar las capturas generadas.
