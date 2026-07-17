# Recvel

Recvel es una app de bienestar para iPhone y Apple Watch que convierte los datos de Apple Health en una lectura diaria clara de recuperacion, carga, sueno, estres, energia, actividad y nutricion. La experiencia visual es dark-first, moderna y glassy, inspirada conceptualmente en productos como Bevel, WHOOP y Garmin, sin copiar su marca, textos, algoritmos privados ni assets.

## Principios del producto

- **Local-first:** datos, baselines, scores, comidas e insights permanecen en el dispositivo.
- **Privacidad por defecto:** sin cuenta, backend, anuncios ni analytics externos en v1.
- **Explicable:** cada score debe mostrar sus factores, datos faltantes y nivel de confianza.
- **Asistencial, no clinico:** Recvel informa sobre bienestar y tendencias; no diagnostica, trata ni sustituye a profesionales de salud.
- **Confirmacion humana:** cualquier estimacion nutricional por IA debe poder corregirse antes de guardarse.
- **Calidad continua:** cada cambio de codigo debe terminar con una compilacion correcta y pruebas proporcionales al riesgo.

## Plataforma y stack

- SwiftUI nativo, iOS 17 o posterior.
- HealthKit como fuente principal de salud y actividad.
- SwiftData para persistencia local.
- Charts para tendencias y comparaciones.
- Vision, NaturalLanguage y Core ML para capacidades on-device.
- watchOS companion previsto para captura de workouts, frecuencia cardiaca en vivo y resumen diario.

No se planea backend ni version premium durante la primera etapa. Todas las funciones disponibles estaran desbloqueadas.

## Datos de Apple Health

Recvel solicitara permisos de forma contextual y tolerara permisos denegados o datos parciales. Nunca se debe asumir que una persona usa Apple Watch todos los dias.

| Dominio | Datos principales |
| --- | --- |
| Cardiovascular | Frecuencia cardiaca, FC en reposo, HRV SDNN, recuperacion de FC, VO2 max |
| Respiratorio | Frecuencia respiratoria y SpO2 cuando esten disponibles |
| Sueno | Tiempo en cama, tiempo dormido, etapas, despertares y horario |
| Actividad | Workouts, pasos, distancia, energia activa y tiempo de ejercicio |
| Cuerpo | Peso, altura, IMC, grasa corporal y masa magra |
| Nutricion | Energia, macros, micronutrientes y agua existentes en HealthKit |
| Bienestar | Minutos de mindfulness, ciclo menstrual y sintomas autorizados |

Apple controla el acceso mediante autorizacion granular. La app no puede inferir que un permiso de lectura fue rechazado; debe funcionar con lo que HealthKit entregue. Referencia: [Apple Developer: HealthKit](https://developer.apple.com/documentation/healthkit).

## Modulos

### Today

Dashboard diario con Recovery, Strain, Sleep y Energy, metricas clave, calidad del dato y una recomendacion breve. Los componentes usan material, transparencias, profundidad y movimiento sutil con accesibilidad para Reduce Motion.

### Recovery

Combina desviaciones personales de HRV, FC en reposo, sueno, frecuencia respiratoria y carga reciente. El baseline debe ser individual, robusto ante outliers y requerir suficiente historial antes de mostrar alta confianza.

### Strain

Resume carga cardiovascular diaria usando duracion, intensidad, zonas de FC, energia activa y workouts. No debe equiparar calorias con calidad de entrenamiento.

### Sleep

Muestra duracion, eficiencia, consistencia, etapas y deuda estimada. Las etapas de dispositivos de consumo son aproximaciones; las recomendaciones deben centrarse primero en duracion y regularidad.

### Stress y Energy

Indicadores de tendencia basados en HRV, FC, actividad y sueno. Cuando no haya mediciones suficientes se mostrara baja confianza, nunca falsa precision.

**Actualizacion 15 de julio de 2026:** Home ya incluye **Stress** (bandas Excelente/Normal/Atencion/Sobrecarga), **VO2 Max** leido de HealthKit y **Bio Age** con dos lentes trazables. `Cardio · FRIEND beta` convierte VO2 max a una edad cardiorrespiratoria de referencia; `Sangre · PhenoAge` usa la formula publicada de Levine solo cuando existen los nueve analitos requeridos y recientes. Sueno, actividad y estilo de vida aparecen como factores de contexto, pero nunca modifican el numero principal. La investigacion, limites y unidades estan en [README_StressAndBio.md](README_StressAndBio.md).

### Journal Pro

Journal usa un dia **wake-to-wake**, calendario semanal y mensual, entradas de dia/noche, tags automaticos desde Apple Health, tags hibridos y tags manuales configurables. Las categorias sensibles estan apagadas por defecto. Insights compara Recovery o Sleep solo tras al menos 5 respuestas `Si` y 5 `No`, y siempre presenta asociaciones, no causalidad. El diario mental guiado se mantiene como un modulo propio dentro de Journal.

### Nutricion con IA

Entrada por foto, texto o voz. El flujo futuro combina reconocimiento visual, descripcion del usuario y una base nutricional local para proponer alimentos, porciones, calorias y macros. La persona revisa y confirma antes de guardar. Una fotografia 2D no determina por si sola volumen, ingredientes ocultos o metodo de coccion.

### Estrategia local para detectar comida y calorias

La investigacion vigente no encontro un modelo pequeno, local y generalista que pueda estimar calorias con alta certeza desde una sola foto en iPhone. Lo viable para Recvel es un pipeline local por niveles de confianza:

1. **Alta confianza:** codigo de barras, etiqueta nutricional por OCR, alimento conocido de HealthKit o gramos/porcion confirmados por el usuario. Aqui el numero viene de una base nutricional local, no de "adivinar" la foto.
2. **Confianza media:** texto o voz ("2 huevos, tortilla, 1 aguacate") parseado localmente y cruzado contra una base USDA/FNDDS/Open Food Facts empaquetada o descargada explicitamente en una fase posterior.
3. **Confianza baja-media:** foto de alimento simple. Un VLM pequeno ya entrenado propone alimentos, porcion aproximada, calorias/macros y dudas en JSON; el usuario confirma alimento y porcion.
4. **Confianza baja:** platos mixtos, salsas, aceites, bowls o comida parcialmente oculta. Usar segmentacion/deteccion solo para ayudar a editar componentes, no para guardar calorias automaticamente.

Arquitectura recomendada para v1 local:

```text
Foto / texto / voz / barcode
        |
        |-- Vision OCR + barcode -> producto/etiqueta -> base local
        |-- VLM local -> candidatos, porcion aproximada y rango
        |-- Segmentacion ligera opcional -> separar componentes editables
        |-- Parser local de lenguaje -> cantidades y unidades
        v
Normalizacion contra base nutricional local
        v
Pantalla editable: alimento, porcion, gramos, confianza, rango kcal
        v
Confirmacion manual -> SwiftData / HealthKit opcional
```

Modelos candidatos sin fine-tuning:

- **Imagen local:** usar un VLM pequeno ya entrenado como **SmolVLM-256M-Instruct** o **Moondream2** para responder con JSON: alimentos visibles, porcion aproximada, kcal/macros estimados, dudas y confianza. SmolVLM-256M es Apache 2.0, acepta imagen+texto y esta disenado para inferencia on-device con menos de 1 GB de memoria GPU; Moondream2 tambien es Apache 2.0 y se describe como un VLM pequeno para correr eficientemente. Son modelos generales, no nutricionistas.
- **Texto/voz local:** usar parser local/reglas y NaturalLanguage; si hace falta modelo, debe ser open weights permisivo, pequeno y gratis. Foundation Models puede explorarse solo como mejora opcional de plataforma, no como core, porque no es open source.
- **Barcode/OCR:** Vision local para codigo de barras y etiqueta nutricional. Esta ruta no necesita LLM y debe ser la de mayor confianza para productos empaquetados.
- **No usar en v1:** Passio, OpenAI, Anthropic, Google Cloud, Apple FastVLM ni Qwen2.5-VL-3B, por costo, cloud, licencia research-only/non-commercial o no cumplir open-source/cero pago.

Regla de producto: Recvel debe mostrar **rango y confianza**. "Muy certero" solo aplica cuando la porcion o etiqueta esta confirmada; foto sola debe comunicarse como estimacion asistida.

#### Complemento de investigacion (julio 2026): volumen, on-device real y bases de datos

- **Segmentacion local como ayuda, no como verdad nutricional:** Vision/Core ML pueden aislar objetos, correr clasificadores y detectar codigo de barras/OCR localmente. Para comida, una mascara visual ayuda a recortar el plato o separar regiones editables, pero no identifica ingredientes ocultos ni determina porcion.
- **LiDAR/depth mejora porcion solo en iPhone compatibles:** combinar profundidad metrica, plano de mesa/plato y mascara puede estimar volumen con mas informacion que una foto 2D. Aun asi requiere calibracion, geometria del plato y densidad estimada del alimento; en iPhone sin LiDAR se debe pedir porcion manual.
- **Depth monocular sigue siendo experimental para producto:** modelos como Depth Pro de Apple son prometedores para profundidad desde una sola imagen, pero no equivalen a una solucion Core ML validada para porciones de comida ni garantizan rendimiento/precision en todos los iPhone.
- **Foundation Models sirve mejor para texto/estructura que para calorias por vision:** si el dispositivo y sistema lo soportan, puede ayudar a convertir descripciones en datos estructurados. No debe ser motor obligatorio de nutricion mientras Recvel soporte iOS 17+ ni presentarse como experto cuantitativo de calorias.
- **No hay un modelo publico listo para produccion que resuelva comida + porcion + calorias con certeza.** Para v1 se usara un VLM listo, sin fine-tuning, con prompt estricto y salida JSON validada por la app. El numero se presenta como propuesta editable.
- **Base local recomendada:** USDA FoodData Central/FNDDS para alimentos genericos, Open Food Facts para empaquetados si se respeta licencia/atribucion, y una tabla curada Recvel para alimentos frecuentes en Mexico/LatAm.
- **Precedente de industria:** los competidores que ofrecen magia visual suelen usar modelos cloud o no revelan arquitectura. Recvel debe diferenciarse por privacidad, rapidez, edicion superior y honestidad de confianza, no por prometer exactitud automatica sin datos de porcion.

Decision actual: **no fine-tuning en v1**. Tomar modelos ya existentes, correrlos localmente cuando sea viable, y disenar el flujo de usuario alrededor de un resultado editable: `alimentos detectados -> porcion aproximada -> rango kcal/macros -> confirmar`.

#### Complemento de investigacion (julio 2026): VLMs pequenos on-device sin fine-tuning, evaluados uno por uno

Investigacion dirigida especificamente a si existe un VLM (modelo de vision-lenguaje) pequeno, ya entrenado, que se pueda correr en el dispositivo tal cual (zero-shot) para identificar comida y sugerir calorias, sin que nadie lo entrene:

- **Apple FastVLM** (0.5B/1.5B/7B, CVPR 2025) es el candidato tecnicamente mas atractivo: corre en iPhone real con demo oficial de Apple, es 85x mas rapido en "time to first token" que comparables. **Pero su licencia ("Apple Machine Learning Research Model License Agreement") prohibe explicitamente uso comercial** ("excludes any commercial exploitation, product development or use in any commercial product or service"). No se puede usar en Recvel sin un acuerdo de licencia aparte con Apple. Fuente: [apple/ml-fastvlm](https://github.com/apple/ml-fastvlm/blob/main/LICENSE_MODEL).
- **SmolVLM2** (256M/500M/2.2B, Apache 2.0, uso comercial permitido) no tiene conversion funcional a Core ML todavia (bug abierto por la operacion `unfold`, no soportada), pero si corre via MLX Swift o GGUF/llama.cpp en iPhone. Fuente: [coremltools#2599](https://github.com/apple/coremltools/issues/2599).
- **Moondream2** (1.8B, Apache 2.0) es, segun un paper especifico de evaluacion dietetica ("Are Vision-Language Models Ready for Dietary Assessment?", [arXiv 2504.06925](https://arxiv.org/html/2504.06925v1)), **el mejor VLM pequeno/abierto evaluado en reconocimiento de comida (54.71% Expert-Weighted Recall)**, pero queda 15 a 35 puntos porcentuales por debajo de modelos propietarios grandes (Gemini 70.16%). El propio paper concluye que los VLMs, grandes y pequenos, son "insuficientes para analisis dietetico comprehensivo" en condiciones reales.
- **El techo de la tecnica tampoco es confiable para numeros exactos:** incluso los modelos propietarios de ultima generacion (Gemini 2.5 Flash, GPT-4.1) tienen 20-56% de error (MAPE) al estimar macros desde una foto sin peso real conocido ([arXiv 2507.07048](https://arxiv.org/pdf/2507.07048)). Un VLM pequeno on-device no puede superar ese techo, solo acercarse por debajo.
- **Conclusion honesta:** hoy no existe un VLM pequeno, abierto, corrible en iPhone, que de un numero de calorias confiable de forma zero-shot. Por eso Recvel no debe usar un VLM como "oraculo de calorias" final. Si se incorpora un VLM (Moondream2 o SmolVLM2-500M via MLX/GGUF, siguiendo el precedente real de la app de App Store "Local LLM-Vision" que ya shippea VLMs on-device sin nube), debe ser solo como capa de **sugerencia de candidatos** (2-3 alimentos posibles) dentro del mismo pipeline de clasificador + base de datos + confirmacion manual ya documentado arriba, nunca devolviendo calorias finales sin pasar por la base nutricional y la confirmacion humana.
- **Para texto, `FoundationModels` si es viable hoy, pero solo como extractor/parser** ("2 huevos, una tortilla, medio aguacate" -> lista estructurada de alimento+cantidad), tarea para la que el modelo esta optimizado (summarization/extraction/classification). Pedirle el numero de calorias de memoria cae en "world knowledge", justo la categoria donde Apple documenta que el modelo es debil y puede alucinar. El patron correcto es usar el LLM solo para estructurar el texto y luego resolver el numero con una **tool local** que consulte la base de datos nutricional embebida (USDA/FNDDS), nunca con el conocimiento parametrico del modelo.

Esta investigacion confirma que la app permanece **100% local en esta etapa**: ningun hallazgo aqui requiere red ni API key. La incorporacion de un LLM/VLM en la nube con API propia de Recvel queda explicitamente para una segunda etapa posterior, fuera del alcance actual.

#### Actualizacion (julio 2026): rectificacion de via principal para la foto

La investigacion vigente vive completa en [Calorie_AI_Research.md](Calorie_AI_Research.md) y reemplaza cualquier decision previa sobre este feature. Decision actual: **sin fine-tuning, sin SDKs pagos, sin APIs cloud y sin modelos non-commercial/research-only**. El core debe usar modelos open source/open weights permisivos (SmolVLM/Moondream como candidatos visuales), datos abiertos (USDA/Open Food Facts con sus obligaciones) y una UI editable con rango/confianza. Los numeros finales deben salir de base nutricional local y porcion confirmada, no de la memoria parametrica del modelo.

### Trends y Journal

Graficas semanales, mensuales y de largo plazo, correlaciones prudentes y registro de habitos. Las correlaciones se comunican como asociaciones personales, no causalidad.

`Tendencias` ya no ocupa una tab principal: vive como una seccion navegable dentro de Home para conservar la lectura longitudinal sin desplazar flujos diarios. La tab liberada se dedica a `Fitness`.

### Fitness

La tab Fitness replica la jerarquia funcional observada en la referencia `Bevel_ref_2.mp4`, adaptada a los datos disponibles en Apple Health y a la identidad visual de Recvel:

- calendario de actividad de 30 dias y resumen acumulado;
- desempeno de Strain contra un objetivo diario ajustado por Recovery;
- carga cardiovascular, distribucion de foco por zonas y HRR al minuto 1 cuando existe una muestra post-workout;
- frecuencia y minutos de fuerza desde HealthKit;
- volumen por grupo muscular solo desde registros manuales confirmados;
- plantillas locales de workout y registro manual para actividades ausentes en HealthKit;
- detalles con breakdowns, contexto de interpretacion y limites de cada metrica.

Fitness no inventa series, repeticiones, peso ni recuperacion cardiaca. Cuando faltan zonas usa duracion como fallback de baja confianza, y cuando falta una muestra post-workout muestra un estado vacio.

### Apple Watch

La segunda fase agregara una app companion para iniciar workouts, observar FC en vivo y consultar Recovery, Strain y Sleep. Smart Alarm se evaluara despues de validar restricciones de watchOS, bateria y experiencia.

## Arquitectura propuesta

```text
SwiftUI Views
    |-- HealthDataProvider  -> HealthKit
    |-- ScoreEngine         -> Recovery / Strain / Sleep / Energy
    |-- BaselineEngine      -> historial y desviaciones personales
    |-- InsightEngine       -> explicaciones y recomendaciones
    |-- NutritionEstimator  -> texto / Vision / Core ML
    `-- LocalStore          -> SwiftData
```

Los algoritmos deben ser deterministas, versionados y probables con fixtures. La UI no debe contener logica de salud.

## Roadmap

1. **Fundacion:** proyecto iOS, navegacion, sistema visual, fixtures, persistencia y permisos HealthKit.
2. **Datos reales:** consultas HealthKit, normalizacion, baselines, calidad y estados parciales.
3. **Scores:** Recovery, Strain, Sleep, Stress/Energy con explicabilidad y pruebas.
4. **Nutricion:** texto y voz, base local, foto asistida y confirmacion manual.
5. **Inteligencia:** insights, journal, correlaciones, widgets y notificaciones locales.
6. **Apple Watch:** workouts, FC en vivo, complicaciones y resumen.
7. **Validacion:** accesibilidad, bateria, privacidad, QA cientifico y preparacion App Store.

## Estado actual

La app ya incluye una vertical funcional local-first, no solo pantallas:

- Onboarding persistente de cinco pasos para objetivo, prioridades, horario, meta de sueno y permisos Apple Health. Puede repetirse desde Ajustes.
- Lectura HealthKit de 14 dias para HRV SDNN, FC en reposo, respiracion, sueno, energia activa, pasos y workouts. El modo demo solo se activa explicitamente para previews y pruebas; sin datos autorizados la app muestra un estado vacio y nunca inventa scores.
- Sueno normalizado por fuente con intervalos solapados unidos, etapas Core/Deep/REM, despertares, latencia, eficiencia, consistencia y siestas. Si el dispositivo solo aporta duracion, la UI no fabrica etapas.
- Workouts con frecuencia cardiaca, cinco zonas, carga cardiovascular, energia, duracion y fuente cuando HealthKit aporta las muestras necesarias.
- Seleccion de fuente preferida para evitar mezclar muestras equivalentes de varios dispositivos; Apple Watch tiene prioridad para senales cardiacas. Los baselines usan mediana y filtrado MAD para resistir outliers.
- Briefing diario con Recovery explicable, baseline personal, necesidad y deuda de sueno, hora recomendada para acostarse, carga actual y objetivo adaptable.
- Calendario mensual estilo Bevel (`CalendarAndJournal`): celdas capsula, anillos segmentados, chips de categoria arriba del mes (multi-select hasta **2**, default Sleep+Stress); la tira semanal de Home usa el mismo tope y lenguaje visual.
- Curva de activacion fisiologica de 24 horas estimada desde FC relativa al reposo, siempre etiquetada como wellness.
- Plan adaptativo: ya no es tab; se abre desde Home (`dashboard.plan`) o el FAB `+`. Resumen en Home (enfoque, sueno de esta noche, conteos semanales) y detalle con metas editables (entrenos, noches, carga, nutricion, check-in calmado), ritmo/semana suave, recordatorios locales opcionales, y en Esta noche avisos de rutina/cama alineados a ciclos mas una rutina previa editable (presets de wind-down).
- Journal (tab): check-in Si/No, grafica de ritmo 14 dias, impactos vs Recovery (5/5), y diario mental stoico (`MentalJournalEntry`, una reflexion por dia + historial).
- Nutricion por texto y foto on-device mediante Vision, catalogo nutricional local, reconocimiento de cantidades y ajuste obligatorio de porcion antes de guardar.
- Detalles especializados, no plantillas genericas: Recovery explica contribuciones y rangos personales de HRV/FC/sueno/respiracion; Sleep muestra ventana, latencia, eficiencia, composicion agregada, balance de siete dias y tendencias; Strain incluye objetivo adaptable, timeline de workouts, zonas de FC y calibracion; Energy expone el balance entre Recovery, Sleep y Strain junto con el contexto de actividad.
- Capa accionable en cada detalle: Recovery selecciona la palanca mas debil contra baseline; Sleep calcula desconexion, hora de cama, despertar, oportunidad y corte orientativo de dosis grandes de cafeina; Strain muestra margen restante, minutos semanales y tiempo en Z4-Z5; Energy traduce Recovery/Sleep/Strain a una recomendacion de ritmo. Todas las razones aparecen en pantalla y se calculan localmente en `InsightEngine`.
- Perfil local, horario de despertar, meta de sueno, briefing matutino y recordatorio de cama mediante notificaciones locales.
- Edicion y borrado de comidas, limpieza del Journal y borrado completo de datos SwiftData desde Ajustes.
- Targets `RecvelTests` y `RecvelUITests`: motores deterministas, missingness, outliers, zonas cardiacas, deuda de sueno, onboarding, estado vacio y recorridos principales.

Los scores siguen siendo estimaciones de wellness y necesitan validacion antes de claims de produccion. La UI muestra explicitamente si usa Apple Health, datos parciales o modo demo.

### P0 completado en simulador

El nucleo P0 que no requiere sensores fisicos esta implementado: queries y normalizacion, fuentes, estados vacio/parcial/baseline, Recovery/Strain/Sleep/Energy explicables, detalle real de sueno y workouts, persistencia editable, recordatorios locales y pruebas deterministas. Queda para dispositivo real validar autorizacion granular, calidad de muestras de Apple Watch, zonas durante workouts reales, consumo de bateria y entrega de notificaciones con horarios reales. El companion watchOS continua fuera de este bloque.

### Direccion visual vigente

La direccion actual combina la densidad analitica de Bevel con la identidad semantica de Recvel: fondo casi neutro, superficies oscuras translucidas, hairlines sutiles, radio de 8 puntos, color reservado para estados y numeros protagonistas. Today incorpora un selector real de siete dias, Recovery como hero animado, tres instrumentos circulares compactos, plan de sueno/carga, activacion de 24 h, factores contra baseline y una accion del dia. No volver al grid 2x2 ni a fondos con gradientes dominantes.

Las detail views usan un hero circular sin card, color semantico por dominio, glass de radio contenido, charts con rango personal, fuente/calidad y cautelas de wellness. No reconstruir un hipnograma si HealthKit solo aporta agregados ni mostrar una curva intradia de Energy sin muestras temporales reales.

### Base cientifica de las recomendaciones accionables

- El plan de Sleep nunca presenta una hora como necesidad clinica. Parte de la preferencia del usuario, garantiza al menos siete horas de oportunidad, incorpora parcialmente la brecha media reciente y suma la latencia observada. El umbral general de siete horas sigue el consenso AASM/SRS para adultos: [Watson et al., 2015](https://aasm.org/resources/pdf/adultsleepdurationconsensus.pdf).
- En Plan / Metas, la hora de cama se alinea de forma opcional a ciclos NREM-REM (~90 min de promedio adulto; rango tipico ~70-120 min; cifras tipo ~1.45 h = 87 min caen en esa variacion). Se elige el conteo (4/5/6) mas cercano a la necesidad u oportunidad del motor y se suma un buffer corto para dormirte (~15 min, latencia tipica ~10-20 min; en el detalle de Sleep se usa la latencia observada cuando existe). Es una heuristica de planificacion para reducir inercia al despertar a mitad de ciclo, no un diagnostico ni un reloj biologico fijo: [Sleep Foundation — stages](https://www.sleepfoundation.org/stages-of-sleep), [NCBI — sleep stages](https://www.ncbi.nlm.nih.gov/books/NBK526132/).
- La rutina previa al sueno en Plan sigue higiene tipica de wind-down (30-60 min: bajar pantallas, lectura, bano, estiramientos ligeros, respiracion), inspirada en guias de bienestar tipo [WHOOP nightly routine](https://www.whoop.com/us/en/thelocker/13-tips-to-create-a-nightly-routine-to-sleep-better/) y [Bevel sleep hygiene](https://www.bevel.health/blog/prioritizing-sleep-hygiene). Los recordatorios son locales, opcionales y limitados (rutina / en cama / luces), no clinicos.
- La regularidad de inicio y fin de sueno se trata como senal propia, no como decoracion. Un panel de consenso encontro que la consistencia importa para salud, seguridad y rendimiento: [Sletten et al., 2023](https://pubmed.ncbi.nlm.nih.gov/37684151/).
- El corte de cafeina se muestra solo para una dosis grande y aclara variabilidad individual. La referencia es un estudio con 400 mg que observo alteracion incluso seis horas antes de dormir: [Drake et al., 2013](https://pubmed.ncbi.nlm.nih.gov/24235903/).
- Recovery usa HRV como tendencia contra baseline junto con FC, sueno y respiracion; una lectura aislada no decide el consejo. La adaptacion de entrenamiento guiada por HRV tiene evidencia prometedora, pero depende de mediciones repetidas y contexto: [Duking et al., 2021](https://pubmed.ncbi.nlm.nih.gov/34489178/).
- Strain muestra minutos semanales para favorecer distribucion y contexto. No convierte el objetivo poblacional en una cuota diaria; la referencia general de actividad para adultos es 150-300 min moderados o 75-150 vigorosos por semana: [OMS, 2020](https://iris.who.int/bitstream/handle/10665/336656/9789240015128-eng.pdf?sequence=1).

Las formulas de oportunidad de sueno, margen de Strain y Energy son heuristicas de producto propias, deterministas y probadas; no son algoritmos clinicamente validados ni replicas de Bevel/WHOOP.

La navegacion principal vuelve a ser una capsula flotante. Con Xcode 26+ utiliza `GlassEffectContainer` y estilos `glass` nativos de iOS 26; Xcode 16.4 conserva un fallback visual equivalente para que iOS 17/18 sigan compilando.

La capsula exterior de la barra inferior siempre conserva material Liquid Glass; el tab activo vive dentro como una segunda superficie interactiva. Las detail views usan controles flotantes individuales: boton Atras circular y titulo semantico en capsula tintada, sin una banda opaca de navigation bar. En iOS 26 estos controles usan `glassEffect`; en iOS 17/18 el fallback combina material real, translucidez, highlight especular y hairline.

Las acciones breves deben usar `Menu` nativo anclado a un control con `platformGlass`, iconos SF Symbols y orden estable. Ajustes, editores y destinos con contenido propio se abren mediante push dentro de `NavigationStack`; no usar sheets como sustituto de navegacion. Reservar las presentaciones modales para tareas temporales que realmente bloqueen el contexto actual.

La tipografia base es SF Pro sin variante redondeada para titulos, etiquetas y lectura larga. SF Rounded o digitos monoespaciados se reservan para scores, tiempos y valores instrumentales. Las transiciones de seleccion, anillos y charts usan animaciones breves con spring/ease-out y siempre respetan Reduce Motion.

El nuevo tema de producto se activa mediante `recvelVisualStyle = .product` exclusivamente desde `ContentView`. Onboarding conserva su tema, composición, materiales y cinco pasos; no aplicar el tema Bevel/Recvel dentro de `OnboardingView`.

## Funciones ampliadas por investigacion de mercado (2026)

Investigacion de competidores (detalle completo en [COMPETITORS.md](COMPETITORS.md); gap Bevel Pro vs Recvel en [BEVEL_PRO_GAP_ANALYSIS.md](BEVEL_PRO_GAP_ANALYSIS.md)) sugiere ampliar el backlog de producto mas alla de Recovery/Strain/Sleep/Energy con estos conceptos, siempre con nombres, copy y algoritmos propios:

- **Resumen unico tipo "Energy Bank" / body battery:** una lectura continua que combina recovery, sueno, strain y estres del dia en una sola cifra que sube y baja (patron de Bevel Energy Bank, Garmin Body Battery, Amazfit BioCharge). Util como version simplificada del dashboard para quien no quiere leer 4 scores.
- **Edad biologica opcional:** varios competidores (Bevel "Biological Age", WHOOP "WHOOP Age"/"Pace of Aging") recalculan semanalmente una edad estimada a partir de sueno, actividad, FC en reposo y (opcional) datos manuales. Si se implementa, debe quedar claro que es una estimacion de bienestar, no una medicion clinica, y debe ser opt-in. Detalle cientifico (PhenoAge vs wearable clocks) y plan de implementacion: [README_StressAndBio.md](README_StressAndBio.md).
- **Journal con correlaciones personales:** registro diario de habitos (cafeina, alcohol, meditacion, sintomas) correlacionado contra Recovery/HRV/sueno, al estilo WHOOP Journal. Comunicar siempre como asociacion personal, nunca causalidad.
- **Ciclo menstrual y su relacion con HRV/sueno:** Bevel y WHOOP (Women's Hormonal Insights) cruzan fase del ciclo con recovery y sueno. HealthKit ya expone datos de ciclo con autorizacion.
- **Coach conversacional on-device:** WHOOP Coach y Bevel Intelligence usan modelos de lenguaje (WHOOP Coach corre sobre modelos de OpenAI) para responder preguntas sobre por que cambio un score. En Recvel esto debe resolverse con reglas + modelos locales (Core ML / Apple Intelligence si esta disponible), sin enviar datos de salud a servicios externos.
- **Snapshot bajo demanda:** patron "Garmin Health Snapshot" (medicion corta de 2 minutos que resume FC, HRV, SpO2, respiracion) es facil de replicar con HealthKit + un cronometro en la app, sin hardware adicional.
- **Resumen matutino ("Morning Report"):** notificacion/pantalla que agrupa Recovery, sueno y recomendacion del dia apenas se despierta la persona.
- **Entrenamiento de fuerza estructurado:** Bevel Strength Builder sugiere que un modulo de fuerza (ejercicios, series, sincronizacion con Apple Watch) es un diferenciador esperado, no solo cardio/strain.
- **Predictor de ritmo/carrera y tendencia de VO2 max:** Recvel ya consulta y muestra VO2 desde HealthKit con fecha y tendencia. Race Predictor sigue pendiente y no debe construirse hasta validar suficiente historial y tipo de actividad. Validaciones Apple Watch reportan errores relevantes vs laboratorio; ver [README_StressAndBio.md](README_StressAndBio.md).
- **Widgets y Live Activities:** todos los competidores relevantes ofrecen widgets de iOS/watch y, en el caso de Bevel, Live Activities/Dynamic Island. Recomendado para v1 dado que no hay backend ni push propio.
- **Nutricion por foto, texto y codigo de barras con confirmacion editable:** ver seccion de Nutricion con IA abajo y el detalle en COMPETITORS.md; es el patron comun a Bevel, Amazfit/Zepp (que usa GPT-4o para vision) y apps como Cal AI/MyFitnessPal Meal Scan. El paso de confirmacion/edicion de porcion es universal y obligatorio, no opcional.

## Sugerencias Grok

Prioridades para acercar Recvel a "mejor app del mercado" sin romper local-first ni uso personal. Ordenadas por impacto diario / esfuerzo. No priorizar: multi-wearable cloud, paywall, backend, bloodwork clinico ni calorias exactas desde foto sola.

### P0 — Habito diario y confianza nutricional

- [ ] **Widgets Home Screen / Lock Screen** con Recovery, Strain y Sleep glanceables (loop de 10 s que Athlytic/Bevel ganan hoy).
- [ ] **Morning Report rico:** notificacion o pantalla al despertar con Recovery, sueno, accion del dia y margen de Strain (ampliar las notifs locales basicas ya existentes).
- [ ] **Food-101 Core ML** en lugar del clasificador Vision generico (candidatos Apache/MIT ya verificados en `Calorie_AI_Research.md`).
- [ ] **Reglas de seguridad clinica 12.10** en nutricion: screening tipo SCOFF/EAT-26, disclaimers de no uso clinico, sin streaks punitivos ni rojo/verde de exito/fracaso en deficit.
- [ ] **Validacion en Apple Watch real:** autorizacion granular, zonas en workouts, bateria y entrega de notificaciones.

### P1 — Scores memorables, aprendizaje y coaching local

- [ ] **Bateria de energia continua** (nombre propio Recvel): una cifra que sube/baja en el dia a partir de Recovery, sueno, Strain y activacion; simplifica el dashboard frente a 4 scores.
- [ ] **Journal mas rico:** hidratacion/agua como meta, cafeina con hora, alcohol con cantidad; correlacion ayuno ↔ Recovery/HRV (diferenciador local-first que nadie hace bien con nutricion incluida).
- [ ] **Coach Q&A local** con reglas + Foundation Models / parser on-device sobre factores ya calculados ("por que bajo Recovery"), sin enviar datos de salud a la nube.
- [ ] **Fuentes cientificas citadas en la UI** de insights (hoy viven en docs; deben aparecer junto a la recomendacion).
- [ ] **Export CSV / respaldo** de comidas, journal y scores (privacidad del usuario, sin backend).

### P2 — Paridad de mercado (despues del nucleo diario)

- [ ] **App companion watchOS** + complicaciones (workouts, FC en vivo, resumen de scores).
- [ ] **Live Activities / Dynamic Island** para ayuno activo o workout en curso.
- [x] **Bio Age trazable por lentes** (FRIEND cardiorrespiratorio + PhenoAge cuando hay panel completo; factores de contexto sin pesos propietarios).
- [ ] **Ciclo menstrual × HRV/sueno** desde HealthKit con autorizacion y lenguaje no alarmista.
- [ ] **Strength builder** estructurado (series × reps × peso locales; sincronizacion Watch cuando exista companion).
- [ ] **Snapshot bajo demanda** (~2 min: FC, HRV, SpO2, respiracion) al estilo Health Snapshot.
- [ ] **Smart alarm / haptic bedtime** tras validar restricciones de watchOS y bateria.
- [x] **VO2 max con protagonismo UI** (query, fecha, tendencia y detalle). SpO2 sigue autorizado sin load/UI.
- [x] **Seccion Home Stress** (bandas Excelente/Normal/Atencion/Sobrecarga desde HRV SDNN + RHR vs baseline).
- [x] **Bio Age explicable** (FRIEND o PhenoAge con nueve labs recientes; nunca se mezclan).

### Roadmap sugerido (personal → competitiva)

1. **Ahora:** widgets + Lock Screen, Food-101 + reglas 12.10, Morning Report rico, agua/cafeina con hora en Journal, validacion en dispositivo real.
2. **Despues:** bateria de energia unificada, coach local Q&A, correlacion ayuno↔Recovery, citas cientificas en UI, export/backup.
3. **Mas adelante:** watchOS companion, edad biologica opt-in, ciclo menstrual, strength builder, Live Activities.

Posicionamiento objetivo: *la app de readiness + nutricion + ayuno mas privada del ecosistema Apple Watch* — scores explicables, confirmacion humana en calorias, sin cuenta ni suscripcion. Compite con Athlytic en claridad, con Bevel en amplitud, y gana en privacidad/honestidad de confianza.

## Nutricion adaptativa implementada

Nutricion tiene setup propio despues del onboarding y permanece local por defecto. `NutritionProfile` alimenta rangos personales de kcal/macros; `NutritionPlanEngine` genera el estado del dia, la siguiente mejor comida y un plan simple para mañana usando comidas registradas y, cuando existen, scores locales de recovery/sleep/strain. Las entradas disponibles son texto, dictado, foto local y barcode desde imagen con Open Food Facts. Toda estimacion muestra rango, confianza e incertidumbres y pasa por porcion/correcciones antes de guardarse.

Gemini es un experimento opt-in para uso personal: inicia apagado, requiere API key en Keychain y consentimiento por envio. No es parte del camino de produccion local-first. Detalle tecnico y limites en [Calorie_AI_Research.md](Calorie_AI_Research.md).

Referencia cercana de arquitectura: **Athlytic** logra una suite completa de Recovery, Exertion, Sleep y Energy usando solo sensores de Apple Watch, sin hardware propio ni backend — es el competidor mas parecido a las restricciones tecnicas de Recvel y vale la pena revisarlo con frecuencia.

## Referencias visuales internas

La carpeta del proyecto incluye dos grabaciones de referencia (`video.mp4`, `video2.mp4`) usadas solo como inspiracion interna de layout y sensacion visual, no como assets a copiar:

- **video.mp4** (estilo WHOOP): header con racha/streak, selector "Today" con flechas, tres anillos grandes (Sleep naranja, Recovery verde, Strain azul) con porcentaje o numero al centro; tarjetas 2x2 debajo (rango de metricas, monitor de estres, pasos, FC) con icono + valor actual + valor de referencia; medidor tipo velocimetro semicircular con aguja para el monitor de estres (0 a 3, zonas Low/Medium/High) y grafica de linea de 24 h coloreada por zona debajo; tarjetas de comparacion "hoy vs. tipico" con barras horizontales apiladas; tendencias semanales en barras (Recovery) y lineas con puntos (HRV) por dia de la semana; barra inferior de tabs con icono circular de perfil resaltado en verde.
- **video2.mp4** (estilo Bevel): pantalla "Hello [nombre], Welcome back!" con selector de dias en pastillas (Sun 17 ... Thu 21); tarjeta grande "Calorie Burn" con slider degradado azul-verde-naranja-rojo y marcador circular con icono de fuego; tarjetas pequenas lado a lado para Sleep (barras tipo ecualizador) y Heart Rate (barra de rango con min/max); tarjeta de peso con grafica de linea y "ideal weight"; tarjetas flotantes superpuestas (efecto "bento" desordenado) para dona de macros (Protein/Carbs/Fats con anillos concentricos), arco de puntos para agua ("Today Water", 78%, meta en ml) y notificaciones tipo toast ("Great Progress!", "Workout Tip"); bottom tab bar con 4 iconos: Home, Activity, Nutrition, Coach.

Estas referencias confirman el pedido de un look **glassmorphism oscuro, con acentos de color semantico por metrica, medidores circulares/semicirculares grandes como elemento hero, tarjetas con datos "hoy vs. referencia" y una barra inferior de navegacion simple**. El sistema visual en `GlassComponents.swift` ya implementa la primera iteracion de este lenguaje: tarjetas de vidrio con radio 24, borde degradado y sombra de profundidad; anillos hero de cuadrado redondeado (`HeroScoreRing`) para Sleep/Recovery/Strain con animacion de entrada; gauge semicircular (`ArcGauge`) para Energia; y tarjetas de metrica "actual vs. tipico" (`MetricCard`) alimentadas por la mediana del `BaselineEngine`. Pendientes de proximas iteraciones: tarjetas flotantes estilo bento, graficas de 24 h coloreadas por zona y barras de comparacion apiladas.
