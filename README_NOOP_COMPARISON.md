# Recvel y NOOP: comparación técnica y de producto

Fecha de revisión: 16 de octubre de 2026.

**Actualización del 19 de octubre:** la [segunda revisión del código local](README_NOOP_LOCAL_CODE_REVIEW.md) usa `Downloads/noop-main` y sigue consumidores reales. Amplía sesiones persistentes, Live Activities, zonas personales, HRR y estrés; precisa que el motor de gasto adaptativo no tiene una integración de producto encontrada y documenta límites de la fusión y los pronósticos. Las referencias fijadas de este documento corresponden a la revisión original.

## Alcance y método

Esta revisión contrasta el código de Recvel con [ryanbr/noop](https://github.com/ryanbr/noop), no solo sus listas de funciones. Se revisaron documentación, modelos, proveedores de datos, motores, pantallas, sincronización, importadores, pruebas y configuración de automatización. La inspección fue dirigida por capacidades y flujos; no constituye una auditoría de cada línea de ambos repositorios.

| Proyecto | Revisión inspeccionada | Base de evidencia |
| --- | --- | --- |
| Recvel | `b1b9e3f52cc79020487a643bcbbcc6a7c370a29c` | Workspace local, documentación y código iOS/watchOS/compartido |
| NOOP | `8e4b0c16e7640607600fa6bde5424095eba6034e` | Copia de referencia de solo lectura y enlaces fijados a ese commit |

No se ejecutó código de NOOP ni se compiló su aplicación. No se conectaron sensores ni se hicieron pruebas de rendimiento, autonomía o precisión. Tener una implementación o pruebas en el repositorio no demuestra que una función sea fiable con todo hardware, ni que su algoritmo esté validado clínicamente. Las capturas publicadas sirven como referencia visual, no como prueba de la versión actual en ejecución.

En este documento, **no encontrado** significa que no se encontró un equivalente en el código auditado; no es una afirmación sobre futuras versiones. Las recomendaciones son propuestas, no funciones entregadas.

## Conclusión ejecutiva

Los proyectos se solapan, pero resuelven problemas distintos:

- **Recvel:** experiencia integrada de bienestar y entrenamiento alrededor de Apple Health. Destacan el registro de comidas, la planificación nutricional, el ayuno, el diario mental, la agenda de entrenamiento y las lentes separadas de edad fisiológica.
- **NOOP:** control y exploración de los propios datos. Destacan la conexión directa a determinados sensores, la importación de historiales, la procedencia de métricas, las comparaciones longitudinales y la portabilidad mediante respaldos y exportaciones.
- **Oportunidad para Recvel:** conservar su experiencia de producto y añadir la transparencia y profundidad de datos de NOOP. No hace falta convertirla en un cliente de pulseras ni reproducir toda su superficie multiplataforma.
- **Oportunidad para NOOP:** incorporar flujos más completos de alimentación, planificación y reflexión personal, sin depender exclusivamente de importar datos que otras apps hayan generado.

Dos correcciones importantes a una lectura superficial: NOOP **sí tiene entrenamiento de fuerza**, y **sí tiene estimaciones de edad de aptitud física/corporal y un registro de laboratorios**. No son exclusivas de Recvel; lo diferencial es el método concreto y la experiencia que las rodea.

## Matriz de capacidades

| Área | Recvel actual | NOOP auditado | Diferencia útil |
| --- | --- | --- | --- |
| Plataformas | iPhone, widgets, Live Activities y Apple Watch | macOS, iOS, Android y Apple Watch; madurez desigual | Recvel puede concentrarse en una experiencia Apple más coherente |
| Fuente principal | Lectura autorizada de HealthKit | Sensores directos y archivos; integración de salud según plataforma | NOOP tiene más control sobre señales crudas y procedencia |
| Otros wearables | Indirectamente, si escriben datos compatibles en Apple Health | WHOOP 4; WHOOP 5/MG parcial; Oura experimental; código de protocolo Polar | No confundir soporte parcial, importación y compatibilidad completa |
| Garmin/Fitbit/Xiaomi | Datos que lleguen a Apple Health; sin importador propio equivalente | Importadores de exportaciones; no implica BLE completo | Importar archivos aporta valor sin mantener protocolos propietarios |
| Historial | Consulta principal de 30 días, con excepciones puntuales como VO₂ máx. | Base histórica local y exploración de periodos extensos | Falta una capa longitudinal persistente en Recvel |
| Recuperación y carga | Motores propios, referencia robusta y factores explicables | Charge/Effort/Rest propios, referencias y señales de sensores | Ninguno reproduce el algoritmo privado de WHOOP |
| HRV | SDNN proporcionada por Apple Health | RMSSD/SDNN desde intervalos R-R cuando existen, con limpieza | No son intercambiables ni admiten trasladar umbrales sin adaptación |
| Estrés | Indicador diario y curva de activación cardiovascular | Vistas y cálculos vinculados a señales más continuas | La frecuencia de adquisición condiciona lo que puede prometerse |
| Sueño | Etapas de HealthKit, consistencia, deuda, horario y rutina | Detección/etapas propias, revisión de intervalos y herramientas de evaluación | Recvel debería mejorar trazabilidad, no empezar otro clasificador |
| Tendencias | Gráficas en detalles; vista general centrada en siete días | Explorador con 7/30/90/180/365 días y todo el historial | Ampliación de alto valor para Recvel |
| Comparación de métricas | Sin explorador general equivalente encontrado | Comparación de 2–4 métricas y correlaciones | Añadir cruces seleccionados, con unidades y límites claros |
| Diario y hábitos | Calendario semanal/mensual, día despertar-a-despertar, etiquetas y diario mental guiado | Hábitos, estado de ánimo y análisis de asociaciones | Recvel destaca en el registro; NOOP en análisis posteriores |
| Efectos diferidos | Asociación de hábitos con Sueño/Recuperación del mismo día | Análisis con desfases y respuesta por dosis en motores específicos | Hay que resolver primero la alineación temporal de Recvel |
| Fuerza | Plantillas, series, cargas, estimación de 1RM, progreso y agenda | Programas, sesiones, series, RPE, descansos e importación | Ambos tienen una base; importación y ejecución en reloj son oportunidades |
| Rutinas complementarias | Desafío diario y rutinas de movilidad/recuperación integradas | No encontrado un generador complementario equivalente | Diferenciador aprovechable de Recvel |
| Reloj | Resumen, complicaciones y captura HealthKit de entrenamientos | Entrenamientos, respiración e intervalos con interacción en muñeca | Extender herramientas de sesión de Recvel antes que otra pantalla de resumen |
| Respiración | Ejercicios guiados en iPhone | Respiración, reloj y biofeedback cuando hay R-R válidos | Añadir sesión en reloj es viable; biofeedback requiere otra base de datos |
| Comida | Foto, texto, voz y código de barras; corrección y confirmación | Importación nutricional, entre otras fuentes CSV | Recvel tiene el flujo de captura que no encontré equivalente en NOOP |
| Planes nutricionales | Motor local y flujo opcional Gemini con planes, ajustes, chat y biblioteca | Registro/análisis nutricional; sin flujo equivalente de comidas generado encontrado | No confundir el plan local con el asistente remoto |
| Gasto energético adaptativo | Metas iniciales por perfil y actividad | Motor retrospectivo con ingesta/peso; en la copia local revisada el 19 de octubre no se encontró consumidor de producto | Capacidad técnica experimental, no una pantalla confirmada |
| Ayuno | Flujo específico, seguridad, sensaciones, historial y Live Activity | No encontrado un módulo equivalente de igual alcance | Diferenciador de Recvel |
| Cafeína y agua | Datos agregados de HealthKit y etiquetas del diario | Registros por dosis/hora, estimación de cafeína restante y seguimiento de agua | Recvel puede convertir agregados en decisiones de horario |
| Edad fisiológica | Lentes Cardio/FRIEND y Sangre/PhenoAge separadas | Fitness Age y Vitality/Body Age con otras aproximaciones | Mismo rótulo comercial no significa mismo constructo científico |
| Laboratorios | Ingreso manual, unidades y panel PhenoAge; importación clínica opcional | Lab Book y catálogo/importación de marcadores | Recvel debe reforzar validación de unidades, paneles y método |
| Ciclo | Etiquetas sensibles opt-in; sin equivalente completo de fases encontrado | Motor de fases con señales fisiológicas y registro | Posible contexto voluntario; no inferencia anticonceptiva |
| Personalización | Agenda, diario y perfiles configurables; Home principalmente prescrito | Reordenar/ocultar módulos de Today y personalizar Sueño | Muy buena adaptación para deportistas y bienestar general |
| Exportar/recuperar datos | Sin respaldo integral/restauración ni exportador general encontrado | Respaldo/restauración, CSV y reportes PDF | Prioridad alta para sostener la promesa de propiedad de datos |
| IA externa | Integración opcional de nutrición con Gemini | Coach con varios proveedores y endpoint compatible configurable | La opción externa debe explicarse y autorizarse por separado |
| Automatización local | No encontrado App Intents/MCP general | Acceso local de solo lectura por MCP/CLI en escritorio | En iPhone conviene empezar por Atajos con alcance limitado |
| Ingeniería | Motores puros y pruebas, pero varias vistas muy extensas | Paquetes Swift separados, pruebas y workflows de CI | Adoptar límites comprobables, no una reescritura total |

Evidencia NOOP: [soporte de dispositivos][n-devices], [importadores][n-import], [explorador][n-explorer], [comparación][n-compare], [funciones documentadas][n-features]. Evidencia Recvel: [proveedor HealthKit](Recvel/Services/HealthDataProvider.swift), [entrenamiento](Recvel/Views/FitnessView.swift), [nutrición](Recvel/Views/NutritionView.swift), [asistente](Recvel/Views/NutritionPlanFlowView.swift), [diario](Recvel/Views/JournalProView.swift).

## Qué tomar conceptualmente de NOOP

### 1. Centro de fuentes y calidad del dato

Una pantalla que responda: qué dispositivo produjo la métrica, cuándo se midió, cuánto historial hay, qué muestras se excluyeron y por qué falta un resultado. En los detalles, mostrar una fuente por métrica y una cobertura de días, no solo una lista general de fuentes del día.

Recvel ya selecciona muestras preferidas y expone problemas de calidad; no se propone empezar desde cero. Falta convertir esa lógica en trazabilidad visible y persistente. Debe distinguir **dato ausente**, **sin actualización reciente**, **señal insuficiente** y **resultado no calculable**. Un dato ausente no prueba permiso denegado en HealthKit.

Referencia: [catálogo de métricas][n-catalog] y [explorador de NOOP][n-explorer].

### 2. Historial largo y comparaciones elegidas por el usuario

Ventanas de 30/90/180/365 días, comparación con el periodo anterior y superposición de dos métricas: sueño frente a carga, horario de entrenamiento frente a sueño o ingesta registrada frente a peso.

Para Recvel requiere almacenamiento derivado local e importación incremental, con cambios y eliminaciones de HealthKit reconciliados. También necesita versión del algoritmo para diferenciar un cambio fisiológico de un cambio de cálculo. No basta con alargar el bucle actual de consultas a 365 días en cada apertura.

Las gráficas deben preservar huecos, unidades originales y cobertura. Si se normalizan series para compararlas, hay que decirlo y permitir inspeccionar valores reales. Una correlación seleccionada entre muchas puede ser casual.

### 3. Resumen semanal determinista y exportable

Un informe local con cambios en regularidad del sueño, carga, actividad, percepción de esfuerzo y cumplimiento del plan. Primero observaciones comprobables; después sugerencias prudentes. Debe poder funcionar sin LLM ni red.

NOOP tiene un [resumen semanal][n-weekly] y [reportes PDF][n-report]. En Recvel serviría también para compartir voluntariamente con entrenador o profesional, sin crear una cuenta ni un backend.

### 4. Respaldo y restauración de verdad

Exportar un archivo versionado con comidas, diarios, rutinas, planes y preferencias. Restaurar con validación previa, vista de lo que se importará, detección de duplicados y recuperación ante error. Exportar CSV por dominio como complemento legible.

NOOP ya tiene [respaldo local y rotación][n-backup]. No asumir que su formato está cifrado. Para Recvel, el cifrado y la exclusión de claves de API deben ser requisitos explícitos. Elegir una carpeta de iCloud/Dropbox puede activar una subida por ese proveedor: sigue siendo una decisión externa al backend de la app y debe explicarse.

### 5. Cómo se asocian tus sesiones con el día siguiente

Comparar recuperación y sueño después de distintos tipos, horarios y volúmenes de sesión, con número de observaciones y datos faltantes. Integrarlo en la agenda: una observación útil es que tus sesiones nocturnas registradas coinciden con menos sueño; no que la app conoce la hora biológicamente perfecta para entrenar.

El [motor de coste por actividad de NOOP][n-activity] exige un mínimo de sesiones y compara mañanas posteriores con días de referencia. Es una buena idea de producto, pero no elimina confusión por intensidad, enfermedad, alcohol o trabajo. Tampoco debe prescribir días de descanso mediante una media de pocos casos. Adaptar al reloj real de la sesión y al día despertar-a-despertar, no copiar su agrupación diaria sin más.

### 6. Diario con asociaciones temporalmente correctas

Separar hábitos previos al sueño de lo que ocurre después de despertar; después permitir desfases justificados, tamaño del efecto y suficiente historial. Recvel ya tiene un registro mejor estructurado de lo que aparenta una comparación de screenshots, pero el motor analítico todavía cruza por fecha civil.

NOOP ofrece [efectos con desfase][n-effects]. No copiar automáticamente el desfase que produzca el resultado más grande: explorar muchos cruces aumenta falsos hallazgos. Mantener ausencia de respuesta distinta de `No`, y no aplicar etiquetas de certeza clínica a una asociación personal.

### 7. Cafeína por dosis y horario

Registrar bebida, miligramos estimados y hora; mostrar una aproximación de cafeína restante al acostarse. Cruzar con el horario de sueño y presentar margen de incertidumbre, porque metabolismo, medicamentos y sensibilidad varían.

NOOP tiene [registros y decaimiento aproximado][n-caffeine]. Recvel ya consulta cafeína diaria, pero un total diario no permite inferir la última toma. Cuando falte hora, pedirla; no fabricarla a partir del agregado.

### 8. Herramientas realmente útiles en Apple Watch

Priorizar temporizador de descanso entre series, intervalos trabajo/recuperación, pasos de una rutina, registro de esfuerzo y respiración háptica. Aprovechar las plantillas y sesiones existentes de Recvel, sin crear un segundo editor independiente.

NOOP tiene [respiración][n-watch-breathe] e [intervalos][n-watch-interval]. El biofeedback HRV en tiempo real es otro proyecto: exige intervalos R-R válidos, limpieza y comprobación en hardware. Apple Health SDNN agregado no equivale a un flujo instantáneo de RMSSD.

### 9. Home configurable sin perder el diseño

Permitir fijar, ocultar y reordenar módulos, con perfiles sugeridos como entrenamiento, descanso y bienestar. Mantener jerarquía, legibilidad, Liquid Glass y animaciones sutiles; no trasladar toda la densidad de escritorio ni copiar los medidores de líquido de NOOP.

El valor está en la [personalización de Today][n-customize], las etiquetas de procedencia y la elección de métricas, no en sustituir la identidad visual de Recvel.

### 10. Importaciones acotadas y acceso local controlado

Comenzar con CSV de nutrición/peso y FIT/TCX/GPX para actividades, si el historial existente en Apple Health no resuelve la necesidad. Vista previa, unidades, zona horaria, atribución y deduplicación antes de confirmar. Archivos ZIP/XML grandes necesitan límites y procesamiento incremental; los archivos de entrada no son confiables.

El [MCP/CLI de NOOP][n-local-access] es interesante para escritorio, pero no es un servidor que debamos incrustar en iOS. Recvel puede comenzar con App Intents: registrar agua, abrir un entrenamiento y consultar un resumen permitido. Dar datos a otro asistente, aunque el primer salto sea local, no garantiza que ese asistente no los envíe a la nube.

## Qué podría aprovechar NOOP de Recvel

| Aporte de Recvel | Por qué complementa NOOP | Condición para adaptarlo |
| --- | --- | --- |
| Registro de comida con confirmación y correcciones | Reduce dependencia de CSV nutricionales externos | No trasladar el fallback numérico arbitrario descrito abajo |
| Perfil, objetivos y propuestas de comidas | Convierte análisis retrospectivo en planificación práctica | Mantener alergias, incertidumbre y controles de seguridad |
| Biblioteca de planes: guardar, renombrar, ajustar y eliminar | Permite dar continuidad al asistente, no solo conversar | Separar generación remota de persistencia local y consumo real |
| Ayuno con historial y Live Activity | Añade un flujo cotidiano que no encontré equivalente | Sin promesas exactas sobre autofagia ni recomendaciones para personas con contraindicaciones |
| Diario mental guiado y calendario | Aporta reflexión y contexto, además de marcar hábitos | No diagnosticar salud mental y conservar entradas sensibles opt-in |
| Agenda con plantillas unificadas y desafío complementario | Une planificación, ejecución y progresión | No duplicar el catálogo de rutinas por cada feature |
| Lentes Cardio/FRIEND y Sangre/PhenoAge | Permite diferenciar aptitud física de un índice sanguíneo | Validar fórmulas/unidades; no sumarlas ni venderlas como una edad biológica verdadera |
| Definiciones científicas contextuales | Explica siglas, interpretación y limitaciones dentro del flujo | La explicación debe corresponder al cálculo implementado, no solo al paper citado |

Referencias Recvel: [plan local](Recvel/Services/NutritionPlanEngine.swift), [flujo y biblioteca](Recvel/Views/NutritionPlanFlowView.swift), [ayuno](Recvel/Views/FastingView.swift), [Diario Pro](Recvel/Views/JournalProView.swift), [biomarcadores](Recvel/Services/BiomarkerEngine.swift) y [metodología existente](README_StressAndBio.md).

## Ciencia: qué comparar y qué no trasladar

| Tema | Diferencia real | Decisión recomendada |
| --- | --- | --- |
| HRV | Recvel lee SDNN de HealthKit; NOOP puede calcular RMSSD desde R-R | Guardar método, contexto y fuente. No comparar números absolutos como si fueran la misma métrica |
| Scores de recuperación | Ambos combinan señales con reglas y pesos propios | Son índices de producto, no resultados clínicamente validados por citar estudios de cada señal |
| Edad fisiológica | Recvel implementa FRIEND/PhenoAge; NOOP tiene HUNT/Nes y una composición Vitality propia | Mantener lentes y nombres específicos. Esta auditoría no valida ninguna fórmula contra una cohorte |
| Body Age de NOOP | Vitality combina relaciones de riesgo y una conversión a años con supuestos | No sustituir PhenoAge por esa combinación ni interpretar su margen visual como intervalo validado |
| Sueño | Recvel muestra etapas de la fuente; NOOP tiene algoritmos propios | No atribuir a Recvel validación del dispositivo, ni a NOOP validez clínica por tener tests |
| Carga y lesión | Algunos cálculos de NOOP incluyen ACWR | No producir predicciones de lesión ni umbrales prescriptivos desde ese cociente |
| Gasto adaptativo | NOOP combina ingesta y tendencia del peso con una conversión energética fija | Explorar con cobertura e incertidumbre; no ajustar metas por cambios breves de agua/peso |
| Correlaciones | Más métricas y desfases producen más oportunidades de asociaciones espurias | Declarar exploración, tamaño de muestra y confusores; priorizar hipótesis antes de probarlas |

Fuentes de implementación: [FitnessAgeEngine][n-fitness-age], [VitalityEngine][n-vitality], [AdaptiveExpenditureEngine][n-expenditure] y [protocolo de evaluación del sueño][n-validation]. Para la distinción de SDNN: [documentación oficial de HealthKit](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilitysdnn). Para las limitaciones del ACWR: [Impellizzeri et al., 2020, PubMed](https://pubmed.ncbi.nlm.nih.gov/32502973/).

Antes de adoptar un cálculo nuevo hay que documentar población de referencia, adquisición, unidades, ventanas, ausencias, precisión conocida y condiciones donde no se calcula. Los mínimos de observaciones escritos en NOOP son decisiones de implementación, no validaciones universales para Recvel.

## Privacidad: ambos son local-first, no necesariamente sin red

NOOP documenta mejor la frontera entre procesamiento local y funciones que pueden usar internet. Su [inventario de red][n-privacy] incluye consulta de actualizaciones activada por defecto, Coach configurable, una importación cloud de Oura excluida de la compilación por defecto y push experimental de Android. También distingue servicios del sistema, mapas y archivos elegidos por el usuario. La existencia de estas rutas no equivale a telemetría biométrica automática.

Recvel necesita un inventario equivalente, especialmente porque la privacidad es parte central de su identidad:

| Ruta de Recvel | Qué se observó | Cambio necesario |
| --- | --- | --- |
| HealthKit, scores y SwiftData | Procesamiento principal local | Explicar también el almacenamiento/compartición que controla el sistema, sin prometer que Apple Health nunca sincroniza |
| Gemini para estimación | Cliente de API y aviso en el flujo de registro | Mantener consentimiento y mostrar datos concretos que saldrán |
| Gemini para planes y chat | El constructor agrega resúmenes de salud, hábitos, comidas, emociones y entrenamiento al contexto | Consentimiento separado por dominios, vista previa y opción de excluir diario/estado emocional |
| Búsqueda de producto | Consulta externa a Open Food Facts | Identificar destino y datos enviados; disponer de entrada manual sin red |
| Dictado | Se usa SFSpeechRecognizer sin exigir reconocimiento on-device en el flujo inspeccionado | No prometer voz 100% local; comprobar disponibilidad, exigir modo local o pedir consentimiento para alternativa |
| Exportación futura | Todavía no hay respaldo integral | Mostrar qué sale, dónde y si está cifrado; excluir secretos |

En el flujo de planes inspeccionado, conectar una clave de Gemini no está separado de una autorización granular para enviar los distintos dominios de salud. El aviso de la clave habla de su envío a Google, pero eso no explica el alcance del contexto de salud. El flujo de estimación y el de planificación deben pasar por el mismo contrato de privacidad, no por avisos inconexos.

Evidencia: [GeminiPlanService](Recvel/Services/GeminiPlanService.swift), [flujo de planes](Recvel/Views/NutritionPlanFlowView.swift), [registro y dictado](Recvel/Views/NutritionView.swift) y [catálogo de copy](Shared/Localizable.xcstrings). No se generó un plan ni se envió información personal durante esta revisión.

## Pendientes reales de Recvel antes de ampliar funciones

Estos puntos aparecieron al contrastar las promesas del producto con los caminos de código. No se corrigieron en esta entrega de análisis.

| Prioridad | Hallazgo | Evidencia | Criterio de resolución |
| --- | --- | --- | --- |
| P0 | Una descripción no vacía que no coincide con el catálogo devuelve 260 kcal y macros fijos | `NutritionEstimator.swift`, rama `matches.isEmpty` | Estado no identificado, sin total inventado; pedir alimento/porción o entrada manual |
| P0 | El contexto del asistente remoto agrega varios dominios personales sin control granular equivalente | `PlanContextBuilder.make`, `NutritionPlanFlowView.startGeneration` | Previsualización y autorización explícita antes de cada tipo de envío; memoria de consentimiento revocable |
| P1 | Se anuncian referencias HRV/RHR de 60 días pero la carga principal cubre 30 y la serie usa valores diarios | `HealthDataProvider.refresh`, `BiomarkerEngine.wearableSeries`, catálogo de biomarcadores | Implementar ventana/agregado reales o corregir nombre, periodo y explicación |
| P1 | Tendencias transforma datos ausentes de sueño/HRV en cero | `TrendsView.sleepCard`, `TrendsView.hrvCard` | Dibujar huecos y cobertura, nunca un cero fisiológico inventado |
| P1 | Las asociaciones de Diario Pro se emparejan por misma fecha civil | `JournalProImpactEngine.impacts` | Contrato temporal probado para hábito, noche y mañana; desfases explícitos |
| P1 | No hay recuperación integral de datos locales ante pérdida/borrado de la app | Sin exportador/restaurador general encontrado | Respaldo versionado, restauración probada y protección de datos sensibles |
| P1 | Documentación mezcla capacidades presentes, candidatas y prohibiciones antiguas | README, FEATURES y contexto de agentes frente a código actual | Inventario único con estado, origen del dato, red y límites por función |

No significa que Recvel carezca de controles: ya existen confianza, selección de fuentes, permisos contextuales y pruebas. El problema es que esos controles no cubren todavía todos los caminos. En particular, el texto de README que dice que no se inventan estimaciones no describe la rama de fallback del estimador genérico.

También hay deriva documental: todavía aparecen el reloj como previsto, referencias a modelos VLM candidatos y prohibiciones de cloud junto a flujos Gemini que sí están implementados. `VNClassifyImageRequest` no equivale a haber desplegado SmolVLM/Moondream ni a un modelo especializado validado de calorías. El chat del plan sí existe; no debe figurar como totalmente ausente.

## Plan de acción propuesto

No se propone incorporar todo NOOP. Este orden maximiza utilidad sin cambiar la arquitectura local-first ni sumar una plataforma nueva.

| Bloque | Entregable | Dependencias | Aceptación |
| --- | --- | --- | --- |
| P0. Confianza | Quitar cantidades fabricadas; consentimiento unificado para IA; inventario de red | Estimador, copy y flujos de nutrición | Alimento desconocido no genera macros; ningún contexto sensible sale sin autorización; modo local funciona sin red |
| P1. Datos | Historial incremental, fuentes/frescura, ventanas correctas y valores ausentes | HealthDataProvider, persistencia y modelo de procedencia | 30/60/90 días reales; cambios/eliminaciones reconciliados; ninguna gráfica inventa ceros |
| P1. Propiedad | Respaldo/restauración y exportación CSV | Esquema versionado y política de conflictos | Round trip de todos los datos del usuario, sin claves; recuperación ante archivo inválido; privacidad explícita |
| P1. Valor inmediato | Resumen semanal y dos métricas comparables | Historial confiable | Resultado determinista sin LLM, periodo anterior, cobertura y unidades visibles |
| P2. Personalización | Home configurable y cafeína por hora | Preferencias estables y catálogo de registros | Persistencia del orden; accesibilidad; cafeína sin hora no genera hora inferida |
| P2. Entrenamiento | Asociaciones por sesión/horario y Diario con desfases | Calendario fisiológico e historial suficiente | Tamaños de muestra visibles, controles de confusión y ausencia distinta de `No` |
| P2. Reloj | Descanso entre series, intervalos y respiración | Sesiones y plantillas existentes | Estado reanudable, sincronización coherente y pruebas reales de haptics/HealthKit |
| P3. Interoperabilidad | Importadores seleccionados y App Intents | Procedencia, deduplicación, respaldo | Vista previa de unidades/fechas, límites de archivo y acciones explícitamente autorizadas |
| Experimental | Gasto adaptativo, sensores BLE o biofeedback R-R | Datos válidos y validación específica | No afectar metas/scores por defecto; medir fiabilidad y batería antes de promover |

Cada bloque con código debe terminar con build y pruebas proporcionales. Usar exclusivamente el simulador existente **iPhone 16 Pro con iOS 18.6**, sin crear otros ni ejecutar suites en paralelo. Sensores, permisos de salud reales, haptics del reloj y precisión fisiológica requieren pruebas físicas posteriores; no marcarlos completos solo por pasar el simulador.

Para ingeniería, extraer primero fronteras pequeñas y comprobables: lectura de salud, historial/procedencia, análisis puro, persistencia y presentación. NOOP demuestra el valor de [paquetes con pruebas][n-ci-packages] y [compilación automatizada][n-ci-app]. Recvel no necesita copiar su estructura ni migrar todo SwiftData a SQLite para obtener esos beneficios.

## Qué no recomendaría copiar ahora

- Un clasificador propio de etapas del sueño: complejidad y validación elevadas cuando ya existe una fuente autorizada.
- Una edad corporal compuesta que sume años de varios riesgos sin validación conjunta.
- Predicción de lesiones o recomendaciones prescriptivas basadas en ACWR.
- Detección de enfermedad, alteraciones del ritmo o fertilidad por heurísticas presentadas como conclusiones.
- Soporte masivo BLE: consume esfuerzo de compatibilidad, reconexión, batería y validación por modelo.
- Alarmas de pulsera o automatizaciones de macOS trasladadas literalmente a iPhone/Watch: las capacidades y restricciones no son las mismas.
- Un Coach con numerosos proveedores antes de resolver consentimiento, trazabilidad y límites del asistente actual.
- Nuevas puntuaciones decorativas sin un dato nuevo o una decisión mejor para el usuario.

## Licencia y reutilización

NOOP es **source-available bajo PolyForm Noncommercial 1.0.0**, no una licencia permisiva como MIT/Apache. Su [LICENSE][n-license] no concede uso comercial de su código original. El uso personal no elimina las condiciones, avisos y restricciones de la licencia; tampoco conviene mezclar hoy código restringido con un producto que podría comercializarse después.

Recomendación: usarlo como referencia de producto y arquitectura; implementar de forma independiente lo que decidamos incorporar y registrar las fuentes científicas o especificaciones de protocolo correspondientes. Si se quisiera reutilizar código, revisar antes el alcance concreto y obtener autorización cuando corresponda. Sus dependencias tienen licencias propias; no heredan automáticamente la de NOOP. Esta revisión no sustituye asesoría legal.

No se incorporó código, assets ni dependencias de NOOP al proyecto Recvel.

## Estado de esta entrega

- Comparación documentada de capacidades presentes, parciales y no encontradas.
- Propuestas en ambas direcciones y priorización para Recvel.
- Hallazgos de coherencia de datos, privacidad y documentación identificados, no corregidos.
- Solo documentación modificada. No se ejecutaron build, unit tests ni UI tests; no hay una nueva validación de compilación o de hardware implícita en esta entrega.

## Referencias fijadas de NOOP

Los enlaces siguientes apuntan a la revisión inspeccionada, no a una rama que pueda cambiar después.

[n-features]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/docs/FEATURES.md
[n-devices]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/docs/DEVICE_SUPPORT_ROADMAP.md
[n-import]: https://github.com/ryanbr/noop/tree/8e4b0c16e7640607600fa6bde5424095eba6034e/Packages/StrandImport/Sources/StrandImport
[n-explorer]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/Strand/Screens/MetricExplorerView.swift
[n-compare]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/Strand/Screens/CompareView.swift
[n-catalog]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/Strand/Data/MetricCatalog.swift
[n-weekly]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/Strand/Screens/WeeklyDigestView.swift
[n-report]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/Strand/Screens/TrendsReportView.swift
[n-backup]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/Strand/Data/BackupSync.swift
[n-activity]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/Packages/StrandAnalytics/Sources/StrandAnalytics/ActivityCostEngine.swift
[n-effects]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/Packages/StrandAnalytics/Sources/StrandAnalytics/EffectRanker.swift
[n-caffeine]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/Strand/Data/CaffeineLog.swift
[n-watch-breathe]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/NOOPWatch/WatchBreatheView.swift
[n-watch-interval]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/NOOPWatch/WatchIntervalView.swift
[n-customize]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/Strand/Screens/TodayCustomizationSheet.swift
[n-local-access]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/Packages/NoopLocalAccess/README.md
[n-fitness-age]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/Packages/StrandAnalytics/Sources/StrandAnalytics/FitnessAgeEngine.swift
[n-vitality]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/Packages/StrandAnalytics/Sources/StrandAnalytics/VitalityEngine.swift
[n-expenditure]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/Packages/StrandAnalytics/Sources/StrandAnalytics/AdaptiveExpenditureEngine.swift
[n-validation]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/docs/VALIDATION_PROTOCOL.md
[n-privacy]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/docs/PRIVACY_SECURITY.md
[n-ci-packages]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/.github/workflows/swift-packages.yml
[n-ci-app]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/.github/workflows/app-build.yml
[n-license]: https://github.com/ryanbr/noop/blob/8e4b0c16e7640607600fa6bde5424095eba6034e/LICENSE
