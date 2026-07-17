# Bevel Pro → Recvel: gap analysis

**Fecha:** 15 julio 2026  
**Alcance:** comparación honesta entre lo que Bevel vende como **Bevel Pro** (paywall / Manage Subscription) y lo que Recvel ya tiene en código + docs.  
**No es paridad de producto:** Recvel es local-first, sin suscripción en v1; Bevel Pro es un tier de pago con IA en la nube y amplitud de biomarcadores. El objetivo es priorizar qué cerrar, qué refinar y qué no copiar.

## Fuentes Bevel Pro (este análisis)

Capturas de la UI de suscripción / paywall en el repo:

| Archivo | Qué muestra |
| --- | --- |
| [`Bevel_references/bevelpro_features_0.PNG`](Bevel_references/bevelpro_features_0.PNG) | **Manage Subscription**: Free vs Pro (checks verdes / X rojas). Free = tracking Sleep/Strain/Recovery, Nutrition & Fitness, Stress Score & Energy Bank. Pro = Bevel Intelligence (+ check-ins, meal planning, training plans, custom insights), Biological Age, Health Records import. |
| [`Bevel_references/bevelpro_features_1.PNG`](Bevel_references/bevelpro_features_1.PNG) | Paywall "Start your health journey…": Optimize Recovery, Personalized Training Plans, Easy Nutrition Tracking (AI), Improve Sleep Quality, Identify Stress Triggers, Track 390+ Biomarkers, Understand Your Cycle (parcial). |
| [`Bevel_references/bevelpro_features_2.PNG`](Bevel_references/bevelpro_features_2.PNG) | Continuación del listado: 390+ Biomarkers, Understand Your Cycle, Track Habits & Symptoms, Advanced Fitness Metrics, Bevel Intelligence, Contextual Intelligence, Biological Age (parcial). |
| [`Bevel_references/bevelpro_features_3.PNG`](Bevel_references/bevelpro_features_3.PNG) | Cierre del listado: Habits & Symptoms, Advanced Fitness, Bevel Intelligence, Contextual Intelligence, Biological Age, Health Records. Pricing Yearly/Monthly + "Start Free for 7 days". |

**Contexto adicional del repo (no es la fuente primaria de este gap, pero alinea el mapeo):** `COMPETITORS.md` (sección Bevel), `README.md`, `HANDOFF.md`, `AI_CONTEXT.md`, `README_StressAndBio.md`, `JOURNAL_SLEEP_RESEARCH.md`, videos en `Bevel_references/` (`bevel_reference.mp4`, `Bevel_ref_2.mp4`, `bevelworkout.mp4`).

**Cómo se encontraron las fuentes:** búsqueda de archivos `bevelpro_features_*` bajo el workspace; ubicados en `Bevel_references/` como PNG (también `bevelpro_features_0`). Glob por nombre falló al inicio por mayúsculas `.PNG` / carpeta; `find -iname '*bevel*'` las localizó.

---

## 1. Qué ofrece Bevel Pro (agrupado por tema)

### Recovery / readiness (Free tracking + Pro coaching)

- Tracking de **Sleep, Strain & Recovery** (Free — `_0`).
- Promesa Pro de **Optimize Your Recovery**: "Know when to push and when to rest" (`_1`).
- **Stress Score & Energy Bank** en Free (`_0`); Pro añade interpretación vía Intelligence / Contextual Intelligence (`_2`, `_3`).

### Sleep

- Tracking de sueño en Free (`_0`).
- **Improve Sleep Quality**: "Uncover patterns in your sleep data" (`_1`) — patrón + insights, no solo score.

### Stress

- Stress Score en Free (`_0`).
- **Identify Stress Triggers**: "Find patterns behind your stress" (`_1`).

### Journal / habits / accountability

- **Daily check-ins & accountability** bajo Bevel Intelligence (Pro, `_0`).
- **Track Habits & Symptoms**: "Find correlations in your routine" (`_2`, `_3`).

### Training / fitness

- Nutrition & Fitness **tracking** en Free (`_0`).
- **Personalized Training Plans** / **Training & fitness plans** (Pro, `_0`, `_1`).
- **Advanced Fitness Metrics**: "See your performance trends" (`_2`, `_3`).

### Nutrition

- Nutrition **tracking** en Free (`_0`).
- **Easy Nutrition Tracking** con IA: "Track food effortlessly with AI" (`_1`).
- **Meal planning & nutrition guidance** (Pro / Intelligence, `_0`).

### Coaching / IA

- **Bevel Intelligence**: "Meet your 24/7 health coach" (`_2`, `_3`); incluye check-ins, meal planning, training plans, **custom data analysis & insights** (`_0`).
- **Contextual Intelligence**: "Insights where you need them" (`_2`, `_3`).

### Biology / biomarkers / records / cycle

- **Biological Age insights** / "Discover your body's real age" (Pro, `_0`, `_3`).
- **Track 390+ Biomarkers**: "See every data point in one place" (`_1`, `_2`).
- **Health Records** import: "Your records, organized and secure" (`_0`, `_3`).
- **Understand Your Cycle**: "Track hormonal shifts and patterns" (`_1`, `_2`).

### UI / monetización (patrón, no feature de salud)

- Dark paywall con lista de iconos + precios Yearly/Monthly + trial 7 días (`_1`–`_3`).
- Pantalla Manage Subscription Free vs Pro con check/X (`_0`).
- Recvel **no** debe replicar paywall en v1 (contrato de producto en `README.md` / `HANDOFF.md`).

---

## 2. Qué cubre Recvel hoy (código + docs)

Leyenda: **Bien** = usable en app · **Parcial** = existe pero más estrecho / heurístico / sin paridad de promesa · **No** = no implementado (solo backlog/docs).

### Recovery, Strain, Sleep, Energy, Stress

| Capacidad Bevel | Recvel | Estado | Evidencia |
| --- | --- | --- | --- |
| Sleep / Strain / Recovery tracking | Scores diarios + detalle + factores + confianza | **Bien** | `ScoreEngine`, `DashboardView`, `DetailViews`; P0 en `COMPETITORS.md` |
| Optimize recovery (push vs rest) | Briefing / acción del día + objetivo de Strain adaptado a Recovery | **Parcial** | `InsightEngine`, Plan; no coach 24/7 |
| Energy Bank continuo intradia | Energy estimado diario + contribuyentes; **sin** curva carga/descarga tipo Bank | **Parcial** | `COMPETITORS.md` auditoría Energy; backlog "bateria continua" en `README.md` |
| Stress Score | Home Stress (bandas Excelente→Sobrecarga) + activación FC | **Bien** | `HealthIntelligenceEngine` / `HealthIntelligenceViews`; `README_StressAndBio.md` |
| Identify stress triggers | Tips heurísticos (p. ej. cafeína) + journal↔Recovery; **no** motor de triggers de estrés dedicado | **Parcial** | Journal associations; tips en Stress engine |

### Sleep (patrones / plan)

| Capacidad Bevel | Recvel | Estado | Evidencia |
| --- | --- | --- | --- |
| Improve sleep / patterns | Duración, eficiencia, consistencia, deuda, plan Esta noche (ciclos ~90 min), wind-down, disciplina vs plan | **Bien / Parcial** | `TonightDetailView`, `SleepCyclePlanner`, `SleepDisciplineEngine`; etapas agregadas solo si HealthKit las da |
| Insights de sueño tipo Pro | Patrones vía Journal (cafeína tarde, pantallas, cena); no "Intelligence" narrativa | **Parcial** | `JournalView` + sleep plan |

### Journal / habits / symptoms

| Capacidad Bevel | Recvel | Estado | Evidencia |
| --- | --- | --- | --- |
| Daily check-ins | Tab Journal: Sí/No (alcohol, cafeína tarde, cena tarde, pantallas, meditación, hidratación, luz) + diario mental | **Bien** | `JournalView`, `HabitLog`, `MentalJournalEntry` |
| Habits & symptoms + correlations | Asociaciones Recovery Si vs No (mín. 5/5); ayuno↔Recovery en Fasting | **Bien / Parcial** | Umbral documentado en `COMPETITORS.md` / `JOURNAL_SLEEP_RESEARCH.md`; síntomas clínicos / ciclo **no** |
| Accountability estilo coach | Sin check-in conversacional ni accountability AI | **No** (accountability humana local sí vía check-in) | — |

### Training / fitness

| Capacidad Bevel | Recvel | Estado | Evidencia |
| --- | --- | --- | --- |
| Fitness tracking / advanced metrics | Tab Fitness: 30d, Strain vs target, cardio load, focus, HRR, fuerza minutos, plantillas, sesión activa | **Bien** | `FitnessView`, `FitnessEngine`, `WorkoutTemplate` |
| Personalized training plans | Plantillas locales + sesión (inspirada en Strength Builder video); **no** planes generados por IA ni periodización Pro | **Parcial** | `FitnessView` comment `bevelworkout.mp4`; backlog Strength builder rico en `README.md` |
| Sync Watch profundo | Solo HealthKit iPhone; companion watchOS pendiente | **Parcial / No** | `README.md` Apple Watch |

### Nutrition

| Capacidad Bevel | Recvel | Estado | Evidencia |
| --- | --- | --- | --- |
| Easy nutrition tracking (AI) | Texto / voz / foto / barcode + edición de porción; Vision genérico (no Food-101 Core ML aún); Gemini opt-in personal | **Parcial** | `NutritionView`, `NutritionEstimator`; `HANDOFF.md` / `Calorie_AI_Research.md` |
| Meal planning & guidance | `NutritionPlanEngine` (Mifflin-St Jeor, estado del día, siguiente comida / plan mañana simple) | **Parcial** | Setup + plan local; no meal plans semanales ni coach nutricional Pro |
| Ayuno (extra Recvel) | Ayuno completo con screening — **diferenciador** no listado en estas capturas Pro | **Bien** (Recvel) | `FastingView` |

### Coaching / contextual intelligence

| Capacidad Bevel | Recvel | Estado | Evidencia |
| --- | --- | --- | --- |
| Bevel Intelligence 24/7 | Insights deterministas + briefing; **sin** chat coach | **No** (coach) / **Parcial** (insights) | Backlog P1 en `COMPETITORS.md` / `README.md` |
| Contextual Intelligence | Acción del día, tips Stress/Plan, notifs locales básicas | **Parcial** | Sin widgets / Live Activities / insights "donde los necesitas" en Lock Screen |

### Biology / cycle / records / biomarkers

| Capacidad Bevel | Recvel | Estado | Evidencia |
| --- | --- | --- | --- |
| Biological Age | Bio Age **beta cardiorrespiratoria** (VO2 HealthKit + FRIEND); no PhenoAge / bloodwork | **Parcial** | `README_StressAndBio.md`, checkbox en `README.md` |
| 390+ Biomarkers | Subconjunto HealthKit (HRV, RHR, VO2, sueño, workouts, peso, etc.); SpO2 autorizado sin UI rica | **No** (amplitud) | No hay catálogo tipo 390+ |
| Health Records import | No hay import de documentos clínicos / labs | **No** | Explicitamente fuera de v1 local en `COMPETITORS.md` |
| Understand Your Cycle | HealthKit puede autorizar ciclo; **sin** UI de fase × HRV/sueño | **No** | Backlog P2 `README.md` |

### UI / distribución

| Capacidad Bevel | Recvel | Estado |
| --- | --- | --- |
| Widgets / Live Activities (mencionado en docs competidor, no en estas 4 PNG) | **No** | P0 backlog |
| Paywall / Pro tier | **No** (intencional) | Sin premium v1 |

---

## 3. Qué falta (missing)

Ordenado por tema; solo lo que las capturas Pro reivindican y Recvel **no** tiene de forma creíble:

1. **Coach conversacional 24/7** (Bevel Intelligence) — check-ins de accountability por chat, Q&A, personalidades.
2. **Planes de entrenamiento generados / periodizados** (Personalized Training Plans) — más allá de plantillas manuales.
3. **Meal planning Pro** — menús / guidance multi-día, no solo "siguiente comida" heurística.
4. **Catálogo tipo 390+ biomarkers** unificado (Biology panel amplio).
5. **Health Records** (PDF/labs/import clínico).
6. **Ciclo menstrual** con patrones hormonales × recovery/sueño.
7. **Energy Bank** como curva continua intradia (Recvel tiene score Energy, no la dinámica Bank).
8. **Widgets / Contextual Intelligence glanceable** (Home/Lock Screen, Live Activities) — crítico vs hábito Bevel/Athlytic aunque no salga literal en `_0`–`_3`.
9. **Nutrición AI de producción** (Food-101 / VLM local serio) — hoy Vision genérico + confirmación humana.
10. **Triggers de estrés** como producto dedicado (correlaciones estrés ↔ hábitos con UI propia).

**Fuera de alcance deliberado (no gap de producto a perseguir en v1):** paywall, multi-wearable cloud, bloodwork obligatorio, claims clínicos.

---

## 4. Qué necesita refinamiento (partial → better)

| Área | Hoy | Refinar hacia |
| --- | --- | --- |
| Recovery "push vs rest" | Briefing + Strain target | Narrativa más clara del día (Morning Report) + un solo CTA consistente |
| Sleep patterns | Plan + Journal | Superficie "patrones de sueño" más visible (consistencia / deuda / cafeína) sin copiar copy Bevel |
| Stress | Score + tips | Más asociaciones explícitas estrés↔hábitos cuando haya muestras (mismo umbral 5/5) |
| Nutrition AI | Pipeline editable | Food-101 Core ML + reglas 12.10; honestidad de confianza ya buena — subir calidad de detección |
| Meal guidance | PlanEngine simple | Mejorar "siguiente comida" con macros del día y recovery; **sin** fingir meal planner Pro |
| Fitness / fuerza | Plantillas + sesión | Series×reps×peso más estructurados; no inventar "plan personalizado IA" |
| Bio Age | Beta VO2/FRIEND | Copy más claro "estimación cardiorrespiratoria"; no vender como Biological Age Bevel |
| Energy | Score diario | Opcional: batería continua con nombre propio (P1), solo si hay senales temporales honestas |
| Journal | 7 hábitos Sí/No | Agua/cafeína con cantidad-hora; síntomas opcionales; no inflar a "symptoms clinic" |
| Contextual insights | En-app | Widgets + notifs matutinas ricas |

---

## 5. Prioridad sugerida para Recvel (P0 / P1 / P2)

Alineada con contrato local-first (`README.md`, `HANDOFF.md`) y con el backlog ya en `COMPETITORS.md` / `README.md`, **re-priorizada contra las promesas visibles en `bevelpro_features_*`**.

### P0 — Cerrar el loop diario y la confianza (donde Bevel Free+Pro ganan el hábito)

| # | Capacidad Recvel | Por qué vs Bevel Pro screenshots |
| --- | --- | --- |
| P0 | **Widgets Home / Lock Screen** (Recovery, Strain, Sleep) | Sustituto local de "Contextual Intelligence" sin nube |
| P0 | **Morning Report** rico | Entrega "optimize recovery / push vs rest" al despertar |
| P0 | **Food-101 / nutrición AI creíble** + reglas clínicas 12.10 | Paridad honesta con "Easy Nutrition Tracking with AI" (`_1`) |
| P0 | Validación **Apple Watch real** | Sin esto, scores Free-tier de Bevel se sienten más "vivos" |

### P1 — Inteligencia local (competir con Intelligence sin ser Bevel)

| # | Capacidad Recvel | Por qué |
| --- | --- | --- |
| P1 | **Coach Q&A local** (reglas + on-device LM) | Cierra el hueco #1 vs Bevel Intelligence (`_0`, `_2`, `_3`) |
| P1 | **Batería de energía continua** (nombre propio) | Acerca Energy Bank Free de Bevel (`_0`) sin copiar nombre |
| P1 | Journal más rico + correlaciones (incl. ayuno↔Recovery ya iniciada) | "Habits & Symptoms" / stress triggers (`_1`, `_2`) |
| P1 | Mejorar **NutritionPlanEngine** (guidance del día) | Meal planning lite vs Pro (`_0`) — no menús semanales cloud |
| P1 | Export / citas científicas en UI | Confianza y ownership (diferenciación, no paridad Bevel) |

### P2 — Amplitud de mercado (después del núcleo)

| # | Capacidad Recvel | Por qué |
| --- | --- | --- |
| P2 | Ciclo menstrual × HRV/sueño | "Understand Your Cycle" (`_1`, `_2`) |
| P2 | Strength builder más completo + watchOS | Training plans / Advanced Fitness (`_1`, `_2`) |
| P2 | Live Activities (ayuno / workout) | Contextual Intelligence en sistema |
| P2 | SpO2 UI / panel Biology ampliado (sin 390+) | Biomarkers (`_1`) — subconjunto útil, no vanity count |
| P2 | Bio Age multivariable opt-in (sigue siendo estimación) | Biological Age (`_0`, `_3`) — sin bloodwork forzado |
| P2 | Health Records / labs | Solo opt-in explícito; **no** P0 (`COMPETITORS.md`) |

### No priorizar (aunque esté en las PNG Pro)

- Replicar **390+ biomarkers** como claim de marketing.
- **Health Records** clínico como feature core.
- **Paywall / Bevel Pro tier**.
- Coach cloud que envíe datos de salud.
- Copiar nombres: Energy Bank, Bevel Intelligence, Biological Age (usar nombres y copy propios).

---

## 6. Resumen ejecutivo

Bevel Pro, según las cuatro capturas, vende sobre todo **guidance**: Intelligence, planes de entrenamiento, meal planning, edad biológica, records y amplitud de biomarcadores — encima de un Free que ya incluye Sleep/Strain/Recovery, Nutrition & Fitness tracking, Stress y Energy Bank (`bevelpro_features_0.PNG`).

Recvel ya cubre bien el **núcleo de tracking explicable** (Recovery/Strain/Sleep/Energy/Stress, Journal con correlaciones, Fitness denso, Nutrición con confirmación, Ayuno). Los huecos más grandes frente al mensaje Pro son: **coach 24/7**, **planes de training/nutrition generativos**, **ciclo**, **records/biomarkers masivos**, y el **hábito glanceable** (widgets / morning report). La nutrición AI y la batería de energía son **parciales** y deben refinarse antes de afirmar paridad.

**Diferenciadores Recvel ya visibles:** local-first sin paywall, confianza/factores por score, ayuno con screening, honestidad nutricional (rango + edición). No competir en "390+ biomarkers" ni en Intelligence cloud; competir en claridad, privacidad y loop diario.

---

## 7. Mapa rápido Bien / Parcial / Missing

```
Bevel Pro theme              Recvel
─────────────────────────    ──────────────────────────
Recovery / Strain / Sleep    BIEN
Stress score                 BIEN
Energy Bank                  PARCIAL
Sleep patterns / plan        BIEN–PARCIAL
Habits & correlations        BIEN–PARCIAL
Fitness metrics              BIEN
Training plans (AI)          PARCIAL (plantillas) / MISSING (IA)
Nutrition AI tracking        PARCIAL
Meal planning Pro            PARCIAL (lite) / MISSING (Pro)
Bevel Intelligence coach     MISSING
Contextual Intelligence      PARCIAL → P0 widgets
Biological Age               PARCIAL (beta VO2)
390+ Biomarkers              MISSING (y no objetivo)
Health Records               MISSING (P2 opt-in)
Menstrual cycle              MISSING (P2)
```
