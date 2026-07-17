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
| Recordatorios locales matutino / cama | Partial | `LocalNotificationManager` (texto genérico, no Morning Report rico) |

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
| Live Activity de ayuno | Missing | sin ActivityKit |

### Fitness

| Feature | Estado | Evidencia |
| --- | --- | --- |
| Calendario 30 d, Strain vs target, carga cardio, focus, HRR | Done | `FitnessView`, `FitnessEngine` |
| Fuerza: minutos HK + plantillas series×reps×kg + sesión activa | Partial | builder local sí; sin companion Watch ni periodización IA |
| Rutina semanal / onboarding de plantillas | Done | `WeeklyRoutineSection` |

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
| Widgets Home / Lock Screen | Missing | sin WidgetKit |
| Live Activities / Dynamic Island | Missing | sin ActivityKit |
| Companion watchOS | Missing | solo iPhone + HK |
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
| Morning Report rico | Partial | notif genérica «briefing listo» |
| Widgets / Live Activities | Missing | — |
| Apple Watch companion | Missing | previsto en README, no código |
| Food-101 / VLM local producción | Missing | investigación sí |
| Reglas clínicas 12.10 (nutrición) | Missing | ayuno sí tiene screening |
| Snapshot bajo demanda | Missing | — |
| Export / backup | Missing | — |
| Citas científicas en UI de insights | Partial | en Sleep/respiración/recursos; no en todos los insights |
| Sin backend / sin premium v1 | Done | contrato de producto |

**Conteo plan original (tabla B):** Done **24** · Partial **6** · Missing **11**

---

## C. Sugerencias Grok

Fuente canónica: `README.md` § «Sugerencias Grok» (julio 2026).  
`README_APP.md` está **desactualizado** en P2 (marca VO2/Stress/Bio Age como pendientes; el código y `README.md` ya los tienen).

### P0 — Hábito diario y confianza nutricional

- [ ] **Widgets Home Screen / Lock Screen** (Recovery, Strain, Sleep) — Missing
- [ ] **Morning Report rico** — Partial (notif básica; no pantalla/payload rico)
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

- [ ] **Companion watchOS + complicaciones** — Missing
- [ ] **Live Activities / Dynamic Island** — Missing
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
| **Missing** | **11** |

- Done: Bio Age lentes, VO2 UI, Home Stress, Bio Age explicable  
- Partial: Morning Report, Journal rico (ayuno↔Recovery ya Done dentro del ítem), citas en UI, Strength builder, smart alarm/bedtime  
- Missing: widgets, Food-101, reglas 12.10 nutri, validación Watch, batería energía, coach Q&A, export, watchOS, Live Activities, ciclo × HRV, snapshot  

---

## D. Gaps prioritarios

Top missing/partial con más impacto diario (alineado a Grok P0 + Bevel gap + HANDOFF):

1. **Widgets Home / Lock Screen** — sin ellos el loop glanceable lo ganan Athlytic/Bevel.
2. **Food-101 Core ML + reglas 12.10 en nutrición** — visión genérica + sin screening/disclaimer clínico de conteo.
3. **Morning Report rico** — hoy solo notif genérica; falta Recovery/sueño/acción/margen Strain en el payload o pantalla.
4. **Validación Apple Watch real** — scores P0 dependen de calidad de muestras, zonas y notifs en dispositivo.
5. **Batería de energía continua / Energy Bank propio** — o, si se prioriza hábito: **coach Q&A local** / export; el quinto gap “de producto memorable” más citado es la batería unificada.

Menciones cercanas: Live Activities (ayuno/workout), ciclo × HRV, companion watchOS.

---

## Cómo mantener este documento

1. Tras cerrar un feature, actualizar §A y la fila en §B/§C con evidencia de archivo Swift.
2. Si cambia la lista Grok en `README.md`, sincronizar §C aquí (esta es la vista de **estado vs código**).
3. No editar `~/.cursor/plans/*`; si un plan se completa, reflejarlo solo aquí / en HANDOFF.

---

*Documento generado para descubrir el inventario completo en un solo sitio. No sustituye `AI_CONTEXT.md` ni la investigación en `Calorie_AI_Research.md`.*
