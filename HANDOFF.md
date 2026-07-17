# HANDOFF — instrucciones para la siguiente IA que continue este trabajo

**Inventario:** [FEATURES.md](FEATURES.md) — inventario vivo Done / Partial / Missing (app actual, plan original, Sugerencias Grok).

> Este archivo existe porque el asistente que investigo y documento todo lo de abajo llego a su limite de uso a mitad de sesion. Sirve para que **otra IA (u otra sesion del mismo asistente) continue exactamente donde se quedo, sin repetir investigacion ya hecha y sin inventar nada que no este ya verificado en este repo.**

## Regla de oro: no alucinar

1. **Toda la investigacion ya hecha esta citada con URLs en los archivos listados en la seccion "Mapa de documentacion" de abajo.** Antes de escribir cualquier afirmacion tecnica, cientifica o de licencia nueva, busca primero si ya esta respondida ahi. Si ya esta, **cita la seccion exacta, no la repitas ni la parafrasees como si fuera nueva**.
2. **Si necesitas un dato que no esta en estos archivos, verificalo con WebSearch/WebFetch antes de escribirlo como hecho.** No asumas nombres de modelos, cifras de precision, licencias, HKCategoryType de Apple, ni citas de papers de memoria. Este proyecto ya tuvo que corregir varias veces cifras inventadas por pasadas anteriores (ver `Calorie_AI_Research.md` seccion "Verificacion con fuente primaria") — repetir ese error es el fallo mas caro que puedes cometer aqui.
3. **Si algo no se pudo verificar, dilo explicitamente** ("no confirmado", "requiere verificar") en vez de rellenar con una suposicion razonable. El usuario prefiere un hueco marcado a un dato inventado.
4. **Este NO es un repositorio git** (`git status` falla con "not a git repository"). No hay historial de commits ni forma de ver "que cambio" con `git diff`. Ademas, **hay minimo otra sesion de IA editando estos mismos archivos en paralelo** durante julio 2026 — varios archivos han sido reescritos por "otra sesion" entre un turno y el siguiente de esta conversacion. Antes de editar cualquier archivo grande (`Calorie_AI_Research.md`, `AI_CONTEXT.md`, `README.md`, `COMPETITORS.md`, o cualquier `.swift`), **leelo primero, no asumas que sigue como lo describe este HANDOFF** — este documento es una foto del 13 de julio de 2026, puede estar desactualizado para cuando lo leas.
5. **No borrar contenido existente en ningun `.md` de investigacion.** La instruccion del usuario durante toda esta sesion fue "complementa, no borres". Aplica lo mismo a los `.swift`: no eliminar features ya implementados sin que el usuario lo pida.
6. **Cada cambio de codigo debe terminar con un build verde antes de darlo por hecho.** Comando exacto:
   ```
   cd "/Users/cesarvargastapia/Downloads/Recvel" && xcodebuild -project Recvel.xcodeproj -scheme Recvel -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6' -configuration Debug build 2>&1 | grep -E "error:|BUILD"
   ```
   Debe imprimir `** BUILD SUCCEEDED **` sin lineas `error:`.
7. **No cambies la postura central del proyecto sin preguntar al usuario primero:** sin backend, sin cuenta, sin premium, local-first por defecto. La unica excepcion documentada y aprobada por el usuario es un modo opcional "uso personal" (ver `Calorie_AI_Research.md` seccion 9) que permite licencias research-only y APIs cloud con tier gratuito **solo porque el uso actual es personal, no distribuido**. No generalices esa excepcion a "toda la app puede usar cloud" sin que el usuario lo confirme de nuevo.

## Mapa de documentacion (que ya existe, no volver a investigar)

| Archivo | Que contiene | Cuando consultarlo |
| --- | --- | --- |
| `FEATURES.md` | **Inventario vivo** de features actuales, plan original vs codigo, checklist Sugerencias Grok y gaps | Antes de priorizar trabajo o preguntar "que falta" |
| `README.md` | Vision de producto, modulos (Today/Recovery/Strain/Sleep/Energy/Nutricion), sistema de datos de Apple Health, estrategia de deteccion de comida por niveles de confianza, complementos de investigacion sobre volumen/LiDAR/bases de datos | Contexto general de producto y de la estrategia de nutricion "por niveles" |
| `COMPETITORS.md` | Matriz detallada de Bevel/WHOOP/Garmin/Amazfit/Oura/Athlytic con citas, patron cross-app de nutricion por IA, notas de verificacion (2 afirmaciones marcadas como no confirmadas: WHOOP "hyperbaric/bone density", Oura "meQ") | Antes de proponer cualquier feature "inspirado en X competidor" |
| `BEVEL_PRO_GAP_ANALYSIS.md` | Gap analysis Free vs Pro desde capturas `Bevel_references/bevelpro_features_*.PNG` vs codigo/docs Recvel (P0/P1/P2) | Antes de priorizar features "tipo Bevel Pro" |
| `AI_CONTEXT.md` | **Contrato operativo del proyecto** — arquitectura de capas, reglas de datos de HealthKit, evidencia cientifica ampliada por score (HRV, sueno, VO2max, ACWR/Strain, estres) con frases de cautela ya redactadas, sistema visual Liquid Glass (reglas de diseno) | **Leer primero, siempre, antes de tocar cualquier score o vista** |
| `README_StressAndBio.md` | **Investigacion + implementacion** de Home Stress, VO2 Max y Bio Age con lentes FRIEND/PhenoAge separadas. Distingue evidencia, heuristica, unidades y limites. **§4.7**: replica 1:1 del hero Bio Age de Bevel (geometria, paleta muestreada, `StardustField`). **§4.8**: patron `MetricDetailView`, Sleep Bank (14 d), coaching de sueno con evidencia, SpO2 + temperatura de muneca en Recovery, clasificacion FRIEND de aptitud, respiracion guiada. Incluye el registro del **bug corregido de las medianas FRIEND** | Antes de modificar Stress, VO2 UI, Sleep, Recovery o cualquier “edad biologica” |
| `Calorie_AI_Research.md` | **El documento mas grande e importante.** Ver desglose detallado abajo | Cualquier cosa relacionada con nutricion con IA o ayuno intermitente |
| `CalAI_Features_Analysis.md` | Analisis de un video de referencia del onboarding de Cal AI (competidor), con tabla de que adaptar a Recvel | Si se toca el onboarding de nutricion |
| `README_APP.md`, `README_COMPETIDORES.md`, `README_IA_CONTEXT.md` | **Set de documentos paralelo**, aparentemente escrito por otra sesion de IA cubriendo terreno similar a los tres de arriba (incluye una spec muy detallada de "Liquid Glass" tipo iOS 26 con codigo Swift de ejemplo). No se han reconciliado con el set principal. **No asumir que estan sincronizados** — si encuentras una contradiccion entre este set y el principal, señalalo al usuario en vez de elegir uno arbitrariamente. |

### Desglose de `Calorie_AI_Research.md` (documento principal, ~1180 lineas a la fecha de este handoff)

- **Secciones 1-8**: arquitectura original de nutricion con IA, investigacion de competidores reverse-engineered (Cal AI usa LLMs comerciales via prompts, no modelo propio; MyFitnessPal Meal Scan = SDK de Passio.ai white-label, confirmado; SnapCalorie usa LiDAR, confirmado por el fundador en HN; Foodvisor y Passio tambien operan como proveedores B2B), tabla de modelos Food-101 candidatos con **licencias verificadas una por una**.
- **Seccion "Restriccion de licencias"**: regla dura de cero costo/open source para v1 publico. Tabla de que modelos/herramientas son Apache 2.0/MIT/CC0 (usables) vs cuales estan bloqueados (Passio, OpenAI/Anthropic/Google Cloud pagos, Qwen2.5-VL-3B research-only, Apple FastVLM research-only).
- **Seccion "Verificacion con fuente primaria"**: correccion critica — de 7 clasificadores Food-101 investigados, **solo 3 tienen licencia permisiva confirmada** (`AlexKoff88/mobilenet_v2_food101`, `prithivMLmods/Food-101-93M`, `Lumia101/Food101-EfficientNet-B0`); los otros 4 no declaran licencia o usan "other" y quedan bloqueados hasta verificar con el autor. Tambien: Depth Anything V2 solo la variante **Small** es Apache 2.0 (Base/Large son CC-BY-NC, no comerciales).
- **Seccion 9 "Uso personal"**: excepcion aprobada por el usuario — como el uso actual es personal (no distribuido), licencias research-only y APIs cloud con tier gratuito SI son aceptables. Tabla de APIs gratis reales verificadas (OpenRouter modelos `:free` = usar ya; USDA FoodData Central API = gratis e ilimitado en la practica; Gemini free tier = evaluar verificando cuota en vivo; OpenAI = descartar, no tiene tier gratis real; LogMeal/Nutritionix/CalorieMama = descartados, son trials temporales no tiers perpetuos). Apple FastVLM (0.5B/1.5B) recomendado como modelo local principal — ya viene en Core ML/MLX listo en Hugging Face, sin conversion necesaria.
- **Seccion "PROPUESTAS DE NUEVOS FEATURES" (seccion 10)**: investigacion completa de ayuno intermitente (Zero, Fastic, BodyFast, Simple, LIFE) — protocolos, patron visual de anillo circular con fases de color, y un **borrador de arquitectura tecnica** (`FastingSession` en SwiftData, `FastingEngine`, reusar `HeroScoreRing`/`ArcGauge` ya existentes) marcado explicitamente como "propuesta a discutir, no codigo implementado".
- **Seccion 11 "Estado implementado: Nutricion adaptativa v1"**: **leer esto antes de escribir cualquier codigo de nutricion** — ya existe `NutritionPlanEngine` (formula Mifflin-St Jeor), `NutritionSetupView` (onboarding de 4 pasos), registro por texto/foto/voz/barcode, capa de correccion de porcion, y un flag `nutritionExperimentalFreeAPIEnabled` (apagado por defecto) para el modo Gemini opcional con API key en Keychain. Tambien lista los limites que siguen vigentes (Vision sigue siendo generico, no hay segmentacion real, sin validacion contra pesaje/calorimetria).
- **Seccion 12 "Evidencia clinica real"**: investigacion medica seria (PubMed/PMC, no marketing) sobre ayuno intermitente y nutricion con IA. Incluye **contraindicaciones documentadas** (menores de 18, embarazo, diabetes tipo 1/insulina, TCA), el hallazgo critico de que 73% de pacientes con TCA reporto que MyFitnessPal-like apps contribuyeron a su trastorno, evidencia de que la autofagia en humanos sigue siendo exploratoria, guia de la FDA sobre "general wellness products", y **una lista numerada de 11 reglas de producto concretas (seccion 12.10)** que aun no estan implementadas en codigo.

## Estado actual del codigo (verificado leyendo los archivos, no solo la documentacion)

Ya implementado en `Recvel/`:
- Sistema de diseno Liquid Glass completo (`Views/GlassComponents.swift`): `LiquidGlassCard`, `HeroScoreRing`, `ArcGauge`, tab bar de capsula flotante.
- **Navegacion (14 jul 2026):** tabs = Hoy / Journal / Nutricion / Ayuno / Fitness. **Plan salio del tab bar** y vive como detalle desde Home (`PlanHomeCard` → `PlanView`) o FAB (`TabBarVisibility.wantsPlan`). Journal tiene `.trackTabBarScroll()` para minimizar la barra como el resto.
- Dashboard, vistas de detalle por score, Trends, Journal enriquecido (habitos + chart + `MentalJournalEntry`), Plan gamificado local, Settings, Laboratory (toggles de datos mock), Onboarding.
- Nutricion: `NutritionEstimator.swift` (clasificador generico de Vision + catalogo de alimentos), `NutritionPlanEngine.swift` (plan calorico Mifflin-St Jeor), `NutritionSetupView.swift` (onboarding de nutricion), `NutritionView.swift` (logging con foto/texto/voz/barcode y correccion de porcion).
- `Services/KeychainStore.swift`: guarda la API key opcional de forma segura para el modo experimental cloud.
- Tests: `RecvelUITests/RecvelUITests.swift` (UI tests), `RecvelTests/EngineTests.swift` (unit tests).
- Stress/VO2/Bio Age (14 jul 2026): `HealthIntelligenceEngine.swift` agrega bandas de presion fisiologica con baseline/confianza y edad cardiorrespiratoria FRIEND; `HealthDataProvider` ya consulta VO2; `HealthIntelligenceViews.swift` contiene Home/details Liquid Glass. No reinterpretar Bio Age como PhenoAge ni agregar pesos arbitrarios de sueno/RHR/pasos.

**Ayuno intermitente v1 — YA IMPLEMENTADO (13 jul 2026, Tarea B completada):**
- `Recvel/Views/FastingView.swift` contiene todo el feature: modelo `FastingSession` (SwiftData), `FastingProtocol` (circadiano/16:8/18:6/20:4/OMAD), `FastingEngine` (fases metabolicas con lenguaje matizado + evaluacion de screening de seguridad), `FastingView` (anillo reusando `ArcGauge`, protocolo picker, timeline) y `FastingScreeningView` (screening de exclusion obligatorio antes de activar).
- Pestana `.fasting` agregada a `AppTab` (GlassComponents.swift) y `ContentView`. `FastingSession.self` registrado en el ModelContainer de `RecvelApp.swift` y en el preview de ContentView.
- El screening implementa las contraindicaciones duras de `Calorie_AI_Research.md` 12.2 (menor de 18, embarazo/lactancia, TCA, diabetes tipo 1/insulina, bajo peso = bloqueo) y el aviso "consulta a tu medico" (adulto mayor/cardiaco/medicamentos = caution). El texto de fases nunca afirma autofagia como hecho (regla 12.4).
- Tests: 7 unit tests nuevos en `RecvelTests/EngineTests.swift` (limites de fase, lenguaje matizado, clamp de progreso, bloqueo/caution/clear del screening, elapsed con endDate) y 2 UI tests en `RecvelUITests/RecvelUITests.swift` (`testFastingSafetyScreeningBlocksContraindication`, `testFastingHappyPathStartAndEnd`). Todos verdes.
- **Actualizacion (13 jul 2026, tarde): el feature de ayuno fue enriquecido mas alla del MVP**, en colaboracion entre dos sesiones concurrentes. Estado actual verificado con tests verdes y screenshots: protocolo custom con slider (12-36 h), tarjetas de protocolo con barra de proporcion ayuno/comida, inicio rapido ("repetir ultimo protocolo"), ventana de alimentacion tras terminar, linea de tiempo de fases sobre el anillo, ajuste retroactivo de hora de inicio (hasta 48 h), notificacion local opcional al completar, registro de estado de animo durante el ayuno, tips contextuales deterministas, estadisticas neutrales (sin streaks punitivos, regla 12.3 — solo visibles con ayunos completados), grafica de 7 dias, calendario de 30 dias, y la tarjeta "Ayuno y tu Recovery" (correlacion contra DailyScoreRecord, minimo 3 dias con/3 sin — el diferenciador de la seccion 10.7, YA implementado con estado "EN PROCESO" hasta acumular datos).
- Tests del ayuno: 14 unit tests en `EngineTests` (fases, lenguaje matizado, stats, dailyFastingHours, recoveryImpact con minimos de muestra, contextualTip determinista, screening) y 2 UI tests robustecidos contra sheets/scroll (`testFastingSafetyScreeningBlocksContraindication`, `testFastingHappyPathStartAndEnd`).
- **Advertencia operativa importante**: durante esta jornada, dos sesiones de IA corrieron `xcodebuild test` simultaneamente y se mataron procesos mutuamente ("Test crashed with signal kill/term before starting test execution"). Si un test falla con ese sintoma, espera a que termine la otra sesion y reintenta en el mismo `iPhone 16 Pro, iOS 18.6`; no crees ni uses otro simulador.

## Actualizacion 15 julio 2026: Journal Pro y Bio Age implementados

- Journal MVP fue reemplazado por `JournalProView.swift`: calendario semanal/mensual, dia wake-to-wake, grupos dia/noche, catalogo configurable, automaticos Apple Health, defaults, pins, umbrales, tags propios, recordatorios e Insights Recovery/Sleep 5/5.
- `ProductIntelligenceModels.swift` agrega `JournalTagConfiguration`, `BiomarkerSample` y `BioAgeReportRecord`; los tres estan registrados en todos los `ModelContainer`.
- `BiomarkerEngine.swift` implementa PhenoAge publicado, conversion de unidades, panel estricto de nueve labs <6 meses, confianza 20/28, factores de cuatro semanas, catalogo y Clinical Records/FHIR opt-in.
- `BioAgeProViews.swift` reemplaza la card y detalle genericos por entrypoint ancho, medio aro con particulas/Reduce Motion, selector Cardio/Sangre, factores, catalogo, detalle y alta manual.
- `HealthDataProvider` ya lee luz diurna, mindfulness, agua/cafeina, peso, grasa, masa magra, presion y SpO2. El SDK no expone un tipo `dietaryAlcohol`; ese dato permanece manual/Journal.
- Suite final verde en `iPhone 16 Pro, iOS 18.6`: 61 unit tests y 20 UI tests, sin fallos. No usar ni crear otro simulador.

**NO implementado todavia (solo investigado/documentado):**
- Las **11 reglas de producto de seguridad clinica** de la seccion 12.10 (screening de exclusion antes de ayuno, prohibicion de streaks punitivos, disclaimers especificos de "no usar para decisiones clinicas", etc.) — la nutricion actual en codigo no las tiene todavia.
- Reemplazo del clasificador generico de Vision por un **modelo Core ML real de Food-101** (los 3 candidatos con licencia confirmada de la seccion "Verificacion con fuente primaria").
- Integracion de **Apple FastVLM** o cualquier VLM local (seccion 9.3) — sigue siendo solo investigacion, no codigo.

## Tareas siguientes sugeridas, en orden de prioridad, cada una con su fuente ya investigada

### Tarea A — Implementar las reglas de seguridad clinica en el codigo de nutricion existente (prioridad alta, no requiere investigacion nueva)

Todo el respaldo ya esta en `Calorie_AI_Research.md` seccion 12.10. Es trabajo de implementacion pura:
- Agregar un screening corto (tipo SCOFF/EAT-26, ver 12.3) antes de habilitar conteo calorico intensivo, en `NutritionSetupView.swift`.
- Revisar `NutritionView.swift` y quitar cualquier patron de UI tipo streak punitivo o color rojo/verde de "exito/fracaso" en deficit calorico si existe (ver 12.3 sobre por que esto es dañino, evidencia de Eikey 2021).
- Agregar el disclaimer explicito de "no usar para decisiones clinicas" en la pantalla de resultado nutricional (ver 12.8, cita Li et al. 2024).
- No inventar el texto exacto del disclaimer — redactarlo en espanol siguiendo el tono ya usado en `AI_CONTEXT.md` seccion "Lenguaje y seguridad", no copiar literal las citas en ingles de la investigacion.

### Tarea B — Implementar el feature de ayuno intermitente v1 (prioridad media, arquitectura ya diseñada)

Fuente completa: `Calorie_AI_Research.md` secciones 10 y 12.1-12.6.
- Crear `FastingSession` (SwiftData) segun el borrador de la seccion 10.8.
- Crear `FastingEngine` que calcule la fase metabolica actual **con lenguaje matizado por incertidumbre cientifica** (ver 12.4 — nunca decir "estas en autofagia" como hecho).
- Reusar `HeroScoreRing`/`ArcGauge` de `GlassComponents.swift` para el anillo visual, no crear un sistema nuevo (consistencia visual ya establecida).
- **Antes de activar el timer**, implementar el screening de exclusion de la seccion 12.2 (menores de 18, embarazo/lactancia, TCA, diabetes tipo 1/insulina, bajo peso) — esto es un requisito de seguridad, no opcional.
- Si se toca el ciclo menstrual existente en la app, agregar el mensaje contextual no alarmista de la seccion 12.5.

### Tarea C — Reemplazar el clasificador de Vision generico por un modelo Food-101 real (prioridad baja, opcional)

Solo usar, sin verificar de nuevo la licencia (ya esta hecho):
- `AlexKoff88/mobilenet_v2_food101` (Apache 2.0)
- `prithivMLmods/Food-101-93M` (Apache 2.0)
- `Lumia101/Food101-EfficientNet-B0` (MIT)

**No usar** `skylord/swin-finetuned-food101`, `Kaludi/food-category-classification-v2.0`, `nateraw/vit-base-food101` ni `paolopertino/mobilenet-finetuned-food101` sin antes contactar al autor — su licencia quedo marcada como no verificada/bloqueada en la investigacion ya hecha.

### Tarea D — Reconciliar el set de documentos duplicado (prioridad baja, requiere decision del usuario)

Existen dos sets de README que cubren terreno parecido (`README.md`/`COMPETITORS.md`/`AI_CONTEXT.md` vs `README_APP.md`/`README_COMPETIDORES.md`/`README_IA_CONTEXT.md`). No decidir unilateralmente cual es "el bueno" — preguntarle al usuario si quiere fusionarlos o mantener ambos.

## Si algo en este HANDOFF ya no coincide con el estado real del proyecto

Este archivo es una foto de un momento especifico. Si al leerlo notas que un archivo mencionado ya no existe, cambio de contenido, o una tarea ya fue hecha por otra sesion mientras tanto: **confia en lo que ves en el proyecto ahora mismo, no en lo que dice este documento**, y actualiza esta seccion o la lista de tareas si corresponde.
