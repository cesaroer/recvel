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

## Estado del planner de entrenamiento (julio 2026, sesion "agenda pro")

Implementado en esta sesion (todo en archivos EXISTENTES — el pbxproj no tiene
grupos sincronizados, no crear .swift nuevos):

- `ExerciseSetLog` (@Model, HealthModels.swift): series persistidas por ejercicio.
  Registrado en los 3 ModelContainer (RecvelApp, ContentView preview, LaboratoryView preview).
  ANTES las series se descartaban al terminar la sesion: no habia progresion real.
- `OneRepMaxEstimator` + `TrainingCoachingEngine` + `LastWorkoutContext` en
  `HealthIntelligenceEngine.swift` (evidencia citada en AI_CONTEXT.md, seccion
  "Coaching de entrenamiento del dia siguiente").
- `WorkoutFeeling` (emoji RPE post-entreno) en HealthModels.swift; reemplaza el
  `perceivedEffort: 6` que estaba hardcodeado en `ActiveWorkoutSessionView.finish()`.
- `SplitType` + `CardioSport` + `WeeklyRoutine.init(from:)` retro-compatible en
  FitnessView.swift; onboarding de 6 pasos adaptativos.
- `WorkoutSummary.effortScore/effortIsEstimated` leidos de HKWorkoutEffortScore
  (iOS 18, manual > estimado, solo lectura); entra a Strain con peso 30%.
- Progresion por ejercicio (`ExerciseProgression` en FitnessView.swift) reusa
  `MetricDetailView` con series peso top-set y e1RM.

**Rutinas pre-hechas + Coach de rutina (julio 2026, sesion "agenda pro 2"):**
`TrainingPresetCatalog.swift` (nuevo, registrado via `xcodegen generate`) contiene
el catalogo de 8 presets, `PresetPickerSection` (paso routinePreview del wizard),
la materialización en `WorkoutTemplate` y `RoutineCoachCard`.
`RoutineAssessmentEngine` vive en HealthIntelligenceEngine.swift. El wizard
(`WeeklyPlanOnboardingView`) gano el paso `.routinePreview` (solo con fuerza), el
paso de dias por contador con semana editable por tap, y enlaza las plantillas
del preset por `sourceID` estable. El banner del
coach es SIEMPRE visible en `WeeklyRoutineSection` (id `fitness.weeklyRoutine.coach`).
El editor del preview es `WorkoutTemplateEditor`, el mismo de Plantillas.
El proyecto ahora usa xcodegen: para archivos nuevos, editar `project.yml` no es
necesario (sources incluye `Recvel/` completo), solo correr `xcodegen generate`.

**Banco de ejercicios del Desafio diario (julio 2026):** `ExerciseLibrary`
tiene el grupo "Challenge" (~32 ejercicios de FUERZA ligera: McGill Big 3,
banda/fisioterapia, pasos, Pilates mat, calistenia y yoga de fuerza). El engine
los consume via `DailyChallengeEngine.maintenancePacks` (5 packs x 3 variantes),
que rota por weekday y SALTA el pack cuyo `bucket` choque con los dias de fuerza
adyacentes. Cada tercer dia queda movilidad para variar. Guardia:
`testDailyChallengeEmissionsExistInExerciseLibrary` cubre packs + variantes.

**IMPLEMENTADO (25 jul 2026) — "Ver mecanica del ejercicio":** dentro de la
sesion activa (`ActiveWorkoutSessionView` → `ActiveSessionExerciseCard`) cada
ejercicio tiene un boton "Ver mecanica del ejercicio" que abre
`ExerciseMechanicsSheet` (`Recvel/Views/ExerciseMechanicsView.swift`): resumen,
posicion inicial, ejecucion numerada, claves y errores comunes, en espanol y
100% offline (`Recvel/Services/ExerciseMechanicsCatalog.swift`, una entrada por
cada ejercicio de `ExerciseLibrary`). La misma hoja se abre desde la "i" de cada
fila de la biblioteca (antes era decorativa; ahora es un boton real).
Demostracion visual: 104 fotogramas de **free-exercise-db** empaquetados en
`Recvel/Resources/ExerciseMedia/<slug>_0.jpg` y `_1.jpg` (inicio/fin), que
`ExerciseMechanicsPlayer` alterna cada 0.9 s con crossfade para simular un gif
(boton play/pausa, respeta Reduce Motion). Detalles no obvios:
- Los slugs del dataset NO se derivan del nombre en espanol (p. ej. no existe
  `Bird_Dog` ni `Burpee`): el mapeo es explicito en `mediaSlug`, y los que no
  tienen imagen caen a la silueta SF Symbol sin romper la vista.
- Los jpg viven sueltos en el bundle, no en el asset catalog, asi que
  `UIImage(named:)` sin extension devuelve nil → `ExerciseMechanicsPlayer.loadImage`
  resuelve la ruta con `Bundle.main.url(forResource:withExtension:"jpg")`.
- xcodegen (`sources: - path: Recvel`) los agrega solos a Copy Bundle Resources.
- Guardias: `testEveryLibraryExerciseHasMechanics`,
  `testMechanicsCatalogHasNoOrphanEntries`, `testMechanicsMediaFramesExistInBundle`.

**Estres: promedio del dia vs ahora (27 jul 2026):** el hero y el entrypoint
mostraban el indice del dia (HRV/FC reposo vs baseline) sin etiqueta, y se leia
como si fuera "ahora". Ahora:
- `StressEngine.dayProfile(activation:)` resume la curva horaria en
  `StressDayProfile` (promedio, actual, maximo, minimo, horas medidas).
- **Hero y entrypoint = PROMEDIO DEL DIA**; el **valor actual** vive en su propia
  tarjeta ("Ahora · ultima hora medida", id `detail.stress.now`) junto al mas y
  menos calmado del dia.
- Con menos de 3 horas medidas (`StressDayProfile.minimumHours`) NO se afirma un
  promedio: la UI cae al indice del dia de siempre.
- `StressEngine.pressureIndex` mapea activacion (FC sobre reposo / 30) a 0-100
  saturando en 2.0 (~60 lpm sobre tu reposo). Es una estimacion y la pantalla lo
  dice: la activacion no entra en el indice de estres.
- Grafica horaria con estilo de la referencia: capsulas redondeadas con
  degradado sobre pista tenue, paleta fria→lavanda→ambar (se quito el rojo de
  alarma; la activacion alta es actividad, no un fallo), media del dia como linea
  punteada y leyenda Tranquilo/Activo/Muy activo.
  **Ojo:** las dos barras de la misma hora usan `yStart:/yEnd:`; con `y:` Charts
  las APILA y la barra de color queda flotando sobre la pista.
- **Tarjeta "Estres ahora"** (`StressTodayCard`, id `detail.stress.now`): copia la
  gramatica de "Today's stress" de la referencia — punto de estado + titulo +
  hora, tres cifras (mas alto / mas bajo / promedio) con divisores finos, y dial
  de ticks a la derecha con el valor actual y su banda dentro. Habla en **indice
  de estres** (0 = sin presion, 100 = maxima), no en calma: es la lectura del
  momento, no el resumen del dia.
- **Estilo de tarjeta de la referencia** (`RevelCardStyle` / `.revelCard()`):
  relleno plano un punto mas claro que el fondo, radio 28 y **sin borde ni
  degradado ni tinte**. Es lo que diferencia sus tarjetas de nuestro glass.
- La tarjeta de ahora se muestra con **una sola lectura** (`profile.current != nil`),
  no con el gate de 3 h: de madrugada el promedio del dia aun no aplica pero el
  valor actual si, y antes desaparecia justo cuando mas se necesita.
- Tests: `testStressDayProfileSeparatesAverageFromCurrent`,
  `testStressDayProfileNeedsThreeHours`, `testStressPressureIndexAndBands`.

**Reporte de la mañana (27 jul 2026):** `MorningReportEngine` +
`MorningReportView` arman la hoja que se lee al despertar: Recuperacion con la
señal que mas resto, sueño + banco de 14 d, la accion del dia y el margen de
carga con la sesion planeada de la agenda. Decisiones que conviene no deshacer:
- **No duplica Home.** Home ya se llama "Resumen de la mañana" y es un tablero
  vivo; la hoja es una foto congelada del despertar que se cierra.
- **Se calcula al abrirla, nunca la noche anterior.** Una notificacion local no
  puede recalcular su contenido al dispararse, asi que el texto de la notif se
  queda sobrio y las cifras se computan en el momento. Programarlas con datos de
  la noche anterior mostraria numeros falsos.
- **Tres entradas:** deep link `recvel://morning` (nuevo `NotificationRouter`,
  delegate de `UNUserNotificationCenter` que enruta el tap por
  `.recvelOpenDeepLink`), auto-apertura una vez al dia dentro de la ventana
  matutina (`shouldAutoPresent`, con test), y enlace fijo bajo el titulo de Home.
- **"Visto hoy" se marca cuando la hoja aparece de verdad** (`onAppear`), no al
  intentar abrirla: presentar dentro del `task` inicial se pierde porque la
  ventana aun no es key — de ahi el pequeño retraso antes de presentar. Si la
  presentacion falla, mañana reintenta.
- **Sin `BGTaskScheduler`:** no hay refresco en segundo plano; es una decision,
  no un olvido.
- **Diseño (27 jul 2026, 4a pasada — la vigente):** sigue la linea de la pantalla
  **Bio Age de la referencia** (no la de la app), escrita desde cero en
  MorningReportView.swift: fondo de nebulosa + campo de estrellas con bokeh y
  deriva (`LabBackdrop`/`StarField`), **dial doble** (`DualDialHero`) con surco de
  ticks exterior = Recuperacion e interior = Energia, disco elevado, etiquetas
  rotadas, marcador con halo en el extremo del arco y reveal por particulas
  convergentes; abajo, modulos de instrumento con micro-encabezado rotulado.
  - Metricas del reporte (elegidas por el usuario): los 4 scores
    (Recuperacion, Sueño, Energia, Carga), sueño de la noche + banco 14 d con
    grafica de noches, margen de carga + sesion planeada, **señales de la noche**
    (HRV, FC reposo, respiracion, SpO2, temperatura de muñeca con rango personal
    y micro-medidor), estres + emociones 24 h, y ayuno + nutricion del dia.
  - **Animaciones (medidas, no a ojo).** Se extrajeron fotogramas de la
    referencia con ffmpeg y se compararon pixel a pixel con PIL:
    · un punto fijo del **fondo** varia **≤3 niveles de 255 en 1.6 s** y no se
      desplaza → en la referencia el fondo NO titila ni deriva;
    · la **nube de particulas del centro** cambia **~16% de sus pixeles entre
      fotogramas separados 0.4 s** → es lo unico con vida continua.
    Por eso el fondo es `StaticStarField` (Canvas dibujado UNA vez, con
    `drawingGroup`) mas un `DustLayer` de 26 motas apenas perceptibles, y toda la
    vida esta en `OrbitingParticles`: cumulos que orbitan + deriva browniana
    (dos senos incompatibles por eje) + parpadeo propio. La primera version hacia
    lo contrario (fondo entero titilando, particulas que desaparecian tras el
    reveal) y por eso se veia barata.
    **Los aros NO animan** (decision del usuario, 27 jul): se dibujan estaticos
    en su valor, con `drawingGroup`, y no hay punto marcador. Se probaron un
    barrido con cabeza de luz viajera y un marcador con halo, y se rechazaron.
    Lo unico que se mueve en la pantalla es el polvo: `OrbitingParticles` en el
    hero y `DustLayer` en el fondo. El resplandor del arco es fijo (trazo
    difuminado del propio arco, no `.shadow` de la vista).
    Metodo de verificacion repetible: grabar con
    `xcrun simctl io <udid> recordVideo`, extraer a 2.5 fps y medir el % de
    pixeles que cambian por zona. Tras el arreglo la nube pasa de 0.4% a 1.6% con
    el fondo en 0.1% (la referencia mide 16% sobre una caja mucho mas densa, no
    es comparable en crudo).
  - `MorningReportEngine.signals` solo incluye lo medido (nunca rellena), y
    normaliza SpO2 (HealthKit la da como fraccion o como %) con tope de 100 %.
  - Pasadas anteriores: (2a) copiaba Bio Age de la app 1:1 → rechazada;
    (3a) lenguaje del Home de Bevel (anillos + COACHING) → los componentes de esa
    version viven ahora en `Recvel/Views/RevelInspiredComponents/` (ver su
    README) y NO se usan aqui. Regla del usuario: en esa carpeta solo entra lo
    que el pida explicitamente.
- **`skipMorningReport`:** los UI tests pasan este launch argument porque entran
  a Home a cualquier hora y la auto-apertura los haria fallar segun la hora del
  dia (mismo patron que `skipHealthKitRefresh`).
- Pendiente de verificar en dispositivo: el tap real sobre la notificacion local
  (la ruta esta probada por deep link; el permiso de notificaciones no estaba
  concedido en el simulador).

**Mapa muscular + tempo de la demostracion (27 jul 2026):** la hoja de mecanica
ahora abre con un mapa anatomico (`MuscleMapView`, `MuscleMapCatalog`): silueta
gris de frente y espalda con el musculo principal en rojo y el secundario en
ambar, mas leyenda con los nombres. Notas:
- Assets de **wger** (wger-project/wger, wger.de) en `Recvel/Resources/MuscleMap`:
  `body_front/back.svg` + `muscle_<id>_main.svg`. El repo de wger es AGPL-3.0 y
  su data es Creative Commons; sirve para uso personal sin distribucion. Si algun
  dia la app se publica, hay que sustituir estas laminas o cumplir la licencia.
- SwiftUI no rasteriza SVG: el compositor es un `WKWebView` que apila el marcado
  **en linea** (`loadHTMLString(baseURL: nil)`, sin red ni disco).
- Los SVG de wger NO traen `viewBox` (solo width/height de Inkscape): sin el,
  WebKit no escala y el mapa sale EN BLANCO. `MuscleMapRenderer.normalized`
  inyecta `viewBox` + `preserveAspectRatio`; hay test.
- El rojo `#fc0000` del asset se reemplaza en caliente para distinguir principal
  de secundario.
- La demostracion de dos fotogramas ya no parpadea: `ExerciseMechanicsPlayer.blend`
  hace un fundido de ida y vuelta con ciclo de 5 s y 1.4 s de pausa en cada
  extremo (funcion pura, con test de monotonia), y en pausa aparecen los botones
  Inicio/Fin para comparar posiciones.
- **Limite conocido:** las laminas ilustradas tipo workoutingym.com/musclewiki
  son material con derechos; no se pueden empaquetar. Con fuentes libres solo hay
  2 fotogramas por ejercicio. Para animaciones ilustradas reales haria falta una
  fuente de pago (ExerciseDB con GIFs) o arte propio.

**Investigacion de APIs de ejercicios con imagen/instrucciones (julio 2026, base
de lo anterior):** la mejor opcion para la regla de "todo local, gratis" es
**free-exercise-db** (https://github.com/yuhonas/free-exercise-db): licencia
**Unlicense (dominio publico)**, 800+ ejercicios, JSON estatico + imagenes en el
repo (sin API key, sin backend). Se puede empaquetar offline en el bundle.
Campos: id, name, force, level, mechanic, equipment, primaryMuscles,
secondaryMuscles, instructions, category, images. Alternativas descartadas para
v1: ExerciseDB API (11k ejercicios con GIFs pero requiere servicio/llave) y wger
(REST, exige self-host). Pendiente si se quiere: script de importacion que mapee
esos nombres (en ingles) a los del catalogo en espanol y descargue las imagenes
al bundle.

**Preview 3 modalidades + movilidad=descanso (julio 2026):** el paso
"Tu rutina sugerida" muestra fuerza (presets) + cardio (deporte + stepper de
minutos, `cardioMinutesDraft`) + movilidad (plantilla `generated.mobility.plan`
editada con WorkoutTemplateEditor; `enrichSessionDetails` la consulta al
contexto en vivo, no al array capturado). Movilidad cuenta como descanso en
contador/coach/planSummary (`RoutineAssessmentEngine.isRestEquivalent`).
ExerciseLibrary gano grupos Cardio y Movilidad + Step-ups/Desplantes/Flexiones/
Band pull-aparts; el engine del challenge quedo alineado a esos nombres
("Sentadilla" singular, "Face pull"). Plantillas segmentada por kind. La rama
"Cardio planeado" del todayCard se CONSERVA como fallback de planes legados sin
plantilla materializada.

**Reconciliacion de tests con la migracion de strings (julio 2026, RESUELTA):**
la suite UI quedo reconciliada con los strings acentuados del catalogo. Cambios
mecanicos aplicados en RecvelUITests: "Como obtener una nueva estimacion" ->
"Cómo obtener una nueva estimación"; "Como leer esta metrica" -> "Cómo
interpretar esta métrica"; "Respiracion guiada"/"Nutricion"/"No es una edad
biologica clinica"/"Tu briefing necesita datos" -> formas actuales; boton back
"Back"/"Atras" -> acepta "Atrás"; items de Menu nativo con tap por coordenada;
el detalle de Stress renderiza lazy (scrollear hasta que la seccion exista en el
arbol); el toggle avanzado del wizard se enciende via experiencia "Avanzada"
(camino de la app, determinista) en vez de pelear con el switch.

**Deuda conocida (no bloqueante):**
- Los enums de fitness (WeeklyGoal, DayAssignment, SplitType, CardioSport,
  WorkoutFeeling) tienen labels en espanol hardcodeado, consistente con el resto
  de FitnessView; falta migrarlos al String Catalog (`Shared/Localizable.xcstrings`).
- Notificacion programada de "hora sugerida de entrenamiento" NO se implemento:
  el consejo de hora vive in-app en la tarjeta de hoy (tip de timing). Si se
  quiere notificacion, extender `LocalNotificationManager` + su switch
  `localizedContent` + claves del catalogo + toggle en Ajustes.
- `MuscleGroupClassifier` (FitnessView.swift) clasifica por palabras clave; los
  ejercicios que no matchean caen al focus de la plantilla o "General".

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

## Actualizacion 16 julio 2026: Widgets, Live Activity y Apple Watch v1

- El proyecto ahora se genera con `project.yml`/XcodeGen y contiene cuatro productos embebidos: `Recvel`, `RecvelWidgets`, `RecvelWatch` y `RecvelWatchWidgets`. Regenerar con `xcodegen generate` si se agregan archivos o targets.
- `Shared/RecvelSharedSnapshot.swift` es el unico contrato entre superficies: snapshot diario Codable, versionado, sin historial de HealthKit. iOS/widgets usan App Group; iPhone/Watch usan WatchConnectivity.
- Widgets iOS: Readiness small/medium/Lock Screen y tablero fisiologico medium/large/Lock Screen. La complicacion watchOS muestra Recovery/Sleep/Strain.
- Ayuno inicia y termina una Live Activity con Lock Screen/Dynamic Island. El deep link `recvel://fasting` abre la tab y un cambio retroactivo de hora reconstruye el intervalo.
- Watch app: Readiness, senales y workouts de carrera/caminata/ciclismo/fuerza mediante `HKWorkoutSession`, con FC, energia y distancia en vivo y guardado en Apple Health.
- Build verde del esquema completo en el unico simulador permitido: `iPhone 16 Pro, iOS 18.6`. Pasaron 82 unit tests, el smoke de onboarding y los UI tests enfocados de navegacion + ayuno. Una primera ejecucion combinada quedo esperando el relanzamiento de un runner XCTest caido y fue interrumpida tras 12 minutos; las ejecuciones aisladas posteriores fueron verdes. Sigue pendiente validar sensores, bateria y sincronizacion de fondo en hardware.

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

## Actualización 20 julio 2026: Agenda semanal profesional

- WeeklyRoutine conserva el JSON anterior y agrega experiencia, objetivo, fase, evento y configuración completa por día.
- Cada sesión define hora fija, preferida o flexible, duración, RPE objetivo, intención de cardio y foco editable; la semana muestra minutos, intensidad y carga sRPE planificada frente a ejecutada.
- TrainingReadinessCheckIn guarda localmente energía, molestias, motivación y dolor o limitación. El motor prioriza este reporte y nunca empuja a entrenar con dolor.
- Apple Health aporta entrenamientos, esfuerzo manual o estimado y rachas cuando están disponibles; sesiones duplicadas con registros locales no se cuentan dos veces.
- La lógica de horario solo interviene en sesiones intensas próximas a dormir y distingue horarios fijos de flexibles. La regla muscular usa carga reciente y molestias, no una prohibición universal de 48 h.
- Método, competidores, evidencia y límites: TRAINING_PLANNER_PRO.md.
- Verificación: build completo verde, 117 unit tests verdes y UI test enfocado del configurador verde en iPhone 16 Pro, iOS 18.6.

## Actualización 20 julio 2026 (tarde): Plan semanal v2 — biblioteca, alto rendimiento y dos velocidades

**Nota de proceso:** con XcodeGen (`project.yml`) los archivos bajo `Recvel/` se incluyen por carpeta; al crear un `.swift` nuevo hay que correr `xcodegen generate` (hecho). Ya no aplica la regla vieja de "no crear .swift nuevos".

Implementado (nuevo archivo `Recvel/Views/TrainingPlanViews.swift` + edits en `FitnessView.swift` y `HealthIntelligenceEngine.swift`):

- **Arquitectura de rutinas:** la agenda es "Plan semanal" y la biblioteca es "Plantillas de entrenamiento". Fuerza, cardio, movilidad, recuperación, rendimiento y desafío diario usan `WorkoutTemplateEditor`; no crear editores específicos de la agenda.
- **Tipos de sesión nuevos en `DayAssignment`:** `.mobility`, `.recovery` (fisioterapia), `.plyometrics`, `.speed`, `.contrast`, `.technique`; cada uno con icono, color, RPE y duración por defecto; `isHighNeuralDemand` / `isRecoveryOriented` alimentan el coaching.
- **`ScheduledSessionDetails` pro** (custom decoder retro-compatible): `jumpContacts`, `contrastSets`, `speedReps`, `speedDistanceMeters`, `targetZone`, `mainLiftPercent1RM`, `sessionNote`.
- **`WeeklyRoutine` plan fields:** `planName`, `advancedConfig`, `personalRecords` (1RM por `MainLift`), `planWeeks` — todo `decodeIfPresent`.
- **Biblioteca de planes** (`WeeklyPlan` + `WeeklyPlanLibraryStore` en UserDefaults): guardar copia, aplicar (con confirmación), renombrar, duplicar, eliminar uno, eliminar todos. El wizard siempre hace upsert al guardar.
- **Gestor de rutinas** (`WorkoutTemplateManagerView`): lista, editar, eliminar una o todas (entrada: menú "..." de "Plantillas de entrenamiento").
- **Wizard nuevo** (`WeeklyPlanOnboardingView`, reemplaza `WeeklyRoutineOnboardingView` que fue eliminado): rápido = 4 pantallas (perfil, modalidades, días, revisión); avanzado (toggle "Opciones de alto rendimiento", auto-ON en nivel avanzado/competitivo) = + fase, editor por día con tipo de sesión y params pro, marcas 1RM. **Botón Atrás** en toolbar desde el paso 2.
- **`SessionDetailEditor`** compartido entre wizard y `TrainingDayEditorSheet` (se abre tocando un día de la tira semanal de la agenda).
- **`PlanExpectationEngine`**: bullets de expectativa por objetivo/nivel/fase + precauciones (0 descansos, ≥3 RPE 8+, potencia en nivel inicial, <120 min) en la revisión.
- **Coaching**: `tips(..., plannedKind:)` — sesiones neurales con recovery <55 o molestias ≥4 sugieren mover/adaptar; días de recuperación tras racha ≥3 reciben refuerzo positivo.
- **Planner**: `suggestedWeek(..., includeMobility:)` convierte el último cardio en movilidad (o la coloca tras el último día de fuerza); `defaultSplit(forStrengthDays:)` (2-3 fullBody, 4 upperLower, 5+ PPL).

Verificación: build verde tras `xcodegen generate`; suite unitaria completa verde (17 tests nuevos: decoders legacy, biblioteca, movilidad, coaching neural/recuperación, expectativas); UI tests verdes: `testWeeklyRoutineOnboardingAsksSplitAndSport` (reescrito al flujo nuevo con toggle avanzado + botón Atrás) y `testQuickPlanWizardSavesAndOpensLibrary` (nuevo: flujo rápido 4 pantallas + biblioteca + eliminar todos) + `testFitnessShowsExerciseProgressionSection` sin regresión. iPhone 16 Pro, iOS 18.6.

### Plantillas unificadas (20 jul 2026)
- `WorkoutTemplateKind`, `sourceID` y `durationMinutes` convierten el catálogo incluido y las sesiones generadas en rutinas persistidas editables.
- `WeeklyRoutine.sessionTemplateIDs` y `dailyChallengeTemplateIDs` enlazan agenda y desafíos a Plantillas; la decodificación anterior sigue soportada y se materializa al abrir Entrenamiento.
- Se eliminó `PresetDayEditor` y el editor especial de desafío. Ambos abren `WorkoutTemplateEditor`.
- `TemplateCodec` entiende `3x10`, `30`, `45s` y `12 min`; las modalidades sin peso usan `ActiveTimedRoutineView`.

**Deuda conocida (no bloqueante):**
- Los tipos de sesión nuevos (movilidad, plio, etc.) tienen labels en español hardcodeado, igual que el resto de FitnessView; pendiente la migración al String Catalog.
- El gestor de rutinas no tiene UI test propio (crear una rutina por UI es un flujo largo); su lógica de borrado es directa sobre SwiftData.
- Las marcas 1RM se guardan y muestran como %1RM objetivo en el editor; aún no se cruzan con el 1RM estimado de `ExerciseSetLog` para sugerir kg por serie.

## Si algo en este HANDOFF ya no coincide con el estado real del proyecto

Este archivo es una foto de un momento especifico. Si al leerlo notas que un archivo mencionado ya no existe, cambio de contenido, o una tarea ya fue hecha por otra sesion mientras tanto: **confia en lo que ves en el proyecto ahora mismo, no en lo que dice este documento**, y actualiza esta seccion o la lista de tareas si corresponde.
