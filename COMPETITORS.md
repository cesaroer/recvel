# Competidores y referencias

Este documento separa funciones observables, oportunidades de producto y limites. Recvel puede aprender de patrones de interaccion y categorias de metricas, pero no debe copiar nombres protegidos, textos, ilustraciones, pantallas, assets ni algoritmos propietarios.

## Matriz funcional

| Producto | Fortalezas observables | Datos y scores | Experiencia relevante | Oportunidad para Recvel |
| --- | --- | --- | --- | --- |
| Bevel | Vista integral de salud, nutricion, journal y coaching | Recovery, Strain, Sleep, Stress, Energy Bank, fitness y tendencias | Interfaz densa, pulida, dark-first y glassy | Explicabilidad superior, privacidad local y confirmacion de estimaciones |
| WHOOP | Narrativa diaria muy clara y fuerte disciplina de uso | Recovery, Strain, Sleep, Stress Monitor, Healthspan | Tres scores memorables, journal y coach conversacional | Misma claridad sin hardware ni suscripcion obligatoria |
| Garmin | Profundidad deportiva y gran historial longitudinal | Body Battery, HRV Status, Training Readiness, acute load, VO2 max | Mucho detalle para atletas, integracion con workouts | Traducir profundidad a decisiones simples sin saturar |
| Amazfit / Zepp | Amplio conjunto de salud con hardware accesible | Readiness, BioCharge, PAI, Sleep, Exertion, Zepp Coach | Resumen diario, food logging y ecosistema diverso | Mejor coherencia visual y uso nativo del ecosistema Apple |
| Oura | Sueno, recuperacion y habitos con narrativa calmada | Readiness, Sleep, Activity, Stress, Resilience | Insights breves y tendencias faciles de leer | Mayor riqueza de workout y nutricion en un solo producto |
| Athlytic | Aprovecha Apple Watch sin hardware adicional | Recovery, Exertion, Sleep, Energy y training load | Familiar para usuarios del ecosistema Apple | Diseño mas distintivo, nutricion y explicaciones de confianza |

## Bevel

Bevel es la referencia visual principal. Su sitio presenta integracion con Apple Watch y otras fuentes, y agrupa strain, sleep, recovery, stress, energy, nutrition, fitness, biological age, cycle, strength, journal, caffeine, water, widgets y coaching. Su ventaja es convertir muchas senales en una superficie coherente.

Recvel debe adoptar conceptualmente:

- Dashboard jerarquico que responde primero "como estoy hoy".
- Profundidad bajo demanda: score, factores, grafica y dato fuente.
- Materiales translucidos, color semantico y animacion sobria.
- Nutricion integrada con el resto de la recuperacion.

Riesgos a evitar:

- Apariencia o nomenclatura demasiado cercanas a Bevel.
- Scores opacos que parezcan clinicamente exactos.
- Exceso de tarjetas decorativas o blur que reduzca legibilidad.

Fuente primaria: [Bevel Health](https://www.bevel.health/es).

Gap analysis dedicado Free vs Pro (capturas `bevelpro_features_*.PNG`) frente a lo implementado en Recvel: **[BEVEL_PRO_GAP_ANALYSIS.md](BEVEL_PRO_GAP_ANALYSIS.md)**.

## WHOOP

WHOOP organiza su producto alrededor de Sleep, Strain y Recovery, complementado por Stress, Journal, Healthspan y WHOOP Coach. El valor no esta solo en medir: crea un ciclo diario de observar, actuar y aprender. La ficha publica tambien deja claro que es un producto de fitness y wellness, no un dispositivo medico.

Patrones utiles:

- Pocos indicadores principales, repetidos consistentemente.
- Journal para estudiar asociaciones entre conducta y recuperacion.
- Recomendaciones accionables conectadas al estado del dia.
- Contexto historico, no lectura aislada de una medicion.

Fuente primaria: [WHOOP en App Store](https://apps.apple.com/us/app/whoop/id933944389).

## Garmin

Garmin destaca por profundidad fisiologica y deportiva. Body Battery intenta representar energia disponible; Training Readiness combina sueno, recuperacion, HRV y carga; HRV Status compara tendencias contra un rango personal; acute load y VO2 max contextualizan entrenamiento.

Lecciones para Recvel:

- Diferenciar preparacion, carga y rendimiento: no son el mismo score.
- Mantener baselines personales de varias semanas.
- Mostrar por que cambia un indicador y cuanto dato lo respalda.
- Permitir vistas avanzadas sin convertir el inicio en una consola tecnica.

Referencias: [Garmin Health Science](https://www.garmin.com/en-US/garmin-technology/health-science/) y [explicacion general de funciones Garmin en WIRED](https://www.wired.com/story/garmins-top-training-features-explained/).

## Amazfit y Zepp

Zepp combina Readiness, Sleep, Exertion, PAI y coaching. Productos recientes han usado BioCharge como lectura continua de energia y han incorporado registro de alimentos asistido por IA. Es una referencia importante para la amplitud funcional a menor costo.

Lecciones para Recvel:

- Un resumen diario debe convivir con metas de actividad a largo plazo.
- La nutricion necesita un flujo rapido, pero siempre editable.
- Los nombres propios de competidores no deben reutilizarse.

Referencias editoriales iniciales: [Amazfit Active 3 en TechRadar](https://www.techradar.com/health-fitness/fitness-trackers/amazfit-active-3-premium-review) y [Amazfit Helio Strap en Tom's Guide](https://www.tomsguide.com/wellness/fitness-trackers/amazfit-helio-strap-review).

## Evidencia y limites cientificos

### HRV

HRV depende de edad, postura, respiracion, hora, fatiga, alcohol, enfermedad, artefactos y protocolo. Recvel debe comparar a la persona consigo misma, preferir ventanas consistentes y evitar umbrales universales. Apple Health expone principalmente SDNN; no se debe mezclar sin explicacion con RMSSD de otros dispositivos.

Punto de partida: [Heart rate variability overview](https://en.wikipedia.org/wiki/Heart_rate_variability). Antes de publicar recomendaciones se requieren revisiones sistematicas y fuentes primarias especificas para cada claim.

### Sueno en wearables

Los wearables suelen ser mas utiles para duracion, horario y tendencias que para clasificacion clinica exacta de etapas. No deben usarse para descartar apnea u otros trastornos. Recvel debe indicar incertidumbre y recomendar evaluacion profesional ante sintomas persistentes.

Mapa inicial de referencias: [Sleep tracking overview](https://en.wikipedia.org/wiki/Sleep_tracking).

### Reconocimiento de alimentos

Reconocer el tipo de alimento no resuelve la porcion, densidad, ingredientes ocultos ni aceite. La estimacion monocular de volumen es un problema abierto y sensible al angulo y la escala. Por ello el resultado de Recvel sera una propuesta editable con rango, no una verdad automatica.

Fuentes iniciales: [survey de reconocimiento de comida por imagen](https://arxiv.org/abs/2106.11776) y [trabajo sobre estimacion de porciones](https://arxiv.org/abs/2602.05078).

## Diferenciacion propuesta

- Todo el procesamiento posible en el dispositivo.
- Sin hardware propietario ni paywall en v1.
- Confianza visible y factores de cada score.
- Nutricion conectada a energia, actividad y recuperacion, con confirmacion humana.
- Lenguaje en espanol claro, sin alarmismo ni claims medicos.
- Un sistema visual propio: negro profundo, vidrio legible, acentos multicolor y movimiento funcional.

## Backlog competitivo priorizado

| Prioridad | Capacidad | Razon |
| --- | --- | --- |
| P0 | Recovery, Strain, Sleep, Energy y datos HealthKit | Nucleo de valor diario |
| P0 | Baselines, confianza y explicacion | Reduce falsa precision |
| P0 | Estados sin datos y permisos parciales | Condicion real de HealthKit |
| P1 | Trends, journal y correlaciones | Convierte datos en aprendizaje |
| P1 | Nutricion por texto, voz y foto | Diferenciador de uso frecuente |
| P1 | Widgets y notificaciones locales | Habito diario sin backend |
| P2 | Apple Watch workouts y resumen | Captura y acceso inmediato |
| P2 | Strength, cycle, biological age | Expansion tras validar el nucleo |

### Sugerencias Grok

Backlog priorizado post-analisis competitivo (julio 2026). Lista canónica con checkboxes en `README.md` / `README_APP.md`.

| Prioridad | Capacidad | Razon |
| --- | --- | --- |
| P0 | Widgets Home / Lock Screen | Loop diario glanceable; Athlytic/Bevel ganan aqui |
| P0 | Morning Report rico | Amplia notifs basicas a un resumen accionable al despertar |
| P0 | Food-101 Core ML + reglas clinicas 12.10 | Nutricion creible y segura vs Vision generico |
| P0 | Validacion en Apple Watch real | Cierra calidad de datos, zonas, bateria y notifs |
| P1 | Bateria de energia continua (nombre propio) | Un numero memorable tipo Body Battery / Energy Bank |
| P1 | Journal rico + correlacion ayuno↔Recovery | Aprendizaje personal con nutricion incluida |
| P1 | Coach Q&A local (sin nube de salud) | Cierra brecha vs Bevel Intelligence / WHOOP Coach |
| P1 | Citas cientificas en UI + export/backup | Confianza y ownership de datos |
| P2 | watchOS, Live Activities, edad biologica opt-in, ciclo, strength builder, snapshot, smart alarm, VO2/SpO2 UI | Paridad de mercado tras el nucleo diario |

No priorizar: multi-wearable cloud, paywall, backend, bloodwork clinico ni calorias exactas desde foto sola.

### Estado P0 de Recvel

El P0 implementado en simulador cubre el ciclo diario central observado en WHOOP, Bevel y Garmin: lectura HealthKit, baseline personal robusto, Recovery/Strain/Sleep/Energy, confianza, explicacion de factores, detalle de sueno, workouts con zonas, objetivo de carga, necesidad de sueno, estado sin datos y recordatorios locales. No se afirma paridad con algoritmos propietarios ni se muestran etapas o scores cuando faltan muestras.

### Auditoria de `bevel_reference.mp4` y respuesta de Recvel

- **Recovery:** Bevel combina hero, senales nocturnas, explicacion, timeline y tendencias del score/HRV/FC. Recvel conserva factores contra baseline, agrega tendencia del propio Recovery y una tarjeta que elige una unica palanca accionable con sus senales de origen.
- **Strain:** Bevel muestra rango objetivo, duracion, energia, timeline, zonas y muchas tendencias. Recvel ya cubre esas capas y agrega margen restante, volumen semanal registrado y minutos Z4-Z5 para evitar que el usuario interprete el objetivo como cuota obligatoria.
- **Sleep:** Bevel destaca tiempo en cama/dormido, Sleep Needed, Target Bedtime, timeline y tendencias de score, etapas, banco, horario, latencia y wake time. Recvel agrega un plan prospectivo de desconexion/cama/despertar, brecha reciente, latencia, cafeina, eficiencia y consistencia; mantiene etapas agregadas porque no inventa intervalos que HealthKit no entregue de forma fiable.
- **Energy:** Bevel muestra carga y descarga intradia. Recvel no replica esa curva sin muestras temporales; en su lugar muestra los tres contribuyentes reales y una recomendacion de ritmo explicable.

La referencia se usa para arquitectura de informacion y densidad, no para copiar textos, assets, nombres propietarios ni formulas.

Pendiente de dispositivo real: validar calidad y precedencia de fuentes, autorizaciones HealthKit, FC durante workouts, bateria y notificaciones. Pendiente de fases posteriores: watchOS, widgets, fuerza estructurada, ciclo, edad biologica y coach conversacional.

## Patrones implementados y por que

La revision de julio de 2026 priorizo ciclos de decision completos sobre paridad superficial:

- **Carga objetivo:** WHOOP ajusta Optimal Strain usando Recovery y carga acumulada. Recvel implementa un objetivo local adaptable y muestra cuanto margen queda, con una escala propia y sin afirmar equivalencia algoritmica. Fuente: [WHOOP Strain](https://support.whoop.com/s/article/WHOOP-Strain?language=en_US).
- **Necesidad de sueno dinamica:** WHOOP combina baseline, carga, deuda y siestas. Recvel implementa baseline, carga y deuda con una hora de cama editable; las siestas quedan pendientes porque requieren normalizacion adicional de HealthKit. Fuente: [WHOOP Sleep](https://support.whoop.com/s/article/WHOOP-Sleep?language=en_US).
- **Journal con umbral minimo:** WHOOP exige 5 respuestas afirmativas y 5 negativas dentro de una ventana para mostrar impactos. Recvel usa el mismo criterio estadistico minimo como patron conceptual, calculado localmente contra DailyScoreRecord. Fuente: [WHOOP Recovery Impacts](https://support.whoop.com/s/article/Recovery-Insights).
- **Plan semanal:** metas de sueno, carga, zonas, actividades y comportamientos son un ciclo valioso de WHOOP. Recvel inicia con workouts, suficiencia de sueno y carga equilibrada, todos editables y medidos desde datos locales de la semana calendario; el tab Plan tambien muestra el enfoque del dia y el sueno de esta noche adaptado a deuda/carga. Fuente: [WHOOP Weekly Plan](https://support.whoop.com/s/article/Weekly-Plan?language=en_US).
- **Activacion, no "estres mental":** WHOOP distingue activacion fisiologica de percepcion emocional. Recvel usa FC relativa al reposo y evita diagnosticar estres; explica que enfermedad, hidratacion o sueno tambien pueden mover la senal. Fuente: [WHOOP Stress Monitor](https://support.whoop.com/s/article/Get-to-Know-the-Stress-Monitor?language=en_US).

No se implementaron nombres propietarios como Body Battery o Energy Bank. Tampoco se mostraron correlaciones con pocos datos ni calorias de foto sin confirmacion.

## Detalle ampliado por producto (investigacion 2026)

Ampliacion de la matriz funcional con datos concretos encontrados en documentacion oficial, blogs de producto y prensa especializada. Todo es informacion publica de referencia; ningun nombre, texto ni algoritmo propietario debe copiarse literalmente.

### Bevel — detalle ampliado

- Scores: **Recovery**, **Strain** (ajustada a la capacidad segun sueno/recovery), **Sleep**, **Stress** en tiempo real, **Energy Bank** (bateria de energia que combina recovery + sueno + strain + stress a lo largo del dia), **Nutrition Score**.
- **Biological Age**: se recalcula semanalmente con sueno, actividad, FC en reposo y, opcionalmente, resultados de laboratorio (bloodwork) cargados por el usuario.
- **Panel "Biology"**: VO2 max, baseline de FC en reposo, baseline de HRV, peso, grasa corporal, masa magra. Importante: **Bevel no calcula VO2 max propio**, lo toma directo de Apple Health y lo compara contra una tabla poblacional por edad/sexo — mismo enfoque que deberia seguir Recvel.
- **Cycle tracking** incluido sin costo, cruzando fase del ciclo con baseline de HRV.
- **Registro de alimentos multi-modal**: escaneo de codigo de barras, busqueda por foto, creacion de receta, "Describe Meal" (texto libre/conversacional), busqueda manual en base de +6M alimentos. Mejora reciente (2025-2026): logging conversacional que crea alimentos personalizados y permite editar la porcion despues de guardar.
- **Bevel Intelligence**: motor de IA que sugiere cuando entrenar/descansar; incluye "Personalities" (tono de coaching seleccionable: Data Nerd, Guardian, Friend, Commander).
- **Strength Builder**: +700 ejercicios, feedback de "carga muscular" en tiempo real, sincronizacion telefono-reloj.
- Fuentes de datos: Apple Watch (principal), Garmin Connect, Oura Ring, Strava (solo lectura de workouts); no se encontro integracion nativa con WHOOP.
- Otros: Health Records (subir documentos clinicos), Journal (hidratacion, luz solar, pantallas, habitos), widgets iOS/Mac, Live Activities/Dynamic Island.

Fuentes: [App Store: Bevel](https://apps.apple.com/us/app/bevel-ai-health-coach/id6456176249) · [Bevel release notes — Introducing Biology](https://docs.bevel.health/release-notes/b/B8960E94-5FFA-4E19-B9B8-3AD357924457/Jun-28-2024-Introducing-Biology) · [Bevel release notes — 2025 Fall/Winter](https://docs.bevel.health/release-notes/b/2790BF67-C2C3-4B45-8344-A97FA266F149/Nov-20-2025-Bevel-2025-Fall-Relea) · [Bevel membership y pricing](https://help.bevel.health/en/articles/11583937) · [Neura Health — review de Bevel](https://neura.health/insight/bevel-health-app-in-depth-review) · [Autonomous — review de Bevel](https://www.autonomous.ai/ourblog/bevel-app-review)

### WHOOP — detalle ampliado

- **Recovery (0-100)**: combina HRV, FC en reposo, calidad/duracion de sueno, frecuencia respiratoria, temperatura de piel y oxigeno en sangre de la noche anterior. Zonas: verde 67-100, amarillo 34-66, rojo 0-33. La ponderacion exacta es propietaria; WHOOP muestra las senales crudas pero no la formula.
- **Strain (0-21)**: numero adimensional inspirado conceptualmente en la escala de esfuerzo percibido de Borg; crece segun tiempo en zonas de FC durante el dia.
- **Stress Monitor**: score 0-3 en tiempo real desde FC + HRV vs. baseline personal.
- **Journal**: +160 habitos diarios correlacionados contra Recovery/HRV/FC en reposo para mostrar "impactos en la recuperacion" personalizados.
- **Healthspan / WHOOP Age / Pace of Aging** (2025): combina nueve metricas de sueno, actividad y forma fisica (incluye VO2 max, FC en reposo, consistencia de sueno y actividad de fuerza) en una "edad WHOOP" y un multiplicador de "ritmo de envejecimiento", recalculados semanalmente.
- **Women's Hormonal Insights** (WHOOP 5.0/MG): ciclo menstrual, fluctuacion hormonal y embarazo cruzados con sueno/strain/recovery.
- **ECG bajo demanda** (hardware WHOOP MG).
- **WHOOP Coach**: chat en lenguaje natural sobre modelos de OpenAI, afinado con datos anonimizados de usuarios y los algoritmos propios de WHOOP; explica por que cambia un score y responde preguntas de ciencia del deporte.
- Membresias 2025: WHOOP One (rendimiento), WHOOP Peak (longevidad), WHOOP Life (con hardware MG, insights cardiovasculares).
- **Sin confirmar** en esta investigacion: funciones de "hyperbaric" o "densidad osea" — no se encontro fuente vigente que las respalde; verificar antes de citarlas.

Fuentes: [WHOOP Healthspan](https://www.whoop.com/us/en/healthspan/) · [WHOOP 5.0 y MG](https://www.whoop.com/us/en/thelocker/introducing-whoop-5-0-and-whoop-mg/) · [Todo lo lanzado por WHOOP en 2025](https://www.whoop.com/us/en/thelocker/everything-whoop-launched-in-2025/) · [WHOOP Coach con OpenAI](https://www.whoop.com/us/en/thelocker/whoop-unveils-the-new-whoop-coach-powered-by-openai/) · [Caso de estudio OpenAI x WHOOP](https://openai.com/index/whoop/) · [Introducing Stress Monitor](https://www.whoop.com/us/en/thelocker/introducing-stress-monitor-a-new-way-to-monitor-manage-stress/) · [WHOOP for Developers — WHOOP 101](https://developer.whoop.com/docs/whoop-101/) · [Women's Hormonal Health (Femtech Insider)](https://femtechinsider.com/whoop-launches-new-wearables-with-enhanced-focus-on-womens-hormonal-health/)

### Garmin — detalle ampliado

- **Body Battery**: gauge 0-100 sobre RMSSD, estres diurno derivado de patrones de HRV y calidad/duracion del sueno nocturno; corre sobre los modelos fisiologicos Firstbeat (propiedad de Garmin).
- **HRV Status**: promedio movil de 7 dias de HRV nocturna para construir un baseline personal, clasificado como Balanced/Unbalanced/Low/Poor.
- **Training Readiness (0-100)**: combina sueno, HRV Status, tiempo de recuperacion restante, carga aguda de entrenamiento, historial de estres y Body Battery. >73 = listo para esfuerzo exigente; <34 = fatiga acumulada.
- **Training Load y ratio agudo:cronico**: carga aguda (~7 dias) dividida entre carga cronica (~4 semanas); ratio >1.5 se marca como riesgo elevado (modelo ACWR clasico de ciencia del deporte — ver seccion de evidencia en AI_CONTEXT.md sobre sus limitaciones).
- **Training Status**: Productive/Maintaining/Detraining segun la tendencia de VO2 max en semanas recientes, no un valor aislado.
- **Sleep Score y Sleep Coach**: Sleep Coach recomienda cuanto dormir la noche siguiente segun carga de entrenamiento reciente (prospectivo, no solo retrospectivo).
- **Race Predictor**: proyecta tiempos de carrera (5K/10K/21K/42K) desde VO2 max e historial de entrenamiento.
- **Morning Report** y **Health Snapshot** (medicion de 2 minutos en quietud: FC, HRV, SpO2, respiracion, estres) son patrones directamente replicables sin hardware propio.

Fuentes: [Garmin — Training Readiness](https://www.garmin.com/en-US/garmin-technology/running-science/physiological-measurements/training-readiness/) · [Garmin Support — Acute/Chronic Load](https://support.garmin.com/en-US/?faq=C6iHdy0SS05RkoSVbFz066) · [Garmin Support — Health Snapshot](https://support.garmin.com/en-US/?faq=PB1duL5p6V64IQwhNvcRK9) · [the5krunner — Body Battery](https://the5krunner.com/garmin-features/sleep/body-battery/) · [the5krunner — Training Readiness](https://the5krunner.com/garmin-features/training/training-readiness/) · [Garmin Blog — Top 10 funciones de salud](https://www.garmin.com/en-US/blog/health/top-10-features-to-monitor-your-health/)

### Amazfit / Zepp — detalle ampliado

- **PAI (Personal Activity Intelligence)**: unico score entre los competidores con **respaldo academico publicado**: algoritmo desarrollado por investigadores de la NTNU (Noruega) sobre el HUNT Fitness Study (35 anos, ~230,000 participantes), que asocia PAI >=100 con menor riesgo de hipertension, enfermedad cardiovascular y diabetes tipo 2. Se calcula por elevacion de FC sobre el baseline en reposo en una ventana movil de 7 dias, ajustado por edad, sexo y FC en reposo.
- **Readiness** (sueno, HRV, respiracion, temperatura) y **BioCharge** (bateria de energia 0-100) como scores complementarios.
- **Zepp Coach**: planes de entrenamiento generados por IA segun nivel, horario y objetivos.
- **Registro de alimentos por IA**: la app Zepp usa explicitamente **GPT-4o** para procesar la foto (~10-20 segundos), entregando desglose de carbohidratos/proteina/grasa/calorias; reconocimiento bueno, estimacion de porcion "irregular" segun revisores.

Fuentes: [Zepp Technology](https://www.zepp.com/technology) · [Amazfit — pagina de tecnologia de salud](https://us.amazfit.com/pages/amazfit-technology-page-health-technology) · [Que es PAI en Amazfit](https://biologyinsights.com/what-is-pai-on-amazfit-and-how-does-it-work/) · [Gadgets & Wearables — Zepp AI food log](https://gadgetsandwearables.com/2025/04/04/zepp-health-ai-food-log/) · [Amazfit — Snap, Log, Achieve](https://us.amazfit.com/blogs/blog/snap-log-achieve-track-your-food-with-zepp)

### Oura — detalle ampliado

- **Readiness (0-100)**: siete contribuyentes — sueno de la noche anterior, balance de sueno (deuda acumulada), balance de actividad, desviacion de FC en reposo, balance de HRV (tendencia multi-dia), desviacion de temperatura corporal, indice de recuperacion (velocidad de recuperacion de FC).
- **Stress**: separado en Daytime Stress (FC, HRV, movimiento, temperatura durante el dia) y Cumulative Stress (horizonte mas largo).
- **Resilience**: ventana movil de 14 dias que combina carga de estres diurno, tiempo restaurativo diurno y recuperacion nocturna; se clasifica en 5 niveles (Limited a Exceptional).
- **Cardiovascular Age** y **Health Radar** (2026, incluye senales de presion arterial nocturna por PPG y respiracion nocturna) — funciones nuevas que comenzaron como "Oura Labs" experimentales antes de lanzamiento general.
- **Symptom Radar**: senales fisiologicas asociadas a enfermedad inminente (temperatura, FC en reposo, HRV, sueno alterado).
- **Sin confirmar**: integracion "meQ" de resiliencia mental — no se encontro fuente vigente; verificar antes de citar.

Fuentes: [Oura — Introducing Health Radar](https://ouraring.com/blog/introducing-health-radar/) · [Oura — Readiness Score explicado](https://ouraring.com/blog/readiness-score/) · [Oura — Resilience](https://ouraring.com/blog/inside-the-ring-resilience-feature/) · [Oura Support — Cumulative Stress](https://support.ouraring.com/hc/en-us/articles/45979919957395-Cumulative-Stress) · [Oura Support — Symptom Radar](https://support.ouraring.com/hc/en-us/articles/35593651188115-Symptom-Radar)

### Athlytic — referencia mas cercana a Recvel

Athlytic demuestra que una suite completa de recovery/readiness es viable solo con sensores de Apple Watch, sin hardware propio — la misma restriccion tecnica de Recvel:

- **Recovery (0-100%)**: HRV + FC en reposo contra un baseline movil de **60 dias**.
- **Exertion**: carga cardiovascular continua durante todo el dia, no solo en workouts formales (analogo a Strain).
- **Sleep Quality (%)**: pondera sueno restaurador (REM+Deep), tiempo despierto, interrupciones y frecuencia respiratoria.
- **Target Sleep / Target Bed Time**: calculado desde Recovery, Exertion, sueno y deuda de sueno acumulada, recomendando cuanto dormir y a que hora acostarse.
- **Athlytic Age**: metrica tipo edad biologica que ahora incorpora recuperacion de FC ademas de VO2 max, limitada a sesiones de intensidad relevante.

Fuentes: [Athlytic — App Store](https://apps.apple.com/us/app/athlytic-ai-fitness-coach/id1543571755) · [Athlytic — Getting Started](https://www.athlyticapp.com/getting-started) · [Neura Health — review de Athlytic](https://neura.health/insight/athlytic-app-in-depth-review) · [Vora — mejores apps de recovery para Apple Watch 2026](https://askvora.com/blog/best-apple-watch-recovery-apps-2026)

## Patron comun: registro de alimentos por IA (foto/texto)

Analisis cruzado de Bevel, Amazfit/Zepp, Cal AI y MyFitnessPal Meal Scan confirma un flujo comun que Recvel deberia replicar:

1. **Captura**: foto (camara o galeria) o texto libre describiendo la comida; codigo de barras como respaldo casi universal para alimentos empaquetados.
2. **Inferencia**: un modelo multimodal identifica alimentos y estima porcion desde la imagen. Zepp declara explicitamente el uso de GPT-4o; Bevel y Cal AI no revelan su modelo.
3. **Confirmacion editable (patron obligatorio, no opcional)**: toda app relevante muestra una pantalla de resultado editable antes de guardar — permite corregir el alimento identificado, ajustar la porcion/cantidad y ver el recalculo en vivo de macros y calorias.
4. **Punto debil universal**: la estimacion de porcion/volumen desde una foto 2D es el problema sin resolver en todas las apps revisadas; por eso el paso de confirmacion manual es central en la UX, no un extra.
5. **Senal de mercado**: MyFitnessPal adquirio Cal AI en marzo de 2026, lo que indica que el registro por foto con IA ya se considera una funcion base esperada, no un diferenciador.

Fuentes: [TechCrunch — MyFitnessPal adquiere Cal AI](https://techcrunch.com/2026/03/02/myfitnesspal-has-acquired-cal-ai-the-viral-calorie-app-built-by-teens/) · [MyFitnessPal Help — Meal Scan FAQ](https://support.myfitnesspal.com/hc/en-us/articles/360045761612-Meal-Scan-FAQ) · [Gadgets & Wearables — Zepp AI food log](https://gadgetsandwearables.com/2025/04/04/zepp-health-ai-food-log/)

## Implicacion para Recvel: nutricion local vs. modelos cloud

La mayoria de experiencias recientes de "foto -> comida -> calorias" en competidores parecen depender de modelos multimodales cloud o no revelan su arquitectura. Zepp declara uso de GPT-4o para su food log; MyFitnessPal/Cal AI y Bevel no publican un modelo pequeno local comparable. Para Recvel, que por contrato no tiene backend ni envio de datos de salud en v1, la experiencia debe competir con UX y privacidad, no con una promesa falsa de exactitud automatica.

Decision de producto:

- Recvel v1 no hara fine-tuning. Usara modelos ya existentes y locales cuando sea viable. **Actualizado julio 2026 tras verificacion factual (ver [Calorie_AI_Research.md](Calorie_AI_Research.md)):** la via principal para imagen es un clasificador Food-101 ya entrenado por terceros (convertido a Core ML) + base de datos nutricional local, no un VLM pequeno — el VLM queda como idea secundaria/experimental. Para texto: Foundation Models/parser local. Para empaquetados: Vision para barcode/OCR.
- Los modelos locales pequenos pueden **sugerir candidatos y rangos**, no afirmar calorias finales.
- La cifra final vendra de base nutricional local + porcion confirmada.
- Barcode/OCR/etiqueta y alimentos repetidos del usuario son los caminos de mayor precision.
- Foto sola debe mostrar rango de kcal y confianza, especialmente en platos mixtos.
- Si en el futuro se considera un SDK comercial de nutrition AI como Passio, debe pasar revision explicita de privacidad, procesamiento local real, licencias, costos y posibilidad de funcionar offline. La documentacion actual de Passio apunta a APIs remotas/LLMs cloud para su modo principal, por lo que no encaja en local-first v1 sin excepcion.

Referencias tecnicas para la evaluacion: [Apple Core ML](https://developer.apple.com/documentation/coreml), [Apple Foundation Models](https://developer.apple.com/documentation/foundationmodels), [SmolVLM-256M-Instruct](https://huggingface.co/HuggingFaceTB/SmolVLM-256M-Instruct), [Moondream2](https://huggingface.co/vikhyatk/moondream2), [Qwen2.5-VL-3B-Instruct](https://huggingface.co/Qwen/Qwen2.5-VL-3B-Instruct), [Passio Nutrition AI](https://passio.gitbook.io/nutrition-ai), [Food-101](https://data.vision.ee.ethz.ch/cvl/datasets_extra/food-101/), [Nutrition5k](https://github.com/google-research-datasets/Nutrition5k), [USDA FoodData Central Downloads](https://fdc.nal.usda.gov/download-datasets/) y [survey de reconocimiento/volumen de alimentos](https://arxiv.org/abs/2106.11776).

## Nota de fecha y verificacion

Toda la investigacion anterior corresponde a busquedas realizadas en julio de 2026; varios lanzamientos citados (WHOOP Healthspan, Oura Health Radar, Bevel Fall/Winter release) son de 2025-2026 y pueden seguir cambiando. Dos afirmaciones quedaron sin poder confirmarse con una fuente vigente y deben verificarse antes de citarlas en materiales externos: funciones de "hyperbaric"/densidad osea en WHOOP, y la integracion "meQ" en Oura.

## Complemento: StressWatch + Stress / VO2 / Bio Age (julio 2026)

Documento canonico de plan + evidencia: **[README_StressAndBio.md](README_StressAndBio.md)**.

### StressWatch (no estaba en la matriz original)

| Aspecto | Detalle |
| --- | --- |
| Que mide | Estres **fisico** / presion corporal via HRV + RHR vs baseline personal |
| Bandas | Excellent → Normal → Attention → Overload |
| HRV | Apple Health entrega **SDNN**; Recvel debe nombrar la metrica real y no presentarla como RMSSD |
| Docs | [Principio de medicion](https://docs.ideation.love/stresswatch/en/) |

Patron a adaptar en Recvel (nombres propios ES): Excelente / Normal / Atencion / Sobrecarga + confianza. No copiar UI ni claims de “AI stress” clinico.

### Estado Recvel tras la comparacion

| Prioridad | Capacidad | Nota |
| --- | --- | --- |
| Hecho | Seccion Home **Stress** + query/tendencia **VO2** | Score diario con baseline, confianza y detalle |
| Hecho | **Bio Age por lentes trazables** | Cardio FRIEND y PhenoAge con panel completo; nunca se mezclan |
| Hecho | SpO2 UI, bloodwork opt-in y Clinical Records | Catalogo local, alta manual e importacion FHIR contextual |

Bevel Biological Age usa opcionalmente bloodwork; WHOOP Age/Healthspan combina VO2, RHR, sueno y fuerza. Esto demuestra demanda de mercado, no valida copiar pesos propietarios. Recvel usa FRIEND o PhenoAge publicado (Levine, 9 biomarcadores sanguineos) como lentes independientes. Sueno, pasos, zonas cardiacas, fuerza, RHR, masa magra, nutricion, alcohol y tabaco son factores explicativos de cuatro semanas y no modifican anos. Los cortes de Stress Recvel son heuristica propia pendiente de calibracion.

## Complemento: Journal y Biology observados en Bevel (15 julio 2026)

Patrones adoptados conceptualmente, con identidad y textos Recvel:

- Calendario semanal compacto con estado de registro y acceso al mes completo.
- Entradas automaticas, hibridas y manuales; defaults, pins, umbrales, busqueda y tags propios.
- Insights con muestras `Si/No`, asociaciones positivas/negativas y advertencia de no causalidad.
- Pantalla Biology con edad, confianza, fecha, factores fisiologicos y biomarcadores navegables.
- Bloodwork opcional para una lente validable, sin intentar reconstruir la formula propietaria multivariable de Bevel.

Recvel conserva diferenciadores propios: diario mental guiado, calendario mensual completo, dia wake-to-wake explicito, dos relojes cientificamente trazables, detalle de fuente/frescura y procesamiento local.
