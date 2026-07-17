# Contexto para IAs y agentes

Este archivo es el contrato operativo del proyecto Recvel. Debe leerse antes de proponer o implementar cambios y actualizarse cuando una decision de producto o arquitectura cambie.

## Objetivo

Construir una app iOS y watchOS premium de bienestar que use Apple Health y Apple Watch para explicar recuperacion, carga, sueno, estres, energia, actividad y nutricion. Debe sentirse como un producto moderno de alto nivel, inspirado en la claridad de Bevel y WHOOP, pero con identidad visual, textos y algoritmos propios.

## Restricciones cerradas

- SwiftUI nativo con iOS 17+.
- SwiftData local; sin backend, cuenta o sincronizacion propia en v1.
- Sin analytics externos ni venta de datos de salud.
- Sin premium en la etapa inicial.
- IA on-device mediante frameworks Apple y modelos locales.
- HealthKit es la fuente principal y siempre requiere consentimiento granular.
- El producto es wellness/informativo, no diagnostico ni tratamiento medico.
- Todo resultado nutricional por IA requiere revision del usuario.
- Cada entrega de codigo debe compilar. No entregar cambios conocidos como rotos.
- Para compilaciones y UITests, usar siempre el simulador `iPhone 16 Pro` con `iOS 18.6` ya existente en la Mac. No crear simuladores nuevos ni runtimes adicionales salvo que el usuario lo pida expresamente.

## Arquitectura

- `HealthDataProvider`: autorizacion, consultas, observacion y normalizacion de HealthKit.
- `BaselineEngine`: ventanas personales, medianas, dispersion, outliers y suficiencia de datos.
- `ScoreEngine`: calculos versionados y deterministas.
- `NutritionEstimator`: entrada de texto, voz o imagen y propuestas editables.
- `InsightEngine`: explicaciones y recomendaciones basadas en reglas o modelos locales.
- `JournalAutoEntryEngine` / `JournalProImpactEngine`: tags medidos, dia wake-to-wake y asociaciones Recovery/Sleep.
- `BiomarkerProvider` / `BioAgeReportEngine`: lecturas, frescura, factores de 28/60 dias y seleccion de lente.
- `PhenoAgeEngine`: formula publicada estricta; no cambiar coeficientes, unidades ni imputar analitos.
- `LocalStore`: modelos SwiftData, migraciones y politica de retencion.
- `Views`: presentacion SwiftUI sin calculos fisiologicos.

No introducir servicios de red, SDKs de terceros, telemetria o almacenamiento cloud sin una decision explicita de producto y revision de privacidad.

### Contratos de Journal y Bio Age

- Journal sensible siempre empieza desactivado. Ausencia de respuesta no equivale a `No`.
- El limite wake-to-wake usa `wakeMinutes`; no volver a agrupar eventos nocturnos por medianoche.
- Insights requiere 5 `Si` y 5 `No` y debe decir asociacion, nunca causalidad.
- Bio Age tiene dos lentes: FRIEND y PhenoAge. Nunca crear un promedio ni asignar anos a sueno, pasos, fuerza o nutricion.
- PhenoAge solo aparece con los nueve analitos, unidades convertibles, edad >=18 y antiguedad menor a seis meses.
- Clinical Records se pide desde una accion explicita dentro de Bio Age, nunca en onboarding ni junto con permisos generales.
- La UI debe conservar el medio aro, fecha, metodo, confianza, factores con estado/fuente y detalle de biomarcador. No reemplazarla por cards KPI genericas.

## Reglas de datos

1. Pedir permisos cuando la funcion los necesite y explicar el beneficio.
2. Funcionar con cero datos, datos parciales, datos retrasados y permisos revocados.
3. Mantener origen, fecha, unidad y calidad de cada muestra relevante.
4. No tratar ausencia de datos como cero.
5. Preferir baselines personales robustos a limites poblacionales genericos.
6. Mostrar confianza baja hasta reunir historial suficiente.
7. Evitar doble conteo de muestras agregadas por multiples dispositivos.
8. No escribir en HealthKit sin una accion clara y consentimiento del usuario.

## Scores

Los scores de la primera etapa son prototipos. Antes de produccion deben tener especificacion versionada, fixtures, sensibilidad a outliers, manejo de missingness y revision de claims.

- **Recovery:** HRV, FC en reposo, sueno, respiracion y carga reciente contra baseline.
- **Strain:** duracion e intensidad cardiovascular, zonas de FC, energia activa y workouts.
- **Sleep:** duracion, eficiencia, regularidad, deuda y etapas con peso prudente.
- **Energy/Stress:** indicadores derivados con confianza explicita; no usar lenguaje de diagnostico.

Cada detalle de score debe responder: valor actual, baseline, direccion, factores positivos/negativos, datos faltantes, confianza y una accion razonable.

## Nutricion

El pipeline deseado es:

```text
Foto / texto / voz
        |
        v
Deteccion local de candidatos
        |
        v
Base nutricional local + porcion estimada
        |
        v
Formulario editable con rango y confianza
        |
        v
Confirmacion -> SwiftData -> HealthKit opcional
```

No afirmar que una imagen determina calorias exactas. Pedir escala, cantidad o descripcion cuando mejore la estimacion. Conservar la foto solo si la persona lo elige.

### Decision de modelos locales para nutricion

**Fuente de verdad:** la investigacion y decision vigente vive en [Calorie_AI_Research.md](Calorie_AI_Research.md). Ese documento reemplaza cualquier conclusion previa sobre Food-101, VLMs, SDKs comerciales o Foundation Models.

Restricciones actuales para v1:

- No fine-tuning propio.
- No pagar licencias, suscripciones, royalties, tokens, APIs cloud ni SDKs comerciales.
- Usar solo modelos open source/open weights permisivos, datos abiertos o APIs de plataforma incluidas en iOS.
- El feature debe funcionar sin Foundation Models porque no es open source; puede quedar como experimento opcional, no como core.
- Passio, OpenAI, Anthropic, Google Cloud, Apple FastVLM y Qwen2.5-VL-3B quedan bloqueados para v1 por costo, cloud o licencia.

- **Fuente numerica principal:** base nutricional local. Priorizar USDA FoodData Central/FNDDS para alimentos genericos, Open Food Facts para empaquetados y una tabla curada propia para alimentos comunes en Mexico/LatAm.
- **Foto:** SmolVLM/Moondream u otro VLM permisivo como asistente visual local; no usarlo como oraculo final de calorias.
- **Multi-comida:** si se agrega segmentacion off-the-shelf, usarla como ayuda de edicion, no como verdad de ingredientes.
- **Porcion:** pedir gramos, unidades caseras o confirmacion de porcion. Si hay LiDAR/depth o referencia visible, puede mejorar el rango, pero la app debe funcionar sin ello y conservar baja confianza cuando falte escala.
- **Texto/voz:** parser local/reglas primero; si hace falta un modelo, debe ser open weights permisivo y pequeno.
- **Barcode/OCR:** tratarlo como el camino de mayor confianza para empaquetados: Vision para codigo de barras y texto de etiqueta, mapeo local a producto/nutrientes, edicion humana.

Niveles de confianza obligatorios:

- Alta: barcode/etiqueta/gramos confirmados o alimento ya guardado por el usuario.
- Media: texto con cantidades claras o foto de alimento simple con porcion confirmada.
- Baja: foto sin escala, plato mixto, salsas/aceites ocultos, bowls, comida parcialmente oculta o multiples preparaciones.

Modelos/datasets utiles para evaluacion, no para entrenar ni prometer exactitud:

- SmolVLM-256M-Instruct: VLM pequeno, Apache 2.0, imagen+texto, pensado para inferencia ligera. Candidato principal de experimento local.
- Moondream2: VLM pequeno, Apache 2.0, buena opcion si el runtime iOS queda mas simple/rapido.
- Food-101: dataset publico de 101 categorias y 101,000 imagenes; util solo como benchmark de cobertura visual, limitado para porcion y cocina local.
- Nutrition5k: dataset de Google con ~5,000 platos, RGB-D cuando existe, masas, calorias y macros; util para prototipos de regresion y pruebas, pero sesgado a cafeterias especificas y muy pesado para empaquetar.
- FoodSeg103/FoodSAM y derivados: utiles para estudiar segmentacion de componentes, pero no resuelven volumen, metodo de coccion, ingredientes ocultos o aceite.

Regla para UI/copy: decir "estimamos", "rango", "confianza" y "ajusta la porcion"; evitar "detectamos exactamente", "calorias certeras" o guardar sin revision.

## Sistema visual

- Dark-first con contraste suficiente y soporte Dynamic Type.
- Glassmorphism con materiales reales, bordes sutiles y profundidad; el contenido siempre gana al efecto.
- Acentos semanticos diferenciados: recovery, strain, sleep, energy y nutrition no deben ser variaciones de un solo color.
- Cards con radio contenido, graficas densas y microinteracciones suaves.
- Respetar Reduce Motion, Reduce Transparency y VoiceOver.
- Usar `Menu` nativo anclado a controles `platformGlass` para acciones contextuales; no recrear menus con sheets o overlays manuales.
- Mantener una capsula Liquid Glass exterior alrededor de toda la barra inferior, ademas del estado de seleccion interactivo. `GlassEffectContainer` por si solo no dibuja esa superficie.
- En details, usar boton Atras circular y titulo con icono en capsula `platformGlass`; evitar una franja opaca ocupando toda la navigation bar.
- Abrir Ajustes, editores y pantallas de detalle con push dentro de `NavigationStack`. Reservar sheets para tareas temporales que deban interrumpir el contexto.
- Usar SF Pro estandar en titulos y texto. Reservar SF Rounded o digitos monoespaciados para scores, tiempos y valores instrumentales.
- Animar seleccion, progreso de anillos y aparicion de charts con transiciones breves, cancelables y compatibles con Reduce Motion.
- Usar SF Symbols para iconos y evitar SVGs manuales cuando exista un simbolo apropiado.
- No copiar layouts pixel a pixel, assets, nombres o copy de competidores.
- Verificar iPhone pequeno y grande, orientacion prevista, textos largos y estados vacios.

## Lenguaje y seguridad

Usar frases como "tendencia", "estimacion", "podria asociarse" y "considera". Evitar "tienes", "detectamos enfermedad", "garantiza" o recomendaciones clinicas. Ante datos inusuales, explicar limites y sugerir consultar a un profesional si existen sintomas o preocupacion.

No generar alertas de emergencia a partir de scores propietarios. Las funciones clinicas autorizadas de Apple deben conservar su contexto original.

## Evidencia

- Priorizar revisiones sistematicas, consensos y documentacion oficial.
- Registrar cita, poblacion, dispositivo, protocolo, outcome y limitaciones.
- No convertir una correlacion de grupo en causalidad individual.
- No extrapolar resultados de ECG clinico a PPG de muneca sin validacion.
- Tratar etapas de sueno y calorias como estimaciones con error.
- Revisar actualidad de cada fuente antes de implementar claims.

Fuentes iniciales se mantienen en [COMPETITORS.md](COMPETITORS.md). Wikipedia y notas editoriales son mapas de descubrimiento, no evidencia final para claims de produccion.

## Evidencia cientifica ampliada (revisiones y meta-analisis, julio 2026)

Investigacion dirigida a PubMed/PMC y sociedades oficiales para respaldar honestamente cada score y feature. Por tema: que esta bien respaldado, que es controversial/incierto, y una frase de cautela sugerida para UI/copy.

### HRV como marcador de recovery

- Bien respaldado: RMSSD es la metrica de HRV a corto plazo preferida para monitoreo autonomico; mediciones casi diarias con promedio movil (p. ej. 7 dias, media +/- 0.5 DE, metodo Plews/Buchheit) superan una lectura aislada. Entrenamiento guiado por HRV mejora adaptaciones submaximas en meta-analisis, con efecto pequeno en VO2 max/rendimiento. La HRV nocturna parece mas sensible a cambios de carga que una lectura matutina puntual.
- Validacion PPG de muneca vs. ECG: HRV/FC de WHOOP (PPG) valida contra ECG dentro de margenes aceptables en condiciones controladas y quietas; la precision se degrada con movimiento.
- Confusores documentados: postura, hora del dia, respiracion, alcohol (suprime HRV nocturna y eleva FC sin alterar necesariamente la arquitectura del sueno), enfermedad (HRV cae 1-3 dias antes de sintomas), edad y sexo (rangos "normales" fijos no aplican igual a todos).
- Controversial: si el entrenamiento guiado por HRV mejora *rendimiento* real (no solo fisiologia submaxima) es evidencia mixta/efecto pequeno; la interpretacion LF/HF como "balance simpatovagal" se considera hoy una sobresimplificacion cientificamente debil.
- Frase de cautela sugerida: "El score de Recovery usa tu HRV nocturna (sensor optico de Apple Watch) respecto a tu propio baseline. La HRV se ve afectada por alcohol, enfermedad, mal sueno, estres e incluso el movimiento durante la medicion, asi que las variaciones diarias son tendencias informativas, no mediciones de laboratorio, y no son un diagnostico."
- Fuentes clave: [Plews et al., Sports Medicine 2013](https://pubmed.ncbi.nlm.nih.gov/23852425/) · [Meta-analisis HRV y VO2max](https://pmc.ncbi.nlm.nih.gov/articles/PMC7663087/) · [Nuuttila et al., IJSPP 2022 — HRV nocturna](https://journals.humankinetics.com/view/journals/ijspp/17/8/article-p1296.xml) · [Validacion PPG WHOOP vs ECG, Sensors 2021](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8160717/) · [Alcohol y HRV nocturna](https://pmc.ncbi.nlm.nih.gov/articles/PMC5878366/) · [Limites de HRV como herramienta autonomica, Frontiers 2026](https://pmc.ncbi.nlm.nih.gov/articles/PMC12883400/)

### FC en reposo y recuperacion de FC (HRR)

- Bien respaldado: FC en reposo baja se asocia a menor mortalidad por todas las causas y cardiovascular; validada como biomarcador poblacional de aptitud cardiorrespiratoria (Fenland Study, ~12,000 adultos). La recuperacion de FC tras ejercicio (caida en el primer minuto) predice mortalidad de forma independiente en varias cohortes.
- Limite: son asociaciones epidemiologicas poblacionales, no validadas como indicador sensible dia a dia de "estado de recuperacion" con el mismo rigor que la HRV en ciencia del deporte.
- Frase de cautela sugerida: "Una FC en reposo mas alta que tu rango habitual puede reflejar mala recuperacion, deshidratacion, enfermedad, calor o alcohol — es una senal de tendencia util, no una medicion clinica."
- Fuentes: [FC en reposo y mortalidad](https://pubmed.ncbi.nlm.nih.gov/24290115/) · [Fenland Study — FC en reposo como biomarcador](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10174582/) · [Recuperacion de FC como predictor de mortalidad](https://pubmed.ncbi.nlm.nih.gov/10536127/)

### Sueno en wearables (incluye Apple Watch)

- Bien respaldado: la deteccion sueno/vigilia es solida en la mayoria de dispositivos (sensibilidad >=95%). La clasificacion de etapas (ligero/profundo/REM) es notablemente menos precisa; un estudio multicentrico con 349,114 epocas y 11 dispositivos encontro variacion sustancial entre marcas. Comparativa especifica Oura/Fitbit/Apple Watch: Apple Watch tuvo la mayor sensibilidad de REM (~68.6%) pero tiende a **sobreestimar sueno ligero y profundo**.
- Guia oficial: la AASM (2018) declara que las tecnologias de sueno de consumo no son grado clinico y deberian cumplir estandares FDA para uso clinico; utiles como herramientas complementarias, no diagnosticas.
- Frase de cautela sugerida: "Las etapas de sueno (ligero/profundo/REM) son estimaciones de Apple Watch/HealthKit basadas en movimiento y FC, no polisomnografia clinica. Son razonablemente precisas para duracion total y horario, pero los porcentajes de cada etapa pueden estar sobre o subestimados. Recvel no diagnostica trastornos del sueno."
- Fuentes: [Meta-analisis: wearables vs. polisomnografia](https://pubmed.ncbi.nlm.nih.gov/39484805/) · [Validacion de 11 dispositivos, estudio multicentrico](https://pmc.ncbi.nlm.nih.gov/articles/PMC10654909/) · [Comparativa Oura/Fitbit/Apple Watch](https://pmc.ncbi.nlm.nih.gov/articles/PMC11511193/) · [Postura AASM 2018 sobre tecnologia de sueno de consumo](https://pmc.ncbi.nlm.nih.gov/articles/PMC5940440/)

### Regularidad y consistencia del sueno

- Bien respaldado: el Sleep Regularity Index (SRI) predice mortalidad por todas las causas mejor que la sola duracion del sueno en una cohorte de UK Biobank de 60,977 personas (~7.8 anos de seguimiento); mayor regularidad se asocio a 20-48% menor mortalidad total. Replicado en revision sistematica de 5 cohortes de bajo sesgo (20-88% mayor mortalidad en los menos regulares).
- Incierto: el mecanismo causal exacto (desalineacion circadiana vs. confusion por estilo de vida irregular) aun se investiga; el SRI es relativamente nuevo (~2020) comparado con metricas de duracion.
- Frase de cautela sugerida: "La evidencia sugiere que un horario de sueno consistente puede importar tanto o mas que la duracion total. Recvel muestra tu consistencia de sueno como una senal adicional de bienestar, no un diagnostico."
- Fuentes: [Windred et al., SLEEP 2024 — regularidad del sueno y mortalidad](https://pmc.ncbi.nlm.nih.gov/articles/PMC10782501/) · [Revision sistematica de regularidad del sueno](https://www.sciencedirect.com/science/article/abs/pii/S108707922500156X)

### VO2 max estimado por wearables

- Bien respaldado: el "Cardio Fitness" de Apple Watch, validado contra protocolo maximo de Astrand con calorimetria indirecta (n=30), mostro error porcentual absoluto medio de ~15.8%, con **sobreestimacion en personas de baja aptitud y subestimacion en personas muy aptas** (sesgo tipico de regresion a la media de algoritmos submaximos).
- Frase de cautela sugerida: "El VO2 max que muestra Recvel viene directo de la estimacion de Apple Health, basada en tu respuesta de FC durante caminatas/carreras, no una prueba de esfuerzo maxima de laboratorio. Los estudios de validacion muestran errores tipicos de 9-16%. Usalo como indicador de tendencia, no como valor de laboratorio."
- Fuentes: [Validacion de VO2 max de Apple Watch, PLOS ONE 2025](https://pmc.ncbi.nlm.nih.gov/articles/PMC12080799/) · [Validacion Apple Watch Series 7](https://biomedeng.jmir.org/2024/1/e59459)

### Strain / carga de entrenamiento (TRIMP, ACWR)

- Contexto: TRIMP (Banister) pondera la FC media de una sesion por duracion, pero colapsa esfuerzos de intensidad variable en un solo valor, lo que puede subestimar cargas de intervalos de alta intensidad.
- Importante para Strain de Recvel: el **ratio agudo:cronico (ACWR)**, popularizado por Gabbett para gestion de riesgo de lesion, tiene criticas metodologicas serias y crecientes desde 2018-2021 (acoplamiento matematico entre el numerador y el denominador, artefactos estadisticos con denominadores pequenos). Un reanalisis Bayesiano no encontro evidencia confiable de que manipular el ACWR prediga o prevenga lesiones.
- Frase de cautela sugerida: "El score de Strain de Recvel se inspira en conceptos establecidos de carga de entrenamiento (impulso de entrenamiento basado en FC) para mostrar que tan demandante fue tu dia o semana respecto a tu baseline reciente. Es una estimacion de carga, no una herramienta validada de prediccion de lesiones — la evidencia de ciencia del deporte encuentra que metricas de razon como el ACWR son estadisticamente fragiles para ese fin, y Recvel no hace afirmaciones sobre prevencion de lesiones."
- Fuentes: [Impellizzeri et al. — problemas conceptuales del ACWR, IJSPP 2020](https://journals.humankinetics.com/view/journals/ijspp/15/6/article-p907.xml) · [Revision sistematica ACWR y riesgo de lesion](https://pmc.ncbi.nlm.nih.gov/articles/PMC7047972/) · [Reanalisis Bayesiano del ACWR](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9572878/)

### Estres inferido desde HRV/FC

- Bien respaldado con cautela: la HRV puede ser un proxy valido y util del estres autonomico de corto plazo "cuando se usa con cuidado dentro de un diseno bien construido" — el marco constante en revisiones recientes, no un aval sin matices.
- Limite central: la HRV no distingue la *fuente* del estres autonomico — un entrenamiento duro, una discusion, cafeina, mal sueno y angustia psicologica real reducen la HRV de forma similar. La interpretacion LF/HF como "balance simpatovagal" se considera hoy sobreestimada por fisiologos autonomicos.
- Frase de cautela sugerida: "El indicador de Estres/Energia de Recvel se deriva de HRV, FC y senales autonomicas relacionadas. Estas senales reflejan activacion fisiologica general — que puede venir de ejercicio, mal sueno, enfermedad, cafeina o estres emocional por igual — y no distinguen la causa. Es una senal de autoconocimiento, no una medida clinica de estres, ansiedad o cualquier condicion de salud mental."
- Fuentes: [HRV como proxy de estres, Stress and Health 2025](https://pmc.ncbi.nlm.nih.gov/articles/PMC12647429/) · [Limites de HRV como herramienta autonomica, Frontiers 2026](https://pmc.ncbi.nlm.nih.gov/articles/PMC12883400/)

### Complemento julio 2026 — Stress dedicado, VO2 y Bio Age

Investigacion ampliada (PubMed/PMC + competidores StressWatch/Bevel/WHOOP) consolidada en **[README_StressAndBio.md](README_StressAndBio.md)**. Resumen operativo para agentes:

- **Stress Home:** bandas Excelente / Normal / Atencion / Sobrecarga desde HRV **SDNN** + RHR vs baseline personal (patron StressWatch). Apple no entrega RMSSD; documentarlo en UI.
- **Fuentes nuevas a citar si se toca Stress:** meta-analisis HRV estres/recuperacion en medicos [PMC12794872](https://pmc.ncbi.nlm.nih.gov/articles/PMC12794872/); biomarcador digital HRV [PMC12849089](https://pmc.ncbi.nlm.nih.gov/articles/PMC12849089/); guia ocupacional HR/HRV 2024 [s12995-024-00414-9](https://link.springer.com/article/10.1186/s12995-024-00414-9).
- **VO2:** auth HealthKit existe; **falta query**. Validacion Apple Watch: MAPE ~13–16%, subestimacion ~6 ml/kg/min ([PubMed 40373042](https://pubmed.ncbi.nlm.nih.gov/40373042/), [JMIR 2024](https://biomedeng.jmir.org/2024/1/e59459)).
- **Bio Age:** PhenoAge ya esta implementado como lente separada y solo se habilita con edad + los 9 labs publicados ([PLOS Med e1002718](https://journals.plos.org/plosmedicine/article?id=10.1371/journal.pmed.1002718)). La otra lente es **edad cardiorrespiratoria beta**, que interpola VO2 contra medianas FRIEND por edad/sexo. RHR, sueno y pasos dan contexto pero no alteran anos. No combinar lentes ni convertir asociaciones de wearables en pesos inventados.
- **Codigo hoy:** `HealthDataProvider` consulta VO2 discreto; `StressEngine` compara HRV SDNN/RHR con 30 dias; `BioAgeEngine` implementa referencia FRIEND; Home y detalles viven en `HealthIntelligenceViews.swift`.
- **Heuristica Stress v1:** los multiplicadores y cortes son parametros de producto, no una formula clinicamente validada ni una reproduccion de StressWatch/Bevel. Exigir 3 dias para score, ambas senales + 7 dias para confianza media y ambas + 21 para alta.

### Estimacion de calorias desde fotos

- Estado del arte: el reconocimiento de alimentos por deep learning ha avanzado mucho para *clasificar* el alimento; la estimacion de *porcion/volumen* y la calorimetria final siguen siendo la parte dificil y no resuelta del pipeline (oclusion, ingredientes ocultos, platos mixtos, estimacion de volumen desde una sola imagen monocular sin referencia de profundidad).
- Evidencia real: estudios piloto de apps comerciales de identificacion de alimentos por IA muestran divergencias relevantes frente a mediciones de referencia, especialmente en poblaciones con composiciones corporales distintas y en platos mixtos/con salsa.
- Consenso: la estimacion por imagen es un ejercicio de aproximacion incluso para nutriologos expertos evaluando fotos; es una limitacion estructural del enfoque (imagen 2D -> volumen 3D -> masa -> calorias), no solo una brecha de ingenieria que se cerrara pronto.
- Frase de cautela sugerida (ya alineada con el pipeline descrito arriba en este documento): "Las estimaciones de calorias y nutricion por foto o texto en Recvel usan IA y son aproximaciones. La precision es mayor en alimentos simples y unicos, y menor en platos mixtos, salsas o ingredientes ocultos (aceites, azucares) — el error puede superar el 20% en comidas complejas. Usalas para seguimiento de tendencia y conciencia general, no como sustituto de datos nutricionales precisos ni de orientacion dietetica profesional, en especial para personas con diabetes u otras condiciones que requieren conteo preciso."
- Fuentes: [Revision de reconocimiento de alimentos por deep learning, Applied Sciences 2025](https://www.mdpi.com/2076-3417/15/14/7626) · [Encuesta de estimacion de volumen de alimentos para evaluacion dietetica](https://arxiv.org/pdf/2106.11776) · [Validez piloto de app de IA para identificar alimentos y estimar energia](https://pmc.ncbi.nlm.nih.gov/articles/PMC10656219/) · [Validez limitada de app de IA en dietetica, npj Digital Medicine](https://www.nature.com/articles/s41746-026-02536-2)

### Guia oficial: wearables no son grado medico

- AASM (2018): tecnologias de sueno de consumo deberian cumplir estandares FDA antes de uso clinico. ACSM (tendencias mundiales 2026) advierte que "la innovacion rapida a menudo supera la validacion" y que los profesionales de ejercicio deben mantenerse informados sobre diferencias de precision entre dispositivos. Una revision "umbrella" viva (Sports Medicine 2024) resume que los wearables de consumo son utiles como herramientas de tendencia con precision variable por metrica, no instrumentos de grado medico.
- **Disclaimer global sugerido** (sintetiza todo lo anterior, coherente con la seccion "Lenguaje y seguridad" de este documento): "Recvel es una herramienta de bienestar y autoconocimiento, no un dispositivo medico. Sus scores de Recovery, Strain, Sleep y Estres/Energia se derivan de estimaciones de sensores de Apple Watch/HealthKit (HRV optica, FC, sueno por movimiento, frecuencia respiratoria) y conceptos generales de ciencia del deporte. Estas senales tienen margenes de error documentados y confusores conocidos (postura, hora del dia, alcohol, enfermedad, diferencias individuales de aptitud/edad/sexo, artefactos de movimiento). Recvel no diagnostica, trata ni predice ninguna condicion medica, lesion o enfermedad, y no sustituye una evaluacion medica, dietetica o de trastornos del sueno por un profesional licenciado."
- Fuentes: [Postura AASM 2018](https://pmc.ncbi.nlm.nih.gov/articles/PMC5940440/) · [ACSM — Tendencias mundiales de fitness 2026](https://acsm.org/top-fitness-trends-2026/) · [Revision umbrella de precision de wearables, Sports Medicine 2024](https://link.springer.com/article/10.1007/s40279-024-02077-2)

## Sistema visual — grabaciones de referencia internas

El proyecto incluye `video.mp4` y `video2.mp4` (raiz del repo) como referencia visual interna de layout, no como assets a copiar. Elementos observados que informan la evolucion del sistema visual (`GlassComponents.swift` y vistas relacionadas):

- **Medidor circular grande como elemento hero** (anillo de progreso con valor central grande, ej. "91% Recovery") y variante **semicircular tipo velocimetro con aguja** para escalas 0-3 (stress monitor), con zonas de color (gris/verde/naranja) marcadas sobre el arco.
- **Tarjetas "hoy vs. referencia"**: valor actual + valor de comparacion pequeno debajo, con icono a la izquierda y chevron a la derecha; grid 2x2 para metricas secundarias (pasos, FC, respiracion).
- **Graficas de linea de 24 horas coloreadas por segmento/zona** (ej. estres bajo en verde, alto en naranja) con iconos de contexto (luna para sueno, bicicleta para actividad) superpuestos en el eje temporal.
- **Barras de comparacion apiladas horizontales** ("hoy" arriba, "tipico" abajo) para comparar contra un dia de referencia similar.
- **Tendencias semanales**: barras verticales por dia (con etiqueta de valor arriba) y lineas con puntos marcados, eje X con dia+numero.
- **Tarjetas flotantes superpuestas estilo "bento" con leve rotacion/offset** (dona de macros con anillos concentricos, arco de puntos para agua con relleno progresivo, toasts de notificacion tipo "Great Progress!"/"Workout Tip") — util para marketing/onboarding mas que para el dashboard principal.
- **Slider horizontal degradado** (azul-verde-naranja-rojo) con marcador circular con icono, usado para una metrica acumulativa tipo "Calorie Burn".
- **Barra inferior de navegacion de 4-5 iconos**, uno de ellos resaltado con anillo de color de acento cuando esta activo.
- Ambas referencias son **dark-first** con blur/material real, no solo opacidad; los acentos de color son especificos por metrica (naranja=sueno, verde=recovery, azul=strain en una referencia; multicolor por metrica en la otra), consistente con la regla ya establecida de "acentos semanticos diferenciados" en la seccion de Sistema visual de este documento.
- Estado de implementacion: `ContentView` activa el tema `.product`, inspirado en la densidad de Bevel y combinado con color/animacion propios de Recvel; Onboarding queda deliberadamente fuera y no debe cambiar. `DashboardView` tiene selector funcional de siete dias, Recovery hero, tres instrumentos circulares y narrativa de briefing. `DetailViews.swift` usa heroes compactos, rangos personales, charts, fuente/calidad y cautelas. Sleep solo presenta composicion agregada cuando no existen intervalos fiables; Energy se declara estimacion diaria y no inventa una bateria intradia. La barra conserva Liquid Glass nativo en iOS 26 y fallback en iOS 17/18.

### Contrato de insights accionables

- `InsightEngine.sleepOpportunityPlan` combina meta elegida, promedio de siete dias, 50% de la brecha reciente (maximo una hora) y latencia de 10-45 min. Produce desconexion, cama, despertar y referencia de cafeina. La cama se redondea al conteo de ciclos (~90 min) mas cercano a esa oportunidad (`SleepCyclePlanner`); es heuristica propia, no una prediccion de necesidad biologica.
- `InsightEngine.briefing` conserva la necesidad/deuda por promedio y strain; la hora de cama del Plan usa el mismo planificador de ciclos (buffer tipico 15 min) y expone `suggestedSleepCycles` / caption para la UI de Metas.
- En Plan → Esta noche, el usuario puede activar recordatorios locales suaves (rutina / en cama / apagar luces) alineados a esa hora de cama por ciclos (`SleepWindDownScheduler` + `LocalNotificationManager.schedulePlanSleepReminders`), y definir una rutina previa (`SleepRoutineStep` en SwiftData) con presets tipicos de wind-down (sin pantallas, lectura, bano, estiramientos, respiracion). Maximo tres avisos al dia; no spamea cada paso.
- `recoveryAdvice` prioriza duracion menor a siete horas, luego varias desviaciones contra baseline y despues carga alta. Nunca atribuir HRV baja a una causa concreta.
- `strainAdvice` compara carga actual con un rango derivado de Recovery, muestra minutos semanales y Z4-Z5. No obliga a alcanzar el rango ni predice lesiones.
- `energyAdvice` solo traduce los scores disponibles a una decision de ritmo. No dibujar carga/descarga intradia hasta disponer de muestras temporales reales.
- Todo consejo debe mostrar sus razones en chips, el disclaimer de wellness y un identificador UI estable `detail.<dominio>.advice` o `detail.sleep.plan`.
- Fuentes de referencia: [AASM/SRS sobre 7+ horas](https://aasm.org/resources/pdf/adultsleepdurationconsensus.pdf), [consenso sobre regularidad](https://pubmed.ncbi.nlm.nih.gov/37684151/), [cafeina 0/3/6 h antes de dormir](https://pubmed.ncbi.nlm.nih.gov/24235903/), [revision de entrenamiento guiado por HRV](https://pubmed.ncbi.nlm.nih.gov/34489178/) y [guia OMS de actividad](https://iris.who.int/bitstream/handle/10665/336656/9789240015128-eng.pdf?sequence=1).

## Criterios de aceptacion

Antes de cerrar cualquier cambio de codigo:

- Compilar el esquema Recvel con `xcodebuild` para iOS Simulator.
- Ejecutar tests relevantes cuando existan.
- Probar sin datos, datos parciales y fixtures completos si se toca HealthKit o scores.
- Confirmar que no se agregaron secretos, red, analytics ni persistencia no autorizada.
- Revisar accesibilidad y overflow si se modifica UI.
- Actualizar README, este contexto y/o matriz competitiva si cambia una decision.
- Informar claramente cualquier prueba que no haya sido posible ejecutar.

## Estado del prototipo

El P0 verificable en simulador esta implementado. La app contiene queries HealthKit de 30 dias, incluida la ultima muestra discreta de VO2, eleccion de fuente y deduplicacion temporal, sueno real por etapas/eficiencia/latencia/consistencia/siestas, workouts con zonas de FC y carga cardiovascular, baselines robustos por mediana/MAD, scores deterministas, Stress fisiologico explicable, Bio Age FRIEND/PhenoAge por lentes, estados vacio/parcial/baseline y briefing local. Tambien incluye Plan, Journal Pro con impactos Recovery/Sleep, perfil y notificaciones locales.

Fitness ocupa la tab que antes usaba Tendencias. Su estructura toma como referencia `Bevel_ref_2.mp4`: calendario de 30 dias, actividad, Strain Performance, Cardio Load, Cardio Focus, Heart Rate Recovery, fuerza y plantillas. Los valores se construyen con `FitnessEngine`; los registros manuales y plantillas usan `FitnessActivityLog` y `WorkoutTemplate` en SwiftData. Tendencias permanece disponible como seccion navegable dentro de Home.

Reglas de integridad para Fitness: no inferir volumen de fuerza desde un workout generico; HRR requiere FC al terminar y una muestra entre 45 y 90 segundos despues; foco cardio requiere zonas; el fallback por duracion debe declararse como menor confianza. Los details deben conservar breakdown, periodo, explicacion y disclaimer, no reducirse a una grafica decorativa.

Nutricion incluye un setup post-onboarding separado, `NutritionProfile`, rangos kcal/macros, `NutritionPlanEngine`, siguiente comida, plan de mañana, texto, dictado, foto local, barcode con Open Food Facts, correcciones y reutilizacion del timeline. Vision general no estima volumen: sus resultados deben conservar confianza baja. Gemini es experimental, opt-in, apagado por defecto, con clave en Keychain y consentimiento por cada envio; nunca hacerlo automatico ni tratarlo como dependencia de produccion.

Los fixtures no son fallback de produccion: solo se habilitan explicitamente mediante `useDemoData` en previews y pruebas. Si HealthKit no entrega datos, debe permanecer el estado vacio y no se deben crear ni persistir scores sinteticos.

Pruebas vigentes:

- `RecvelTests`: outliers y medianas, determinismo de scores, missingness/confianza, bandas Stress, Bio Age con/sin inputs, zonas cardiovasculares, ventana/merge/foco/HRR de Fitness, deuda de sueno, targets nutricionales, cambios de plan y flag externo apagado.
- `RecvelUITests`: onboarding, briefing, Tendencias dentro de Home, detalles de Recovery/Sleep/Strain/Energy/Stress/VO2, tab Fitness, navegacion principal, setup nutricional, estimacion/correccion/guardado y estado HealthKit vacio.
- Validacion visual manual en `iPhone 16 Pro` con `iOS 18.6` para dashboard completo y estado sin datos. No usar otros simuladores por defecto.

Requiere dispositivo fisico: autorizacion granular real de HealthKit, comparacion de fuentes Apple Watch/iPhone, sesiones con FC en vivo, bateria y entrega de notificaciones en uso cotidiano. El companion watchOS se implementa y valida por separado.

Reglas adicionales para agentes desde julio de 2026:

- No reemplazar `HealthDataProvider.refresh()` por datos estaticos para simplificar previews.
- No mostrar impactos del Journal antes de 5 respuestas Si y 5 No unidas a scores del mismo dia.
- No volver a un dashboard generico de cards 2x2. Mantener la narrativa hero -> plan -> Stress -> VO2/Bio Age -> factores -> accion.
- No eliminar ni saltar el onboarding para usuarios nuevos. Mantener sus cinco pasos y `hasCompletedOnboarding`; los UI tests fuerzan este valor mediante launch arguments.
- No aplicar `recvelVisualStyle = .product` a `OnboardingView`; su diseño queda congelado salvo peticion explicita del usuario.
- La barra inferior debe conservar su capsula flotante. En SDK 26+ usar Liquid Glass nativo; mantener el fallback mientras iOS 17 siga soportado.
- No llamar "estres mental" a la curva de activacion basada en FC.
- No guardar una estimacion nutricional sin que la persona pueda ajustar porcion.
- No omitir rango, confianza ni incertidumbres de una estimacion nutricional.
- No enviar texto o foto a Gemini sin flag opt-in y confirmacion inmediata del usuario.
- Mantener `HealthDataMode` visible para diferenciar HealthKit, parcial y Demo.
- No volver a colocar Tendencias como tab principal sin una decision explicita; esta alojada en Home y Fitness usa esa posicion.
- No poblar el radar muscular con energia, minutos o suposiciones. Solo `totalVolumeKg` confirmado por el usuario.
- El siguiente bloque de alto valor despues de P0 es: validacion con dispositivo, calibracion de Stress, companion watchOS, widgets y ampliar Journal/Tendencias. Un reloj biologico multivariable validado y el coach conversacional siguen despues.
- **Stress / VO2 / Bio Age (julio 2026):** implementacion + evidencia en [README_StressAndBio.md](README_StressAndBio.md). No llamar PhenoAge a la beta, no presentar VO2 como laboratorio y no llamar “estres mental” a bandas basadas en HRV/RHR.
