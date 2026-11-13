# Recvel × NOOP: veredicto técnico y plan de fusión

Revisión del 21 de octubre de 2026. Complementa la [comparación de producto](README_NOOP_COMPARISON.md) (16 oct) y la [revisión del código local](README_NOOP_LOCAL_CODE_REVIEW.md) (19 oct). Esta entrega responde tres preguntas concretas —**¿NOOP nos gana en cálculos, en ciencia o en precisión?**— y propone **qué pantallas, lógica y componentes tomar de NOOP y en qué lugar exacto de Recvel ponerlos**.

## Alcance y método

- Recvel en `b1b9e3f` (el código de la app no cambió desde la revisión anterior; solo documentación).
- NOOP: copia local `Downloads/noop-main` (`project.yml` 12.1.0, build 438). No se ejecutó ni compiló. Licencia **PolyForm Noncommercial 1.0.0**: todo lo que sigue son adaptaciones conceptuales; no se incorpora código, assets ni dependencias.
- Se auditó **motor por motor con la misma rúbrica en ambos** (método, fuente de la señal, referencias, gates de calidad, tests) y después **pantalla por pantalla** (navegación, secciones, componentes reutilizables, estados vacíos). Cuatro pasadas independientes; las líneas citadas son de esta Mac.
- Cifras de volumen: NOOP tiene ~2,100 funciones de test solo en `StrandAnalytics` frente a 238 en toda Recvel; Recvel cita ~94 referencias científicas (PubMed/DOI/"et al.") en código y docs frente a ~9 de NOOP. Ninguna de las dos cifras demuestra validez clínica.

---

## 1. Veredicto en tres ejes

### 1.1 Lógica y cálculos: NOOP gana en la capa de señal, no en los scores

| Tema | NOOP | Recvel |
| --- | --- | --- |
| HRV | RMSSD desde R-R crudos; filtro 300–2000 ms; rechazo de ectópicos tipo Malik (20 % vs mediana local de 5 latidos); RMSSD "gap-aware"; **oculta el valor si hay sobreconteo** (`HRVAnalyzer.swift:435-561`) | SDNN agregado de HealthKit, **media de todas las muestras del día civil** mezclando vigilia y sueño; "hoy" cambia durante el día; sin mínimo de muestras (`HealthDataProvider.swift:246-256, 375-388`) |
| Baseline | EWMA winsorizada (vida media 14/21 noches), z robusto, estados **calibrating <4 / provisional / trusted ≥14 / stale >14 d** (`Baselines.swift:98-102`) | Mediana + filtro MAD (bien diseñado), pero `deviation` **emite con un solo día de historial** (`BaselineEngine.swift:22-26`) |
| FC máxima | Tanaka 208−0.7·edad, o percentil 99.5 observado con ≥600 muestras; override manual en Ajustes (`StrainScorer.swift:154-184`, `SettingsView.swift:447-476`) | `max(pico de la sesión × 1.03, 180)`: sin edad, sin método publicado, **distinta en cada sesión**; zonas, strain y drivers de Bio Age lo heredan (`HealthDataProvider.swift:525`) |
| Strain / carga | Karvonen + TRIMP de Edwards por zonas (Banister opcional); ≥600 muestras o ≥10 min; tope de 2 min por muestra para no inflar huecos | Energía activa/mediana·68 + zonas·32; **base 650 kcal inventada** sin historial; **strain = 0 sin energía** (`ScoreEngine.swift:71-88`) |
| Carga longitudinal | CTL/ATL/TSB con EWMA 42/7 d; **un día faltante rompe la serie, nunca se rellena con 0**; "Building N of 42 days" (`TrainingLoadEngine.swift:19-21`) | No existe |
| HRR | Elegible solo con ≥120 s sobre 70 % FCmáx; mediana ±15 s con ≥3 muestras; huecos >10 s rompen; 1/2/5 min; nunca interpola; 12 tests | Última muestra de los 45 s previos **o cualquier muestra anterior**; solo si bajó; sin cobertura mínima; **0 tests**; la tarjeta rellena `[0,0,0,0]` sin datos (`HealthDataProvider.swift:504-519`, `FitnessView.swift:1378`) |
| Estrés diurno | Máscara de movimiento (descarta la hora con ≥30 % ambulatorio y la siguiente si FC sigue +8 lpm); ≥300 muestras/h o `.noData`; dice contra qué referencia puntuó | `(FC horaria − RHR)/30` con **RHR 58 por defecto**; no excluye entrenos ni exige cobertura (`HealthDataProvider.swift:574-592`) |

**Pero** en los scores compuestos los dos son heurísticas propias: Charge de NOOP (pesos 0.55/0.20/0.15/0.05/0.05 sin cita, HRV en ms lineales mientras su Readiness usa ln; el r≈0.71 vs Oura no tiene comando que lo regenere, violando su propia regla R3) y Recovery de Recvel (62+115·Δ, 62+120·Δ, pesos 0.31/0.22/0.25/0.12/0.10). Y NOOP tiene un **ACWR mal implementado** (`ReadinessEngine.swift:204-214`: `compactMap` comprime días faltantes, ventana acoplada, 14 días mínimos para una ventana de 28) — justo lo que su propio TrainingLoadEngine prohíbe. Recvel rechaza ACWR con argumento explícito (`ScoreEngine.swift:147-152`), y eso está bien.

### 1.2 Ciencia: NOOP implementa más fórmulas publicadas; Recvel cita más y tiene los dos motores mejor anclados

- **NOOP copia métodos publicados literalmente** en más sitios: Task Force 1996 y Malik 1989 (HRV), Karvonen/Edwards/Banister/Tanaka (strain y zonas), Nes 2011 + Kurtze 2008 (Fitness Age, coeficientes literales), Keytel 2005 y Harris-Benedict revisada (calorías), Baevsky (índice de estrés), Lomb-Scargle (dominio frecuencial). Tiene `docs/VALIDATION_PROTOCOL.md` con 8 reglas (prerregistro, nunca puntuar contra referencia propia, split temporal) y un benchmark reproducible del clasificador de sueño contra PSG (Walch 2019, n=31, kappa ≈0.36, con un residuo de REM **reconocido sin resolver**).
- **Recvel tiene los dos motores más trazables de los dos proyectos**: PhenoAge (Levine/Liu 2018, 9 analitos obligatorios, sin imputación, ≤6 meses, LOINC correctos) y FRIEND (Kaminsky 2015, tablas publicadas, sin extrapolar fuera de 20–79, confianza limitada por VO₂ estimado). El Body Age de NOOP (`VitalityEngine`) es una suma de hazard ratios "genéricos" sin cita, cuyo comentario contradice al código (dice 12 % por 1000 pasos, el coeficiente da 6.6 %). También tienen fuente las reglas de coaching de Recvel (campo `evidence` obligatorio), Mifflin-St Jeor y Epley/Brzycki.
- **Donde Recvel se aparta del método**: `BiomarkerEngine.swift:118` aplica `ln(CRP)` en **mg/L** cuando la Tabla 1 de Levine 2018 especifica **mg/dL**. Verificado analíticamente: como el término entra como ln, el efecto es una **constante de +2.44 años para todos los usuarios** (ln 10 × 0.09536762 / 0.090165), independiente del valor de CRP. El test (`EngineTests.swift:1243-1260`) valida la propia fórmula, no una referencia externa, y la lente de sangre se presenta con confianza "alta" (`:279`).

Conclusión: **citar no es implementar**. NOOP gana en método y disciplina de validación; Recvel gana en trazabilidad documental y en dos motores concretos, pero uno de ellos tiene un error de unidad que hay que corregir antes de reclamar fidelidad.

### 1.3 Calidad y precisión del dato: NOOP gana claramente

NOOP aplica una política de **"no fabricar"** de punta a punta: scores `Double?`, cuatro estados del valor (scored / carried con sello de fecha / calibrating con "N of 4 nights" y la causa / noData), Charge devuelve nil sin baseline y su fallback 58 no lo usa ninguna llamada de producción, horas de estrés sin datos quedan `.noData`, widgets y Watch pintan guion y "as of 2h ago" cuando el snapshot es viejo, las gráficas "levantan el lápiz" en los huecos.

Recvel tiene **valores inventados que llegan a UI, widget, Watch y base de datos**, todos verificados hoy:

| Dónde | Valor inventado | Línea |
| --- | --- | --- |
| Recovery sin señales | 58 | `ScoreEngine.swift:57` |
| Sleep sin datos | 50 | `ScoreEngine.swift:385` |
| Base de energía sin historial | 650 kcal | `ScoreEngine.swift:71, 200` |
| Curva de estrés sin RHR | 58 lpm | `HealthDataProvider.swift:586` |
| Alimento no reconocido | 260 kcal, 12/32/9 g | `NutritionEstimator.swift:17-28` |
| Tendencias y Home con dato ausente | 0 | `TrendsView.swift:13,106,124,134`, `DashboardView.swift:768-772` |
| Widget y Watch con una sola señal | 58 / 50 | `SharedSnapshotPublisher.swift:11-28` |
| Fitness sin dato | recovery 50, strain 0 | `FitnessView.swift:73-76` |
| Persistencia diaria | guarda los fallbacks como mediciones | `LocalStore.swift:32-51` |

`WellnessScore.value` es `Int` no opcional (`HealthModels.swift:459`): la arquitectura no puede expresar "sin dato". Además hay **fuga temporal**: `RecoveryInsightsEngine.swift:111-118`, `TrendsView` y `DashboardView` calculan la baseline de un día con **días posteriores** (`DetailViews.swift:1258-1259` sí lo filtra: incoherencia entre pantallas); Journal Pro cruza tags nocturnos con el recovery de esa misma mañana y cuenta respuestas por defecto como observaciones (`JournalProView.swift:675, 687-703`). Todo contradice `AI_CONTEXT.md:58`.

Matiz justo: parte de la ventaja de NOOP viene de controlar el hardware (R-R de WHOOP). Recvel está limitada a SDNN agregado de HealthKit. Pero los gates, los estados y la política de no fabricar son transferibles sin cambiar de fuente.

---

## 2. Correcciones de precisión en Recvel (antes de fusionar nada)

Por impacto. Son prerrequisito del plan de fusión: cualquier explorador o comparador construido encima de datos con ceros inventados heredaría el problema.

| # | Corrección | Evidencia | Criterio de aceptación |
| --- | --- | --- | --- |
| 1 | CRP a mg/dL en PhenoAge | `BiomarkerEngine.swift:118` | Caso de referencia **externo** (no derivado de la fórmula) reproduce ±0.05 años; el test antiguo se reemplaza |
| 2 | FC máx por Tanaka con override en perfil | `HealthDataProvider.swift:525` | Una sola FCmáx por persona, con fuente y fecha; zonas de todas las sesiones recalculadas con ella; `Zonas` con etiqueta "estimada"/"manual" |
| 3 | `WellnessScore.value` opcional y eliminación de fallbacks | tabla anterior | Ningún `?? 0`, `58`, `50`, `650` en scores, tendencias, widget, Watch ni `DailyScoreRecord`; instrumentos muestran estado "sin dato"/"calibrando" |
| 4 | Estimador sin macros inventados | `NutritionEstimator.swift:17-28` | Alimento desconocido ⇒ estado "no identificado" y entrada manual/porción |
| 5 | Baseline solo con pasado y mínimo de días | `RecoveryInsightsEngine.swift:111-118`, `TrendsView`, `DashboardView`, `BaselineEngine.swift:22-26` | Un día nunca usa días posteriores; `deviation` exige ≥7 días; prueba unitaria del contrato temporal |
| 6 | HRV nocturna/reposo con mínimo de muestras | `HealthDataProvider.swift:246-256` | Ventana de sueño o madrugada; ≥N muestras o nil; "hoy" no cambia a mediodía |
| 7 | HRR y curva de estrés con elegibilidad | `HealthDataProvider.swift:504-519, 574-592` | HRR solo con esfuerzo sostenido y cobertura ≥3 muestras en ±15 s; estrés excluye entrenos y marca horas sin cobertura; tests de extracción |
| 8 | Journal Pro: alineación noche→mañana y excluir respuestas por defecto | `JournalProEngine.swift:344`, `JournalProView.swift:687-703` | Tag nocturno de D se cruza con recovery de D+1; solo respuestas del usuario cuentan |
| 9 | Inconsistencias menores | textos "60 días" con 30 cargados; dos modelos de deuda de sueño (`InsightEngine` vs `SleepBank`); fuerza = 0 en inglés (`BiomarkerEngine.swift:311` filtra por "Fuerza"); OpenFoodFacts trata 100 g como porción; docs de estrés ("calm") y FRIEND ("20-89") obsoletos | Un solo modelo de deuda; filtro por tipo, no por nombre localizado; textos coherentes con la ventana real |

---

## 3. Plan de fusión: qué tomar de NOOP y dónde ponerlo

Regla general: **no se añade una pestaña ni un "More"**. Recvel tiene cinco dominios claros (Hoy, Diario, Nutrición, Ayuno, Entrenamiento) y cada pieza de NOOP se inserta en la pantalla que ya trata ese tema. Los ids de accesibilidad nuevos siguen la convención `<pantalla>.<sección>`.

### 3.1 Lógica (motores) — reimplementar como funciones puras en `Recvel/Services`, con tests numéricos contra valores calculables a mano

| Motor NOOP de referencia | Qué reimplementar | Archivo destino en Recvel | Quién lo consume |
| --- | --- | --- | --- |
| `Baselines.swift` | Estados de baseline `calibrating(n)/provisional/trusted/stale` sobre la mediana+MAD existente; mínimo de días; límites por métrica (HRV 5–250, RHR 30–120, resp. 4–40) | `BaselineEngine.swift` (extender) | `ScoreEngine`, `StressEngine`, instrumentos de Hoy, `MetricDetailView` (baseline punteada solo si trusted) |
| `HRZones.swift` + Settings | Tanaka + override + zonas editables crecientes, con fuente y fecha de vigencia | nuevo `CardioProfile` (SwiftData o `@AppStorage` JSON) + `ScoreEngine.zones` | `HealthDataProvider` (zonas por sesión), `StrainDetailView.zonesCard`, drivers de Bio Age |
| `HeartRateRecovery.swift` | Elegibilidad (≥120 s sobre 70 % FCmáx), FC final = mediana de últimos 30 s, caídas a 1/2/5 min con ±15 s y ≥3 muestras, huecos >10 s rompen | `HealthDataProvider` → extraer a `HeartRateRecoveryEngine.swift` | `heartRateRecoveryCard`, `workoutTimeline` de Strain |
| `TrainingLoadEngine.swift` | CTL/ATL/TSB con EWMA 42/7 d sobre la carga diaria **ya definida** en Recvel; sufijo contiguo; `building(n of 42)` | nuevo `TrainingLoadTrendEngine.swift` | Nueva tarjeta en `cardioGrid` (ver 3.2). **Presentar como forma/fatiga/frescura, nunca como riesgo de lesión** (regla anti-ACWR de `AI_CONTEXT.md:209-215`) |
| `DaytimeStress.swift` | Máscara de ejercicio/movimiento (workouts de HealthKit + hora posterior si FC sigue alta), cobertura mínima por hora, estados `noData` | `HealthDataProvider.loadActivation` → `StressEngine` | `StressHomeCard`, `StressDetailView` curva, widget |
| `ChargeBreakdownFormat.swift` | Contribuciones por factor en ±puntos contra baseline, con veredicto y confianza | `ScoreEngine.factors` ya existe: añadir `deltaPoints` y `confidence` | `recoveryDrivers` de Hoy, `driversCard` de Recovery |
| `WeeklyDigest` | Agregados semanales deterministas: media, Δ semana vs semana, Δ vs baseline, "mayores cambios", cobertura N/7 | nuevo `WeeklyDigestEngine.swift` | Hoja de resumen semanal (3.2) |
| `EffectRanker` + `BehaviorInsights` | Desfase 0/+1/+2 **declarado por el usuario o por el tipo de tag** (no "el mayor |d|"), control = ausencia registrada, n≥5 por grupo, confianza Solid/Building/Calibrating | `JournalProImpactEngine` y `RecoveryInsightsEngine` | `patternPreview`, `JournalInsightsView`, `RecoveryInsightsView` |
| `CaffeineLog.swift` | Dosis+hora, decaimiento 0.5^(t/5.5 h), hora límite = cama − 2 vidas medias, **sin inventar mg** | nuevo `CaffeineEngine.swift` sobre `HabitLog.numericValue/unit` | Diario (registro), `tonightPlanCard` y `daylightAndCaffeineCard` (consumo) |
| `WidgetSnapshot` staleness | Una sola decisión de frescura: `updatedAt` + día ancla; si es viejo, guion y "hace 2 h" | `RecvelSharedSnapshot` v3 + `SharedSnapshotPublisher` | Widgets, complicación, Watch, Live Activities |

**No reimplementar** (débil en NOOP o fuera de la línea de Recvel): Charge/Rest (pesos propios como los nuestros), ACWR, SleepDebt calibrado con n=1, Vitality/Body Age, RecoveryForecast (heurística sin prueba retrospectiva), clasificador de sueño propio, CircadianEngine (cosinor sobre FC con umbrales "unvalidated"), fusión multidispositivo BLE.

### 3.2 Pantallas y secciones — dónde entra cada cosa

| Función | Pantalla NOOP de referencia | Ubicación en Recvel | Qué cambia en esa pantalla |
| --- | --- | --- | --- |
| **Estado del valor (4 casos) + sello de fecha** | `ChargeDisplay` (`LiquidTodayView.swift:2779`) | Hoy → `recoveryHero`, `scoreRail`; detalles → `DetailHero` | El anillo sin dato no dibuja progreso: muestra guion y "Calibrando · 3 de 7 noches" o "Última noche · mar 20" si arrastra; Energy nunca arrastra ("ayer sería falso, no viejo") |
| **Editor de Hoy** | `TodayCustomizationSheet` + `EditableLayoutList` | Hoy → botón "Editar Hoy" al final (antes de `disclaimer`), como el "Editar secciones" de Entrenamiento; opción duplicada en `moreMenu` | Lista Mostradas/Ocultas, arrastrar, borrador con Guardar/Cancelar/Restablecer; orden en `@AppStorage("home.sections")`; secciones fijas: header, dayStrip y recoveryHero |
| **Explorador de métricas** | `MetricExplorerView/MetricDetailView` | Reescribir `TrendsView` (hoy 7 días, nil→0) como índice de métricas que abre el `MetricDetailView` existente | `MetricDetailView` ya tiene 30D/3M/6M/1Y: añadir chips **bloqueados hasta tener historia**, Δ vs periodo anterior de igual longitud ("sin periodo previo" si falta), baseline punteada solo si trusted, tabla de lecturas con fuente. Requiere historial persistente >30 d (3.4) |
| **Comparar 2 métricas** | `CompareView` | `MetricDetailView`, entre `chartCard` y `trendsCard`: los `siblingChips` pasan a admitir un segundo trazo | Overlay normalizado con min/máx reales en leyenda, una frase por par ("cuando X sube, Y tiende a…"), "N días solapados", nada si n<10 o |r|<0.3 |
| **Resumen semanal** | `WeeklyDigestView` | Hoy → tarjeta entre `planWeekSection` y `stressSection` (solo en "hoy"), que abre una hoja con el molde de `MorningReportView` y navegación semana anterior/siguiente | Determinista, sin LLM; exportable a PDF con `ImageRenderer` (como `TrendsReportSheet`) |
| **Procedencia y calidad** | `SourceBadge`, tabla con columna Source, `FusedRecordView` | Hacer público `DataProvenanceCard` (`DetailViews.swift:616`) y ponerlo en `MetricDetailView` tras `explanationCard`; `SourceBadge` en `FluidRecoveryHero` junto a la confianza | Asignar por fin `.insufficientHistory`; distinguir **ausente / sin actualización / señal insuficiente / no calculable**; sheet "fuentes difieren" solo cuando hay ≥2 bundles con el mismo tipo |
| **CTL/ATL/TSB** | `TrainingLoadCard` | Entrenamiento → `cardioGrid`, nueva tarjeta `fitness.trainingLoad` bajo `cardioLoadCard`; detalle como ruta nueva de `FitnessDetailSheet` | "Forma" como cabecera, crónica/aguda debajo, "Construyendo · 18 de 42 días"; copy sin riesgo de lesión |
| **HRR 1/2/5 min** | `WorkoutDetailView:173-212` | Entrenamiento → `heartRateRecoveryCard` (quitar `[0,0,0,0]`) y fila HRR en `workoutTimeline` de `StrainDetailView` | Guion cuando no es elegible, texto de por qué ("sin esfuerzo sostenido al final"), tendencia solo con ≥3 sesiones elegibles |
| **Perfil cardiovascular** | `SettingsView:447-476` | Ajustes → tarjeta nueva entre `profileCard` y `languageCard` | FCmáx "Auto · 190 lpm (Tanaka)" o manual; zonas en lpm siempre crecientes; fecha de vigencia; edad/sexo se leen de `NutritionProfile` |
| **Sueño corregible** | `SleepTimeEditor`, `userEdited`, Undo | `SleepDetailView` → botón "Corregir" en `sleepWindow` | Modelo `SleepOverride` nuevo (SwiftData): inicio/fin/siesta, sobrevive al refresco de HealthKit, muestra original y corrección, Undo ~7 s. Recalcular score y marcarlo "corregido" |
| **Cafeína por dosis** | `CaffeineLogCard` | Diario → `dayEntries` (sección manual de día): filas cantidad + hora; consumo en `tonightPlanCard` (Sueño) y `daylightAndCaffeineCard` (Energía) | Convierte el tag híbrido `late.caffeine` en registros con hora; "aprox. 45 mg activos a la hora de dormir · estimación"; si falta hora, pedirla, no inferirla |
| **Respaldo / exportación** | `BackupSyncView`, CSV/PDF por pantalla | Ajustes → tarjeta nueva entre Privacidad y `notificationCard` | Archivo versionado (comidas, diario, rutinas, planes, biomarcadores, overrides) con vista previa al restaurar; **sin claves de API**; CSV por dominio; aviso explícito si la carpeta elegida sincroniza a la nube. Cierra el "Missing" de `FEATURES.md` §A |
| **Atajos / App Intents** | Siri intents de NOOP | Nuevo grupo `Recvel/Intents` reutilizando deep links `recvel://` y `RecvelSharedSnapshot` | Primeras acciones: registrar agua/comida, abrir siguiente entrenamiento, iniciar ayuno, leer resumen de hoy (solo lectura). Nada que envíe datos fuera |
| **Watch: descanso, intervalos, respiración** | `WatchIntervalView`, `WatchBreatheView` | Watch → `ActiveWorkoutView` (descanso entre series e intervalos desde la plantilla del iPhone) + 4.ª página del TabView vertical para respiración | Reusar `BreathingTechnique` de iOS; configuración en iPhone, ejecución háptica en muñeca; estado `unavailable/denied/idle/active/saved` como ya hace `WatchWorkoutView` |
| **Live Activity de entrenamiento** | `LiftLiveActivity` | `RecvelWidgets` → `ActivityConfiguration` junto a `RecvelFastingLiveActivity`; manager calcado de `FastingLiveActivityManager`, iniciado desde `ActiveWorkoutSessionView` / `ActiveTimedRoutineView` | Ejercicio, serie, descanso con `Text(timerInterval:)` para que corra solo; `isStale` ⇒ guion. Depende de la **sesión persistente** (prioridad 2 de la revisión del 19 oct) |
| **Hábitos con desfase y confianza** | `InsightsHubView` | Diario → `patternPreview` y `JournalInsightsView` | Chip "misma noche / día siguiente", pill Sólido/Construyendo/Calibrando, n por grupo visible, "asociación, no causa" |

### 3.3 Componentes de design system a crear (en `GlassComponents.swift` o `Recvel/Views/Components/`)

| Componente NOOP | Equivalente a crear en Recvel | Reemplaza / reutiliza | Regla de datos ausentes |
| --- | --- | --- | --- |
| `ScoreStatePill` (solid/building/calibrating/live) | `ScoreStatePill` sobre `DataConfidence` + nuevo `BaselineState` | Hoy el texto de confianza va suelto en `DetailHero:145` y `FluidRecoveryHero` | — |
| `StatTile` (valor, Δ, sparkline, "sin periodo previo") | `MetricStatTile` | `DetailStatStrip` (`DetailViews.swift:348`) | valor `String?` ⇒ "—"; sparkline solo con ≥2 puntos |
| `TrendChart` con `segment` y `baselineValue` | `GapAwareTrendChart` (Swift Charts, series `[(date, value?, source)]`) | `DetailTrendCard`, `NeonTrendChart` (no maneja huecos), sparklines de `trendsHomeSection` | **levanta el lápiz** en nil; un punto aislado se dibuja como punto; baseline punteada solo si trusted |
| `DaytimeLoadLine` | Curva de activación por tramos | `StressDetailView` curva, widget | horas sin cobertura = hueco, nunca 0 |
| `SourceBadge` | `SourceBadge(text:tint:)` | texto plano de fuentes en `DataProvenanceCard` | máx. 2 fuentes "A + B" |
| `DataPendingNote` / `ComingSoon` / `SyncingHistoryNote` | Familia `EmptyStateNote(kind:)` con causa y siguiente paso | estados ad hoc de Journal (:292-333), `FitnessEmptyPlot`, `missingSleepCard` | distingue cargando / sin permiso / sin datos / insuficiente / no calculable |
| `EditableLayoutList` + `EditableLayoutDraft` | `SectionLayoutEditor` genérico | `FitnessSectionEditor` (solo 2 toggles) | — |
| `ChargeBreakdownSection` | `ScoreBreakdownList` (±pts, valor vs baseline, barra relativa, veredicto) | `recoveryDrivers`, `driversCard` | omite el "vs baseline" si no hay baseline |
| `YearHeatStrip` (nil = celda vacía) | reutilizar `HatchPattern`/`ReportRing(hatched:)` archivados en `RevelInspiredComponents/` | calendario de 30 días de Entrenamiento, `calendarCard` de Ayuno | celda ausente ≠ valor bajo |
| `SegmentedPillControl` con segmentos bloqueados | extender `windowPicker` de `MetricDetailView` | — | chip visible pero atenuado hasta tener historia |

Instrumentos propios de Recvel a corregir, no a sustituir: `HeroScoreRing`, `DashboardScoreInstrument`, `MiniGauge`, `ArcGauge` reciben `Int?` y, con nil, dibujan la pista vacía + guion (hoy pintan 50/58). `BioAgeTickDial(hasValue:)` ya es el precedente correcto.

### 3.4 Infraestructura necesaria para que lo anterior funcione

1. **Historial persistente de métricas diarias** (>30 días): hoy `DailyScoreRecord` solo guarda recovery/sleep/strain y `HealthDataProvider` relee 30 días en 5 instancias. Añadir un `DailyMetricRecord` (día, métrica, valor?, fuente, versión del algoritmo) con importación incremental y reconciliación de borrados de HealthKit. Es prerrequisito del explorador, comparador, CTL/ATL y resumen semanal.
2. **Un solo `HealthDataProvider` compartido** vía environment en vez de cinco instancias.
3. **`BaselineState` y `WellnessScore.value: Int?`** (sección 2, punto 3) — todo lo demás depende de esto.
4. **Snapshot compartido v3** con `updatedAt`, día ancla y campos opcionales, para la decisión única de staleness.
5. **Sesión de entrenamiento persistente** (`WorkoutSessionController`, ya priorizada el 19 oct) antes de Live Activity y Watch.

---

## 4. Patrones UX transversales a adoptar

1. **"Sin dato" nunca es cero.** Guion, pista vacía, hueco en la línea. Aplica a app, widget, Watch, Live Activity y persistencia.
2. **Cuatro estados del valor**: medido / arrastrado con sello de fecha / calibrando con progreso y causa / sin dato. Energía y Carga no se arrastran.
3. **Pendiente ≠ conclusión**: "Leyendo…", "Calculando…" distintos de "Sin datos". La sincronización se cuenta en pasos, nunca en un % inventado.
4. **Una decisión de frescura** por superficie: si el snapshot es viejo, "hace 2 h" y guion, no el número viejo.
5. **Procedencia en tres niveles**: badge en el hero, columna de fuente en tablas, hoja de discrepancia solo cuando hay conflicto real. Las estimaciones lo dicen: "aprox.", "estimación".
6. **Funciones experimentales marcadas**: pill "BETA", sección avanzada colapsada, consentimiento propio.
7. **Explicar el score**: factores en ±puntos, pesos visibles, metodología con la fórmula.
8. **Rangos honestos**: chips bloqueados hasta tener historia; Δ contra ventana anterior de igual longitud; baseline solo cuando es fiable.
9. **Correcciones del usuario respetadas**: sobreviven al refresco; Undo con texto distinto según el caso.
10. **Correlaciones con freno**: n mínimo, |r| mínimo, desfase explícito, confianza Sólido/Construyendo/Calibrando, "asociación, no causa".

---

## 5. Qué NO copiar de NOOP

- La pestaña "More" con ~28 filas, `SettingsView` de 3,474 líneas y el Test Centre: densidad de herramienta de escritorio. Recvel tiene cinco dominios y debe mantenerlos.
- Tres variantes de Home (Liquid, clásica, Coupled) y el doble eje de Effort 0–100/0–21.
- La simulación líquida a 60 Hz y la opacidad configurable: coste de rendimiento, y `LiquidVessel` pinta nil igual que 0, contradiciendo su propia regla.
- Interacciones de hover y 8 chips de rango: en iPhone bastan 4–5 rangos y scrubbing táctil.
- Coach con clave propia, selección de modelo, URL de servidor y conteo de tokens. Lo reutilizable es el launcher sin red y los chips contextuales, no la configuración.
- Sus motores débiles (sección 3.1, "No reimplementar").

## 6. Qué podría tomar NOOP de Recvel

Captura de comida con confirmación y corrección; biblioteca de planes (guardar, renombrar, ajustar, eliminar); ayuno con Live Activity; diario mental guiado; lentes Cardio/FRIEND y Sangre/PhenoAge separadas (tras corregir CRP); reglas de coaching con campo `evidence`; una sola Home con jerarquía fija y Liquid Glass sobrio.

---

## 7. Orden propuesto

| Fase | Entregable | Depende de | Aceptación |
| --- | --- | --- | --- |
| **0. Precisión** | Sección 2 completa: CRP, Tanaka+override, `value: Int?` sin fallbacks, estimador sin macros inventados, baseline solo pasado, HRV nocturna, HRR/estrés con elegibilidad, Journal alineado | — | Ningún número inventado en app/widget/Watch/persistencia; PhenoAge contra caso externo; tests de extracción de HealthKit |
| **1. Estados y explicabilidad** | `BaselineState`, `ScoreStatePill`, `EmptyStateNote`, estado del valor en 4 casos, `ScoreBreakdownList`, `GapAwareTrendChart`, staleness único | Fase 0 | Calibrando muestra "N de 7 noches" y causa; gráficas con huecos; widgets con guion y "hace 2 h" |
| **2. Historial y procedencia** | `DailyMetricRecord`, provider único, `DataProvenanceCard` público con 4 estados de ausencia, `SourceBadge` | Fase 1 | 30/90/365 días reales; borrados de HealthKit reconciliados; versión del algoritmo por fila |
| **3. Entrenamiento** | Perfil cardiovascular en Ajustes, HRR 1/2/5, CTL/ATL/TSB, sesión persistente, Live Activity de entreno | Fases 0–2 | Zonas estables y editables; HRR solo elegible; forma/fatiga sin lenguaje de lesión; sesión recuperable tras matar la app |
| **4. Exploración** | `TrendsView` como explorador, Comparar en `MetricDetailView`, resumen semanal + PDF | Fase 2 | Chips bloqueados por historia; Δ vs periodo anterior; una frase por par con n visible |
| **5. Diario y nutrición** | Hábitos con desfase y confianza, cafeína por dosis, sueño corregible | Fases 0–2 | Desfase declarado, control = ausencia registrada; mg nunca inventados; override sobrevive al refresco |
| **6. Personalización y portabilidad** | Editor de Hoy, respaldo/exportación, App Intents, Watch con descansos/intervalos/respiración | Fases 1–3 | Orden persistente; round-trip de respaldo sin claves; acciones de Atajos solo lectura/registro |

Cada fase compila y pasa `RecvelTests` + los UI tests del área en el simulador iPhone 16 Pro existente. Hardware real (Watch, haptics, HealthKit en campo) se valida aparte y no se marca como hecho por pasar el simulador.

## Estado de esta entrega

Solo documentación. No se modificó código ni se ejecutaron builds o tests. No se incorporó código, assets ni dependencias de NOOP. Los hallazgos de la sección 2 están identificados y **no corregidos**.
