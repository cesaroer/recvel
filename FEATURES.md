# FEATURES — inventario vivo de Recvel

**Última auditoría de código:** 16 julio 2026  
**Regla:** Done / Partial / Missing solo con evidencia en Swift (o ausencia explícita). No marcar Done por documentación sola.

**Inventario:** este archivo. Cross-links: `README.md`, `HANDOFF.md`.

---

## Fuentes consultadas (solo lectura)

| Fuente | Rol |
| --- | --- |
| `README.md` § Roadmap / Estado / **Sugerencias Grok** | Plan de producto + checklist canónica Grok |
| `COMPETITORS.md` § Sugerencias Grok / backlog | Matriz competitiva y prioridades |
| `README_APP.md` § Roadmap / Sugerencias Grok | Set paralelo (parcialmente desactualizado en P2) |
| `HANDOFF.md` | Estado verificado de implementación (foto; contrastar con código) |
| `AI_CONTEXT.md` | Contrato de scores / HealthKit / copy |
| `BEVEL_PRO_GAP_ANALYSIS.md` | Gaps vs Bevel Pro (capturas `bevelpro_features_*.PNG`) |
| `Calorie_AI_Research.md` §10–12 | Ayuno, nutrición IA, reglas clínicas 12.10 |
| `CalAI_Features_Analysis.md` | Wishlist onboarding Cal AI |
| `README_StressAndBio.md` | Stress / VO2 / Bio Age / Sleep Bank |
| `JOURNAL_SLEEP_RESEARCH.md` | Journal + umbrales de correlación |
| `~/.cursor/plans/home_stress_bio_vo2_*.plan.md` | Plan Stress/VO2/Bio Age (**no editado**) |
| `~/.cursor/plans/multi_emotion_fasting_logs_*.plan.md` | Multi check-in emociones/feeling (**no editado**) |

**Sugerencias Grok:** no hay archivo aparte ni imagen/PDF con ese nombre. La lista canónica vive en **`README.md` → sección «Sugerencias Grok»** (espejo en `COMPETITORS.md` y `README_APP.md`).

---

## A. Inventario completo actual

Leyenda: **Done** = usable en app · **Partial** = existe pero incompleto / heurístico / sin paridad de promesa.

### Navegación y shell

| Feature | Estado | Evidencia |
| --- | --- | --- |
| Tabs Hoy / Journal / Nutrición / Ayuno / Fitness | Done | `AppTab`, `ContentView` |
| Tab bar Liquid Glass + FAB acciones rápidas | Done | `GlassComponents`, `TabQuickAction` |
| Plan / Metas fuera del tab bar (Home + FAB) | Done | `PlanHomeCard` → `PlanView`; `wantsPlan` |
| Tendencias dentro de Home (no tab) | Done | `TrendsView` desde `DashboardView` |
| Onboarding 5 pasos + reabrir desde Ajustes | Done | `OnboardingView`, `SettingsView` |
| Ajustes, Laboratorio (mocks), wipe local | Done | `SettingsView`, `LaboratoryView`, `LocalStore` |
| Sistema visual Liquid Glass | Done | `GlassComponents` (`HeroScoreRing`, `ArcGauge`, etc.) |

### Home / Dashboard

| Feature | Estado | Evidencia |
| --- | --- | --- |
| Hero Recovery + instrumentos Sleep / Strain / Energy | Done | `DashboardView`, `ScoreEngine` |
| Briefing / acción del día | Done | `InsightEngine` |
| Calendario semanal + mensual con anillos segmentados | Done | `HomeCalendarViews`, `HomeDayRingEngine` (chips ≤2) |
| Activación fisiológica 24 h (FC vs reposo) | Done | `HealthDataProvider` + UI Home/Stress |
| Stress (bandas Excelente→Sobrecarga) | Done | `StressEngine`, `StressHomeCard`, `StressDetailView` |
| Emociones multi/día (tope 6) + gráfica + consejo | Done | `EmotionLog`, `HealthIntelligenceViews` |
| Respiración guiada | Done | `BreathingExerciseView` |
| VO2 Max (valor, fecha, tendencia, detalle) | Done | `HealthDataProvider` + `VO2DetailView` |
| Bio Age (lentes FRIEND + PhenoAge) | Done | `BiomarkerEngine`, `BioAgeProViews` |
| Plan resumen en Home | Done | `PlanHomeCard` |
| Workouts de la semana en Home | Done | `HomeWeekWorkoutsCard` |

### Detalles Recovery / Strain / Sleep / Energy

| Feature | Estado | Evidencia |
| --- | --- | --- |
| Recovery con factores, baseline, confianza, palanca | Done | `RecoveryDetailView`, `InsightEngine` |
| SpO2 + temperatura de muñeca en Recovery | Done | snapshot + cards en `DetailViews` |
| Strain: objetivo adaptable, zonas, timeline, margen | Done | `StrainDetailView` |
| Sleep: duración, eficiencia, consistencia, etapas si HK las da | Done | `SleepDetailView` |
| Sleep Bank (ventana ~14 d) | Done | `SleepBankEngine` |
| Coaching de sueño con evidencia citada | Partial | `SleepCoachingEngine` / recursos en detalle; no en todos los insights |
| Energy: balance Recovery/Sleep/Strain + ritmo | Done | `EnergyDetailView` |
| Energy Bank continuo intradiario | Missing | score diario sí; curva carga/descarga no |
| MetricDetailView / recursos por métrica | Done | `DetailViews` |
| Clasificación aptitud FRIEND | Done | `FitnessClassificationEngine` |

### Plan / Esta noche / disciplina de sueño

| Feature | Estado | Evidencia |
| --- | --- | --- |
| Metas semanales editables (entrenos, noches, carga, nutrición, check-in) | Done | `PlanView` |
| Esta noche: ciclos ~90 min, wind-down, notifs rutina/cama | Done | `TonightDetailView`, `SleepCyclePlanner`, `SleepWindDownScheduler` |
| Disciplina vs plan (noches medidas) | Done | `SleepDisciplineEngine` |
| Recordatorios locales matutino / cama | Done | `LocalNotificationManager` + `NotificationRouter`: la matutina abre el Reporte de la mañana por deep link |

### Journal

| Feature | Estado | Evidencia |
| --- | --- | --- |
| Journal Pro (wake-to-wake, semana/mes, día/noche, tags) | Done | `JournalView` en `JournalProView.swift` (legacy en `LegacyJournalView`) |
| Tags automáticos HealthKit + configurables + sensibles off | Done | `JournalProEngine`, `JournalTagConfiguration` |
| Insights Recovery/Sleep con umbral 5/5 | Done | motor Journal + scores |
| Diario mental guiado | Done | `MentalJournalEntry`, `MentalJournalView` |
| Tags de ciclo (menstruación, SPM, etc.) | Partial | catálogo sí; sin cruce dedicado ciclo × HRV/sueño |
| Agua / cafeína con meta-hora y cantidad rica | Partial | HK lee agua/cafeína; Journal tags; no meta-hora completa tipo Grok |

### Nutrición

| Feature | Estado | Evidencia |
| --- | --- | --- |
| Setup Mifflin-St Jeor + perfil | Done | `NutritionSetupView`, `NutritionPlanEngine` |
| Log texto / voz / foto / barcode + edición de porción | Done | `NutritionView`, `NutritionEstimator`, OFF barcode |
| Plan del día / siguiente comida / plan mañana | Partial | motor local simple; no meal planner multi-día Pro |
| Clasificador Food-101 Core ML | Missing | aún `VNClassifyImageRequest` genérico |
| Gemini opt-in (Keychain) | Partial | flag experimental; no path producción |
| Reglas clínicas 12.10 en nutrición (SCOFF, disclaimer clínico, anti-streaks) | Missing | no hay screening/disclaimer 12.10 en `NutritionSetupView` / `NutritionView` |

### Ayuno

| Feature | Estado | Evidencia |
| --- | --- | --- |
| Protocolos + custom, anillo, fases matizadas | Done | `FastingView`, `FastingEngine` |
| Screening de exclusión (contraindicaciones) | Done | `FastingScreeningView` |
| Feeling multi (tope 6), gráfica, consejo terminar | Done | `FastingFeelingLog` |
| Stats neutrales, calendario, correlación ayuno↔Recovery | Done | `recoveryImpact` (≥3/3 días) |
| Live Activity de ayuno | Done | `FastingLiveActivityManager`, Lock Screen y Dynamic Island; reinicia si cambia la hora inicial |

### Fitness

| Feature | Estado | Evidencia |
| --- | --- | --- |
| Calendario 30 d, Strain vs target, carga cardio, focus, HRR | Done | `FitnessView`, `FitnessEngine` |
| Plantillas de entrenamiento: fuerza, cardio, movilidad, recuperación, rendimiento y desafío | Partial | editor y ejecución local compartidos; fuerza registra series×reps×kg y otras modalidades tiempo; sin rutina estructurada sincronizada al Watch ni periodización IA |
| Rutina semanal / onboarding de plantillas | Done | `WeeklyRoutineSection` |
| Agenda pro: split de fuerza (full body/torso-pierna/PPL/grupo por día) + deporte de cardio + minutos por día | Done | `SplitType`/`CardioSport`, onboarding de 6 pasos, retro-compatible con agendas guardadas |
| Series persistidas por ejercicio + 1RM estimado (Epley+Brzycki, gate ≤10 reps) | Done | `ExerciseSetLog` + `OneRepMaxEstimator`; progresión por ejercicio reusa `MetricDetailView` |
| Emoji post-entreno (RPE 1-10) + esfuerzo de Apple Health (iOS 18, solo lectura) | Done | `WorkoutFeeling`, `HKWorkoutEffortScore` manual>estimado con etiqueta honesta |
| Coaching del día siguiente con evidencia (readiness muscular 48h, timing vs sueño, deload, moderación) | Done | `TrainingCoachingEngine` en la tarjeta de hoy de la agenda |
| Rutinas pre-hechas por split con badge ("Ideal para hipertrofia") + preview editable en el wizard | Done | `PresetRoutineCatalog` (8 presets), materialización con dedupe al guardar |
| Días rediseñados: cuántos días + tiempo → semana sugerida editable por tap (fuerza/cardio/descanso) | Done | `canonicalDays` espaciados 48-72h, mini-coach en vivo |
| Coach de rutina: califica la semana en el review y SIEMPRE en la agenda (balanceada / pocos descansos / variar en 4-6 semanas) | Done | `RoutineAssessmentEngine` + `RoutineCoachCard` |

### HealthKit / datos / baselines

| Feature | Estado | Evidencia |
| --- | --- | --- |
| HRV, RHR, respiración, sueño, workouts, pasos, energía, VO2 | Done | `HealthDataProvider` |
| SpO2, temp muñeca, daylight, agua, cafeína, peso, grasa, LBM, PA | Done | lectura en provider |
| Baselines mediana/MAD, confianza, estados vacío/parcial | Done | `BaselineEngine`, `ScoreEngine` |
| Ciclo menstrual HealthKit × scores | Missing | tags Journal; sin UI de fase × Recovery/HRV |
| Clinical Records / FHIR opt-in (PhenoAge labs) | Partial | `ClinicalRecordsImporter` |

### Inteligencia / plataforma pendiente

| Feature | Estado | Evidencia |
| --- | --- | --- |
| Insights deterministas + briefing | Done | `InsightEngine` |
| Coach Q&A conversacional local | Missing | sin chat/Foundation Models coach |
| Widgets Home / Lock Screen | Done | Readiness + tablero fisiologico en `RecvelWidgets` |
| Live Activities / Dynamic Island | Done | ayuno activo, progreso temporal y deep link |
| Companion watchOS | Partial | briefing, metricas, complicacion y workout con FC/energia/distancia; falta validacion fisica |
| Export CSV / respaldo | Missing | sin `fileExporter` / export de datos |
| Snapshot bajo demanda (~2 min) | Missing | — |
| Validación Apple Watch real (campo) | Missing | P0 de producto; no verificable en simulador |

---

## B. Plan original vs actual

Plan original = módulos/roadmap de `README.md` + backlog `COMPETITORS.md` + propuestas `Calorie_AI_Research` / StressAndBio, contrastado con código.

| Feature original | Estado | Nota |
| --- | --- | --- |
| Today: Recovery / Strain / Sleep / Energy | Done | Núcleo P0 en simulador |
| Baselines + confianza + explicabilidad | Done | `BaselineEngine` / detalles |
| Estados sin datos / permisos parciales | Done | empty + quality flags |
| Stress / activación (wellness, no diagnóstico) | Done | Stress + curva FC; emociones separadas |
| Energy Bank continuo tipo Body Battery | Missing | Solo score Energy diario |
| Journal + correlaciones (umbral 5/5) | Done | Journal Pro |
| Diario mental | Done | `MentalJournalEntry` |
| Nutrición foto/texto/voz + confirmación | Partial | Pipeline sí; Vision genérico |
| Nutrición barcode + OFF | Done | vía imagen |
| Plan adaptativo / metas | Done | fuera del tab bar |
| Tendencias longitudinales | Done | `TrendsView` en Home |
| Fitness / workouts / zonas | Done | tab Fitness |
| Strength builder estructurado | Partial | plantillas + sesión; no Watch sync |
| Ayuno intermitente + screening | Done | tab Ayuno (antes solo propuesta §10) |
| Correlación ayuno ↔ Recovery | Done | `recoveryImpact` |
| VO2 Max UI | Done | Home + detalle |
| Bio Age wellness / PhenoAge | Done | lentes separadas |
| Sleep Bank + plan Esta noche + disciplina | Done / Partial | Bank + plan Done; coaching citas Partial |
| SpO2 en producto | Done | Recovery detail |
| Ciclo menstrual × HRV/sueño | Missing | tags sí; cruce no |
| Coach conversacional on-device | Missing | insights sí, chat no |
| Morning Report rico | Done | hoja propia con Recovery, sueño, acción y margen; 3 entradas |
| Widgets / Live Activities | Done | dos widgets iOS + Live Activity de ayuno |
| Apple Watch companion | Partial | briefing, senales, complicacion y workout; hardware pendiente |
| Food-101 / VLM local producción | Missing | investigación sí |
| Reglas clínicas 12.10 (nutrición) | Missing | ayuno sí tiene screening |
| Snapshot bajo demanda | Missing | — |
| Export / backup | Missing | — |
| Citas científicas en UI de insights | Partial | en Sleep/respiración/recursos; no en todos los insights |
| Sin backend / sin premium v1 | Done | contrato de producto |

**Conteo plan original (tabla B):** Done **25** · Partial **7** · Missing **9**

---

## C. Sugerencias Grok

Fuente canónica: `README.md` § «Sugerencias Grok» (julio 2026).  
`README_APP.md` está **desactualizado** en P2 (marca VO2/Stress/Bio Age como pendientes; el código y `README.md` ya los tienen).

### P0 — Hábito diario y confianza nutricional

- [x] **Widgets Home Screen / Lock Screen** (Recovery, Strain, Sleep) — Done
- [x] **Morning Report rico** — Done (`MorningReportView`; notif sobria + deep link, auto-apertura diaria y enlace en Home)
- [ ] **Food-101 Core ML** — Missing (`VNClassifyImageRequest`)
- [ ] **Reglas de seguridad clínica 12.10 en nutrición** — Missing (ayuno ya tiene screening; nutrición no)
- [ ] **Validación en Apple Watch real** — Missing (proceso de campo, no feature de UI)

### P1 — Scores memorables, aprendizaje y coaching local

- [ ] **Batería de energía continua** (nombre propio) — Missing
- [ ] **Journal más rico** (agua/cafeína hora, alcohol cantidad; ayuno↔Recovery) — Partial  
  - Ayuno↔Recovery: **Done** (supersede parcial del ítem)  
  - Agua/cafeína/alcohol ricos: **Partial**
- [ ] **Coach Q&A local** — Missing
- [ ] **Fuentes científicas citadas en la UI de insights** — Partial (detalle Sleep/recursos sí; briefing genérico no)
- [ ] **Export CSV / respaldo** — Missing

### P2 — Paridad de mercado

- [x] **Companion watchOS + complicaciones** — Partial: producto v1 listo; validacion fisica pendiente
- [x] **Live Activities / Dynamic Island** — Done para ayuno; workout queda como ampliacion
- [x] **Bio Age trazable por lentes** (FRIEND + PhenoAge) — Done *(supersede: antes “edad biológica opt-in” genérica)*
- [ ] **Ciclo menstrual × HRV/sueño** — Missing
- [ ] **Strength builder** (series × reps × peso) — Partial *(plantillas/sesión locales; sync Watch pendiente)*
- [ ] **Snapshot bajo demanda** — Missing
- [ ] **Smart alarm / haptic bedtime** — Partial *(notifs de cama/wind-down; no alarm háptica Watch)*
- [x] **VO2 max con protagonismo UI** — Done · SpO2: Done en Recovery (README Grok aún dice “sin load/UI” → **superseded**)
- [x] **Sección Home Stress** — Done
- [x] **Bio Age explicable** — Done *(duplicado conceptual del ítem Bio Age lentes; mismo Done)*

### Conteo checklist Grok (20 checkboxes en `README.md`)

| Estado | Cantidad |
| --- | ---: |
| **Done `[x]`** | **4** |
| **Partial** (sigue `[ ]`, hay avance en código) | **5** |
| **Missing** | **8** |

- Done: widgets, Live Activity de ayuno, Bio Age lentes, VO2 UI, Home Stress, Bio Age explicable
- Partial: companion watchOS (hardware pendiente), Journal rico, citas en UI, Strength builder, smart alarm/bedtime
- Missing: Food-101, reglas 12.10 nutri, validación Watch, batería energía, coach Q&A, export, ciclo × HRV, snapshot

---

## D. Agenda semanal profesional → Plan semanal v2

- [x] Perfil de experiencia, objetivo, fase y evento opcional.
- [x] Fuerza por split y cardio por deporte.
- [x] Configuración por día: foco, duración, RPE objetivo, intención, hora y flexibilidad.
- [x] Carga prevista y ejecutada mediante sRPE, con Apple Health cuando existe esfuerzo asociado.
- [x] Registro previo local de energía, molestias, motivación y dolor/limitación.
- [x] Coaching contextual con Recovery, esfuerzo previo, grupos musculares, racha, sueño y horario.
- [x] Compatibilidad con agendas JSON anteriores y progreso de 1RM estimado existente.
- [x] **Plan semanal v2 (20 jul 2026):** Plan semanal + Plantillas de entrenamiento, biblioteca de planes guardables (`WeeklyPlanLibraryStore`: aplicar/renombrar/duplicar/eliminar/eliminar todos), gestor de rutinas con "eliminar todas", wizard rápido de 4 pantallas + modo avanzado (fase, editor por día, marcas 1RM), botón Atrás, tipos de sesión más allá del gimnasio (movilidad, recuperación/fisioterapia, técnica, pliometría, velocidad, contraste) con parámetros propios (contactos, bloques de contraste, reps × metros, zona FC, %1RM, nota), editor de día desde la tira semanal, revisión con "Qué esperar de este plan" (`PlanExpectationEngine`), coaching consciente de sesiones neurales y días de recuperación (`plannedKind`).
- [x] **Desafío diario y plantillas unificadas (20 jul 2026):** toggle opt-in en «¿Qué incluye tu semana?»; mini-rutina ligera distinta al estímulo del día (upper↔lower, anti-overlap). Rutinas prefabricadas, cardio, movilidad, recuperación, rendimiento y desafíos son `WorkoutTemplate`, aparecen en Plantillas y usan el mismo editor. Cardio = un ejercicio + minutos; `TemplateCodec` soporta repeticiones y tiempo. Motor: `DailyChallengeEngine`.

- [x] **Mecánica del ejercicio (25 jul 2026):** botón «Ver mecánica del ejercicio» en cada tarjeta de la sesión activa y en la «i» de la biblioteca → `ExerciseMechanicsSheet` con demostración animada (dos fotogramas alternados tipo gif, play/pausa, respeta Reduce Motion), posición inicial, ejecución paso a paso, claves y errores comunes. Catálogo propio en español (`ExerciseMechanicsCatalog`, cobertura 1:1 con `ExerciseLibrary`, verificada por test) e imágenes empaquetadas de free-exercise-db (Unlicense, dominio público) → funciona sin conexión.

- [x] **Mapa muscular y tempo de la demostración (27 jul 2026):** cada mecánica abre con la lámina anatómica (frente y espalda, músculo principal en rojo y secundario en ámbar, con leyenda) compuesta desde los SVG de wger; el fundido entre los dos fotogramas pasó a un ciclo lento de 5 s con pausa en los extremos y botones Inicio/Fin en pausa. Límite: no existe fuente libre con animaciones ilustradas por ejercicio; las láminas tipo workoutingym.com son material con derechos.

- [x] **Morning Report rico (27 jul 2026):** hoja «Reporte de la mañana» (`MorningReportView` + `MorningReportEngine`) con Recuperación y la señal que más restó, sueño + banco de 14 d, la acción del día y el margen de carga con la sesión planeada. Tres entradas: deep link `recvel://morning` desde la notificación (`NotificationRouter`), apertura automática una vez al día dentro de la ventana matutina, y enlace fijo bajo el título de Home. Cierra el P0 «Morning Report rico» del README §Sugerencias Grok. Diseño propio en la línea de la pantalla Bio Age de la referencia: fondo de nebulosa y estrellas, dial doble (Recuperación fuera, Energía dentro) con reveal por partículas, y módulos de instrumento. Métricas: los 4 scores, sueño + banco 14 d, margen de carga + sesión, señales de la noche (HRV, FC reposo, respiración, SpO₂, temp. muñeca con rango personal), estrés + ánimo y ayuno + nutrición. Componentes de la versión anterior archivados en `Recvel/Views/RevelInspiredComponents/`.

Fuente metodológica y límites: TRAINING_PLANNER_PRO.md.

## E. Gaps prioritarios

Top missing/partial con más impacto diario (alineado a Grok P0 + Bevel gap + HANDOFF):

1. **Food-101 Core ML + reglas 12.10 en nutrición** — visión genérica + sin screening/disclaimer clínico de conteo.
2. ~~Morning Report rico~~ — **hecho el 27 jul 2026** (§D).
3. **Validación Apple Watch real** — scores P0 dependen de calidad de muestras, zonas, WatchConnectivity y batería.
4. **Batería de energía continua / Energy Bank propio** — lectura intradía memorable y accionable.
5. **Coach Q&A local / export** — explicabilidad conversacional y portabilidad sin backend.

Menciones cercanas: Live Activity de workout, fuerza estructurada en Watch y ciclo × HRV.

---

## Cómo mantener este documento

1. Tras cerrar un feature, actualizar §A y la fila en §B/§C con evidencia de archivo Swift.
2. Si cambia la lista Grok en `README.md`, sincronizar §C aquí (esta es la vista de **estado vs código**).
3. No editar `~/.cursor/plans/*`; si un plan se completa, reflejarlo solo aquí / en HANDOFF.

---

*Documento generado para descubrir el inventario completo en un solo sitio. No sustituye `AI_CONTEXT.md` ni la investigación en `Calorie_AI_Research.md`.*
