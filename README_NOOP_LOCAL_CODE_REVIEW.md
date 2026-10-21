# Segunda comparación: Recvel y el código local de NOOP

Revisión del 19 de octubre de 2026, usando directamente `/Users/cesarvargastapia/Downloads/noop-main`.

## Qué se revisó

Se siguieron rutas desde sus entradas de navegación hasta las vistas, controladores, motores, persistencia y pruebas disponibles. La distinción importante es entre una función conectada al producto, un motor sin consumidor encontrado y una propuesta documental.

- Recvel: commit `b1b9e3f52cc79020487a643bcbbcc6a7c370a29c`; los cambios locales previos eran el README y la comparación del 16 de octubre. No había cambios locales en código de la app.
- NOOP: carpeta descargada sin `.git`. `project.yml` declara versión `12.1.0`, build `438` e iOS mínimo `17.0`. Esto identifica la configuración, pero no demuestra un commit o release exactos.
- Huella SHA-256 del README de esa copia: `f258b8de3f006d26eac3c321dfe1933b51a2ac6b4257fab44b94b89490014c5f`.
- La copia temporal usada el 16 de octubre ya no estaba disponible. No se afirma que esta carpeta sea más nueva ni que las diferencias descritas sean cambios recientes: varias son precisiones o ampliaciones de la auditoría anterior.
- Revisión estática. No se ejecutó NOOP, no se conectó hardware y no se atribuyen resultados de pruebas a la mera existencia de tests. No se modificó su carpeta.

La [comparación anterior](README_NOOP_COMPARISON.md) sigue siendo útil para importación, respaldos, nutrición y licencia. Este documento precisa la profundidad de implementación y corrige lo que podía interpretarse como una función terminada cuando solo existe el motor.

## Conclusión revisada

**NOOP tiene más profundidad implementada en ejecución de sesiones de fuerza, análisis longitudinal, personalización cardiovascular e interoperabilidad.** La diferencia no se limita a conectarse por Bluetooth o importar CSV.

**Recvel tiene una integración más específica de alimentación, agenda de entrenamiento, rutinas complementarias, ayuno y diario mental.** Esto no implica que sus estimaciones nutricionales sean más precisas ni que sus scores estén validados. La ventaja es el flujo de producto que ya conecta esos dominios.

La adaptación más valiosa combina la agenda y las plantillas de Recvel con una sesión persistente, zonas personales, mejores controles de calidad y análisis históricos. Para lograrlo, conviene reforzar los datos y la ejecución antes de añadir más puntuaciones.

## Comparación siguiendo el código

| Función | NOOP local: implementación y conexión | Recvel actual | Adaptación recomendada |
| --- | --- | --- | --- |
| Sesión de fuerza recuperable | `LiftSessionController` vive en la raíz, persiste cambios y recupera la sesión al iniciar; alimenta pantalla, barra y Live Activity | `ActiveWorkoutSessionView` mantiene ejercicios y hora en `@State`; persiste sesión/series al finalizar | Controlador de sesión compartido y borrador recuperable |
| Descansos y continuidad | Estados de sesión, temporizadores por fecha, valores pendientes y avisos fuera de la hoja | Hay ejecución y registro de series, pero sin el mismo ciclo de vida persistente | Descanso entre series, minimizar/reabrir y restaurar tras terminación del proceso |
| Live Activities | Bundle y controladores conectan fuerza, FC en vivo y sincronización | ActivityKit está dedicado al ayuno | Priorizar entrenamiento: ejercicio, serie, descanso y siguiente acción |
| Widgets | Resumen, curva de FC, curva de estrés y resumen del Coach | Recuperación/tablero de métricas y ayuno | Curvas con huecos reales y un widget de próxima sesión; no multiplicar widgets sin datos útiles |
| FC máxima y zonas | Ajustes permiten FC máxima manual y cinco umbrales; `Profile.hrZoneSet` llega a `LiveWorkoutView` | Importación calcula una FC máxima estimada por sesión y con mínimo de 180 lpm | Perfil cardiovascular persistente y zonas editables con fuente y fecha |
| Carga a largo plazo | `TrainingLoadCard` consume CTL/ATL/TSB del motor con ventanas 42/7 días y estados de cobertura | Carga por sesión/día, agenda, esfuerzo y recomendaciones; no equivalente CTL/ATL/TSB encontrado | Gráfica longitudinal opcional con unidades y cobertura claras |
| Recuperación de FC | Detalle de entrenamiento consume HRR de 1/2/5 minutos, con muestras mínimas y continuidad | HRR de un minuto ya existe, con criterios más simples | Mejorar elegibilidad y cobertura del dato existente, después ampliar ventanas |
| Estrés durante el día | Vista consume `DaytimeStress`, con referencia diurna, mínimo de muestras y exclusión por movimiento cuando dispone de acelerometría | Curva horaria de FC sobre RHR; cálculo separado del indicador diario | Distinguir actividad, recuperación posterior, reposo y falta de observaciones |
| Discrepancias entre dispositivos | `FusedRecordHost` llama al adaptador y presenta ganador, contribuyentes y discrepancias | Selección de muestras preferidas y nombres de fuente, sin explorador equivalente | Procedencia por métrica y elección explicable; corregir los límites descritos abajo |
| Sueño editable | Edición de horas/siestas, protección de correcciones frente a nuevas sincronizaciones, recálculo y aviso de cambios | Detalles, planificación, rutina y datos HealthKit; sin correcciones locales equivalentes encontradas | Anotación/corrección local reversible, conservando intacta la muestra original |
| Horarios y ritmo diario | `CircadianEngine` llega a `AppModel` y a componentes de reloj corporal | Horario habitual, recomendaciones, planificación y calculadora de ciclos | Contexto de regularidad y cambios de horario; investigar antes de estimar fase circadiana |
| Pronóstico de recuperación | `IntelligenceView` llama a `RecoveryForecaster` | Recomendaciones actuales, sin el mismo pronóstico numérico encontrado | Mejorar preparación para mañana; una cifra predictiva requiere evaluar error real |
| Siri/Atajos | App Intents implementados y registrados: marcar momento, sincronizar pulsera, vibración y consulta al Coach | Sin `AppIntent`/`AppShortcutsProvider` encontrado | Registrar agua/comida, abrir rutina y consultar resumen mediante acciones acotadas |
| Gasto energético adaptativo | Motor y tests Swift/Kotlin; no encontré un consumidor de producto en ninguno de los dos | Metas iniciales por perfil, actividad y objetivo | Idea experimental, no ventaja de una pantalla ya entregada por NOOP |
| Nutrición completa | Importadores nutricionales; no encontré captura estructurada por foto/porción y biblioteca de planes equivalente | Registro, edición, recetas locales, planes, chat Gemini opcional, biblioteca y envío confirmado a HealthKit | Mantener la experiencia Recvel y corregir sus límites de estimación |

Evidencia de sesiones y superficies: [controlador NOOP][n-session], [integración iOS][n-ios-app], [bundle de widgets][n-widgets], [Live Activity de fuerza][n-lift-activity], [sesión Recvel][r-fitness] y [widgets Recvel][r-widgets]. Evidencia de análisis: [carga longitudinal][n-load], [tarjeta que lo consume][n-load-card], [detalle de entrenamiento][n-workout], [estrés][n-stress-view] y [fuentes][n-fused-host].

## Diferencias que importan para atletas

### 1. Conservar una sesión mientras se usa el resto de la app

NOOP separa el estado de la sesión de la vista que la muestra. `start` persiste, `resumeSaved` recupera y `resume` reconstruye los valores pendientes, series y descanso. La app iOS conecta los cambios del controlador a ActivityKit. Hay pruebas específicas que leen JSON de una versión anterior y comprueban la restauración de valores aún no confirmados.

Recvel guarda las series completadas al finalizar. El borrador actual vive en `@State` y `bootstrap()` reconstruye la sesión desde la plantilla. No encontré una restauración de ese borrador tras terminar el proceso. Esto no significa que cada paso a segundo plano lo borre: el riesgo aparece cuando se destruye ese estado antes de guardar.

**Propuesta:** `WorkoutSessionController` con un borrador persistente, reloj basado en fechas, pasos de sesión y un único estado para iPhone, Live Activity y reloj. Una serie planeada debe conservarse distinta de una completada, y un objetivo de RPE distinto de la percepción reportada. NOOP permite completar pendientes al finalizar y rellena RPE desde el objetivo si falta; esa decisión no debe copiarse como si todo fuera una observación del usuario.

Fuentes: [sesión NOOP][n-session], [tests de persistencia][n-session-tests], [sesión Recvel][r-fitness].

### 2. Zonas personales que no cambien con cada entrenamiento

En `HealthDataProvider`, Recvel usa `max((maximum ?? 175) * 1.03, 180)` como FC máxima estimada para las zonas del entrenamiento importado. Por tanto, el pico de una sesión puede cambiar los límites usados para clasificarla; la ruta no utiliza una FC máxima personal configurable.

NOOP ofrece FC máxima manual y umbrales de zona editables, persistidos en el perfil y utilizados en el entrenamiento en vivo. Además, su código distingue zonas visibles por porcentaje de FC máxima de otros métodos de carga: no conviene asumir que todas sus cifras de zona/carga usan exactamente el mismo método.

**Propuesta:** guardar método, FC máxima, límites, fuente y fecha de vigencia; permitir edición y explicar cuándo una referencia es estimada. No recalcular silenciosamente todo el historial tras cambiar el perfil. Un valor configurado tampoco garantiza precisión fisiológica: debe conservar su contexto.

Fuentes: [consulta Recvel][r-health], [zonas NOOP][n-zones], [ajustes NOOP][n-settings], [perfil NOOP][n-profile].

### 3. Ver la acumulación de entrenamiento

NOOP tiene una superficie conectada para carga crónica, aguda y balance. El motor usa suavizado exponencial, inicia desde observaciones reales y distingue descanso medido de día faltante. Un hueco interrumpe la secuencia utilizada; el estado inicial sigue figurando como calibración.

Recvel cuenta con carga, esfuerzo, progresión de fuerza y agenda, pero no encontré esta comparación longitudinal. Sería útil para visualizar semanas de acumulación y descarga, siempre que primero exista el historial necesario. El input de NOOP es su puntuación de carga diaria: sus valores no son automáticamente TRIMP ni una probabilidad de lesión.

**Propuesta:** aprovechar datos de Recvel con una definición de carga estable y explícita; mostrar cobertura y no convertir un balance negativo en una prohibición automática de entrenar.

Fuentes: [motor y reglas de ausencias][n-load], [tarjeta conectada][n-load-card], [motor de carga Recvel][r-score].

### 4. Mejorar la HRR que Recvel ya tiene

No hace falta crear la función desde cero. Recvel busca una FC al terminar y otra cercana al minuto, pero puede usar como referencia final una muestra anterior a los últimos 45 segundos; solo emite la diferencia si la FC bajó. No tiene en esa ruta los controles de continuidad y mínimo de muestras del motor NOOP.

NOOP calcula ventanas de 1/2/5 minutos y devuelve ausencia si faltan observaciones. Su elegibilidad exige esfuerzo sostenido cerca del final; las pruebas incluyen desconexiones, fragmentos y una diferencia con signo negativo. Son controles de implementación concretos, no prueba de equivalencia a una evaluación clínica.

**Propuesta:** conservar signo y procedencia, exigir proximidad/cobertura suficiente y explicar el protocolo. Ampliar a 2/5 minutos solo cuando HealthKit tenga muestras suficientes, sin interpolar un resultado faltante.

Fuentes: [Recvel: cálculo dentro de workouts][r-health], [motor NOOP][n-hrr], [tests NOOP][n-hrr-tests].

## Estrés, sueño y calidad: qué sí adaptar

La curva de estrés de Recvel sale de promedios horarios de FC y una referencia RHR, con fallback de 58 lpm cuando esa referencia falta. `loadActivation` no excluye sesiones de ejercicio ni exige una cobertura mínima más allá de tener muestras. El indicador diario de estrés usa otro cálculo; no debe confundirse con esta curva.

NOOP tiene exclusión por movimiento cuando dispone de acelerometría, una máscara posterior a actividad y estados sin datos. Además, mantiene desactivada la contribución diurna RMSSD en el modo de referencia personal (`daytimeRMSSDScoringEnabled = false`), aunque el código pueda calcularla. La presencia de R-R no significa que todas sus pantallas lo usen como entrada del score.

Lo aprovechable es la distinción visible entre reposo, ejercicio, recuperación posterior y señal insuficiente. Las constantes de NOOP dependen de su adquisición: su mínimo de 300 muestras por hora no se puede trasladar sin más al muestreo de Apple Watch. Sus comparaciones con otro wearable tampoco demuestran validación clínica. Fuentes: [activación Recvel][r-health], [motor diurno NOOP][n-daytime], [consumidor en pantalla][n-stress-view].

En sueño, NOOP permite corregir horas y siestas y conserva esas correcciones frente a detecciones posteriores. También avisa si un resultado cambia tras sincronizar. Recvel puede incorporar correcciones locales, una explicación de la noche seleccionada y un historial de actualización, manteniendo separados el registro original, la corrección y el score recalculado. Fuente: [SleepView][n-sleep].

La calculadora actual de Recvel ofrece ciclos de 90 minutos y 15 minutos para conciliar el sueño. Son supuestos explícitos del código; no equivalen a fases medidas esa noche. Conviene que la UI los presente como una aproximación de horario y que el plan priorice necesidad de sueño y regularidad. Fuente: [SleepCyclePlanner][r-cycle].

## Límites de NOOP encontrados al seguir los consumidores

### La fusión es visible, pero no gobierna toda la app

`FusedRecordHost` sí está conectado a navegación y carga datos reales. Sin embargo, `buildTodayFusedRecord` es una lectura adicional: el propio adaptador no sustituye la resolución principal de series. No se debe describir como un consenso multifuente aplicado automáticamente a cada score.

También selecciona la última fila de cada fuente dentro de un intervalo de aproximadamente tres días y las entrega al comparador sin exigir una fecha común. Eso permite, por ejemplo, comparar una fuente actualizada hoy con otra cuya última fila es de anteayer y presentar la diferencia como discrepancia entre fuentes.

La política usa prioridades por tipo de fuente. Para sueño, una entrada genérica Apple Health recibe menor prioridad que etapas calculadas por NOOP; esto no inspecciona qué dispositivo o método originó cada muestra de HealthKit. La interfaz de fusión tampoco incorpora el método HRV en cada entrada. Recvel debe conservar fecha, ventana, método y dispositivo antes de intentar resolver discrepancias.

Fuentes: [adaptador de AppModel][n-app], [resolver][n-fusion], [política de prioridades][n-policy]. Este hallazgo corresponde a la pantalla de fusión; no prueba que todo el pipeline NOOP mezcle fechas o métodos.

### El pronóstico es una heurística, no una predicción demostrada

`RecoveryForecaster` combina media reciente, carga, sueño previsto y reversión a la media con constantes. La banda se construye desde dispersión histórica y mínimos fijos. Está conectado a `IntelligenceView`, pero no encontré en ese motor una calibración del intervalo frente al error predictivo real.

El producto puede mostrar una orientación aproximada, pero no deberíamos trasladar esa cifra a Recvel como expectativa fiable de la recuperación de mañana. Una primera versión útil puede explicar preparación, carga y oportunidad de sueño sin prometer un porcentaje futuro. Fuentes: [motor][n-forecast], [consumidor][n-intelligence].

### El reloj corporal usa un proxy concreto

Aunque parte de sus comentarios describe ritmo de actividad, el código documenta que el consumidor real alimenta el cosinor con FC media por hora. El mínimo térmico puede derivarse mediante un desplazamiento fijo; no es necesariamente temperatura central medida. El propio motor indica que ningún consumidor de producción aporta el mínimo térmico observado en esa ruta.

Es una función conectada, pero no conviene copiar sus etiquetas como si midiéramos fase circadiana directamente. Para Recvel tendría prioridad mostrar horario habitual, variabilidad y contexto de exposición a luz, con una investigación separada antes de estimar cronotipo. Fuentes: [CircadianEngine][n-circadian], [AppModel][n-app].

### Hay motores que todavía no equivalen a una función de producto

`AdaptiveExpenditureEngine` tiene implementación y tests. La búsqueda de sus consumidores en Swift y Kotlin de producción solo encontró las definiciones y referencias internas del motor, sin una vista/repositorio que llame a `estimate`. Por eso se corrige la comparación anterior: existe capacidad técnica, pero no se confirma un flujo de gasto adaptativo disponible para el usuario.

Esta misma comprobación se aplicó a otras funciones: las tarjetas de carga, el coste por actividad, la fusión, el pronóstico y las Live Activities sí tienen consumidores identificables. Fuente: [motor adaptativo][n-adaptive].

## Lo que Recvel conserva como diferencial

| Flujo de Recvel | Diferencia frente a esta copia de NOOP |
| --- | --- |
| Capturar comida, ajustar porción y confirmar | NOOP importa nutrición, pero no encontré este flujo estructurado equivalente |
| Asistente y biblioteca de planes | Recvel permite generar, guardar, renombrar, ajustar y eliminar planes; el modo Gemini es remoto y opcional |
| Agenda más rutinas complementarias | Recvel conecta tipo de sesión, horario, esfuerzo, plantillas y desafío diario |
| Ayuno | Flujo específico, sensaciones, historial y Live Activity |
| Diario mental | Entradas guiadas y calendario junto a los hábitos; NOOP tiene ánimo/hábitos, no el mismo flujo encontrado |
| Edad fisiológica por lentes | FRIEND y PhenoAge separados; NOOP sí tiene otras edades estimadas y laboratorios, pero no ese mismo método |

NOOP podría adoptar estos flujos y una separación más explícita entre objetivos, estimaciones y observaciones. Recvel debería conservarlos mientras refuerza fiabilidad; no hay motivo técnico para reemplazar nutrición o diario con equivalentes más simples.

Persisten los pendientes del primer análisis: fallback de 260 kcal para texto no reconocido, discrepancia entre referencias anunciadas de 60 días y carga de 30, ceros en tendencias cuando faltan datos y consentimiento insuficientemente granular del contexto Gemini. El código de Recvel sigue en la misma revisión; este análisis no los corrige.

## Orden propuesto después de esta revisión

| Orden | Trabajo | Resultado verificable |
| --- | --- | --- |
| 1 | Confianza de datos y privacidad ya documentadas | Alimentos desconocidos sin macros inventados; ausencias sin ceros; contexto remoto autorizado |
| 2 | Sesión persistente de entrenamiento + Live Activity | Editar series, navegar, terminar el proceso y recuperar el mismo borrador/descanso; guardar una sola vez |
| 3 | Perfil cardiovascular y HRR | Zonas estables/editables, fuente visible y HRR solo con cobertura suficiente |
| 4 | Historial, respaldo y procedencia | Ventanas reales, restauración completa y actualizaciones trazables |
| 5 | Estrés contextual y widgets de curvas | Ejercicio identificado, huecos visibles y datos antiguos distinguidos de actuales |
| 6 | Análisis longitudinal y resumen semanal | Carga acumulada, periodos comparables y asociaciones con suficiente historial |
| 7 | Sueño corregible, Atajos y Home configurable | Correcciones reversibles, acciones del usuario y preferencias persistentes |
| Experimental | Pronóstico numérico, reloj corporal y gasto adaptativo | Validación propia y error documentado antes de afectar metas o consejos |

La sesión persistente sube de prioridad respecto al análisis anterior por su impacto directo durante un entrenamiento. Para integrar reloj y teléfono, se necesita definir qué dispositivo controla la sesión y cómo se resuelven cambios concurrentes; no basta con añadir una pantalla de series al Watch.

La modularidad de NOOP es una referencia útil, pero no elimina toda su complejidad: `AppModel.swift` tiene 2,703 líneas y `Repository.swift` 3,540 en esta copia. En Recvel, `FitnessView.swift` tiene 5,606 y concentra vista, planificación y ejecución. El primer límite a extraer debería ser la sesión activa, con pruebas de recuperación, no una reescritura general del proyecto.

Cada entrega posterior con código debe compilar y ejecutar pruebas apropiadas exclusivamente en el simulador existente **iPhone 16 Pro, iOS 18.6**, sin crear otros ni paralelizar suites. Reanudación real de HealthKit en Watch, BLE y avisos hápticos requieren validación física adicional. En esta entrega solo se actualizaron documentos; no se compiló ni ejecutó la suite.

NOOP conserva [PolyForm Noncommercial](../noop-main/LICENSE). Las propuestas son adaptaciones conceptuales; no se ha incorporado código ni assets del repositorio.

## Comparación del respaldo científico

Revisión adicional: 2026-10-19. Inspección estática y contraste con publicaciones originales; no se ejecutaron benchmarks ni se modificaron algoritmos. Se distingue entre evidencia de una señal, fidelidad a un método publicado y validación del resultado completo de la app.

### Ventajas concretas de NOOP

- **FC máxima estimada:** `HRZones.swift:105` aplica Tanaka, `208 - 0.7 × edad`, y permite un máximo manual. Es un método poblacional publicado, más justificable como fallback que `max(pico de sesión × 1.03, 180)` en `HealthDataProvider.swift:525` de Recvel. No equivale a medir la FC máxima individual ni valida automáticamente las zonas metabólicas. Fuente: [Tanaka et al., 2001](https://pubmed.ncbi.nlm.nih.gov/11153730/).
- **HRV longitudinal experimental:** `HRVReadiness.swift` analiza lnRMSSD promediada y referencia personal prolongada. El uso de promedios tiene respaldo en investigación deportiva, pero sus ventanas, límites y categorías son una adaptación propia. El módulo declara que no está validado con datos diversos y está desactivado por defecto; no demuestra que la recuperación habitual de NOOP sea superior. Su filtrado utiliza noches válidas, no necesariamente siete días consecutivos. Fuente: [Plews et al., 2014](https://pubmed.ncbi.nlm.nih.gov/24334285/).
- **Disciplina de validación:** `docs/VALIDATION_PROTOCOL.md` exige predicciones previas, referencias independientes, mediciones reproducibles y evaluación fuera de los datos usados para ajustar. Dispone de herramientas para contrastar sueño con PSG. Es una ventaja de infraestructura y metodología, no prueba de precisión clínica: el propio documento reconoce resultados anteriores que no resistieron una nueva medición.
- **Control de calidad:** los filtros de densidad de muestras, actividad y recuperación tras ejercicio en sus motores de estrés/HRR son buenas prácticas de medición. Sus umbrales concretos no quedan validados solo por tener pruebas unitarias.

### Donde no está demostrada una superioridad

- **Recuperación, energía y estrés:** en ambos proyectos existen combinaciones y umbrales propios. En Recvel, los pesos de HRV/RHR/sueño y las conversiones a puntuación de `ScoreEngine.swift` no deben presentarse como una fórmula clínicamente validada. La evidencia de cada componente no demuestra la exactitud de la combinación.
- **Edad fisiológica:** `VitalityEngine.swift` de NOOP combina asociaciones con riesgo usando coeficientes aproximados, un ajuste de solapamiento y conversión propia a años. No se encontró validación externa de esa combinación. Su consistencia de sueño basada en variación de duración tampoco es equivalente al Sleep Regularity Index.
- **PhenoAge en Recvel:** elegir un modelo publicado aporta trazabilidad, no certifica nuestra implementación. El modelo original tiene validación poblacional independiente, pero no es una medición literal del envejecimiento de una persona ni valida las otras puntuaciones de Recvel. Fuente: [Liu et al., 2018](https://journals.plos.org/plosmedicine/article?id=10.1371/journal.pmed.1002718).

### Hallazgo pendiente: unidad de CRP en PhenoAge

`Recvel/Services/BiomarkerEngine.swift:118` calcula `log(input.crpMgL)`. El resolver normaliza CRP a mg/L y la entrega sin convertir a mg/dL. La tabla 1 del artículo original especifica **mg/dL** para el término logarítmico de CRP. Es una discrepancia concreta con el método publicado; debe corregirse y verificarse con casos de referencia independientes antes de presentar este cálculo como reproducción fiel.

Fuente primaria: [Levine et al., 2018, tabla 1, página 576](https://yunliweb.its.unc.edu/pdf/Levine2018.pdf). El artículo describe tanto la edad fenotípica clínica como el reloj epigenético posterior; Recvel implementa la primera, no DNAm PhenoAge.

Estado: **identificado, no corregido en esta revisión**. La siguiente entrega debería auditar unidades y coeficientes completos, probar equivalencia mg/L–mg/dL y contrastar resultados con una implementación de referencia independiente; no basta con generar las expectativas de prueba desde nuestra misma fórmula.

Conclusión: NOOP tiene ventajas puntuales de método y validación reproducible. No se encontró evidencia para afirmar que todas sus puntuaciones sean científicamente superiores. La prioridad de Recvel debe ser corregir discrepancias con métodos publicados y evaluar nuestros cálculos, no añadir referencias bibliográficas como sustituto de esa validación.

## Evidencia local

Los enlaces apuntan a los archivos inspeccionados en esta Mac. Las líneas sirven para localizar las implementaciones, no para sustituir la lectura de sus consumidores.

[n-session]: /Users/cesarvargastapia/Downloads/noop-main/Strand/Data/LiftSessionController.swift:135
[n-session-tests]: /Users/cesarvargastapia/Downloads/noop-main/StrandTests/LiftSessionPersistenceTests.swift:45
[n-ios-app]: /Users/cesarvargastapia/Downloads/noop-main/StrandiOS/App/StrandiOSApp.swift:258
[n-widgets]: /Users/cesarvargastapia/Downloads/noop-main/StrandiOSWidgets/NOOPWidgetBundle.swift:10
[n-lift-activity]: /Users/cesarvargastapia/Downloads/noop-main/StrandiOSWidgets/LiftLiveActivity.swift:16
[n-zones]: /Users/cesarvargastapia/Downloads/noop-main/Packages/StrandAnalytics/Sources/StrandAnalytics/HRZones.swift:115
[n-settings]: /Users/cesarvargastapia/Downloads/noop-main/Strand/Screens/SettingsView.swift:444
[n-profile]: /Users/cesarvargastapia/Downloads/noop-main/Strand/Data/Profile.swift:207
[n-load]: /Users/cesarvargastapia/Downloads/noop-main/Packages/StrandAnalytics/Sources/StrandAnalytics/TrainingLoadEngine.swift:22
[n-load-card]: /Users/cesarvargastapia/Downloads/noop-main/Strand/Screens/TrainingLoadCard.swift:76
[n-workout]: /Users/cesarvargastapia/Downloads/noop-main/Strand/Screens/WorkoutDetailView.swift:139
[n-hrr]: /Users/cesarvargastapia/Downloads/noop-main/Packages/StrandAnalytics/Sources/StrandAnalytics/HeartRateRecovery.swift:46
[n-hrr-tests]: /Users/cesarvargastapia/Downloads/noop-main/Packages/StrandAnalytics/Tests/StrandAnalyticsTests/HeartRateRecoveryTests.swift:113
[n-daytime]: /Users/cesarvargastapia/Downloads/noop-main/Packages/StrandAnalytics/Sources/StrandAnalytics/DaytimeStress.swift:119
[n-stress-view]: /Users/cesarvargastapia/Downloads/noop-main/Strand/Screens/StressView.swift:142
[n-fused-host]: /Users/cesarvargastapia/Downloads/noop-main/Strand/Screens/V5PillarHosts.swift:22
[n-app]: /Users/cesarvargastapia/Downloads/noop-main/Strand/App/AppModel.swift:2289
[n-fusion]: /Users/cesarvargastapia/Downloads/noop-main/Packages/StrandAnalytics/Sources/StrandAnalytics/FusionResolver.swift:24
[n-policy]: /Users/cesarvargastapia/Downloads/noop-main/Packages/StrandAnalytics/Sources/StrandAnalytics/MetricArbitrationPolicy.swift:111
[n-sleep]: /Users/cesarvargastapia/Downloads/noop-main/Strand/Screens/SleepView.swift:259
[n-forecast]: /Users/cesarvargastapia/Downloads/noop-main/Packages/StrandAnalytics/Sources/StrandAnalytics/RecoveryForecast.swift:83
[n-intelligence]: /Users/cesarvargastapia/Downloads/noop-main/Strand/Screens/IntelligenceView.swift:127
[n-circadian]: /Users/cesarvargastapia/Downloads/noop-main/Packages/StrandAnalytics/Sources/StrandAnalytics/CircadianEngine.swift:94
[n-adaptive]: /Users/cesarvargastapia/Downloads/noop-main/Packages/StrandAnalytics/Sources/StrandAnalytics/AdaptiveExpenditureEngine.swift:61
[r-fitness]: /Users/cesarvargastapia/Downloads/Recvel/Recvel/Views/FitnessView.swift:5016
[r-widgets]: /Users/cesarvargastapia/Downloads/Recvel/RecvelWidgets/RecvelWidgets.swift:1
[r-health]: /Users/cesarvargastapia/Downloads/Recvel/Recvel/Services/HealthDataProvider.swift:475
[r-score]: /Users/cesarvargastapia/Downloads/Recvel/Recvel/Services/ScoreEngine.swift:446
[r-cycle]: /Users/cesarvargastapia/Downloads/Recvel/Recvel/Services/SleepCyclePlanner.swift:42
