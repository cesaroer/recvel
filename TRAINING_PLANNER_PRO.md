# Planificador de entrenamiento profesional

## Objetivo

La Agenda semanal de Recvel no es solo un calendario. Es una capa local de planificación y autorregulación para personas activas y atletas: describe la intención de cada sesión, cuantifica la carga prevista, incorpora la respuesta real y propone ajustes prudentes sin diagnosticar ni predecir lesiones.

## v2 (julio 2026): plan semanal, biblioteca y alto rendimiento

- La agenda se llama **Plan semanal** y todas las sesiones ejecutables viven en **Plantillas de entrenamiento**. `WeeklyRoutine` organiza cuándo entrenar; `WorkoutTemplate` define qué hacer, tanto en fuerza como cardio, movilidad, recuperación, rendimiento y desafío diario.
- **Biblioteca de planes** (`WeeklyPlanLibraryStore`, UserDefaults): guardar el plan actual, aplicar uno guardado (con confirmación), renombrar, duplicar, eliminar uno o eliminar todos. Patrón "Saved Plans" de Apple Fitness+ / biblioteca de TrainingPeaks.
- **Gestor de rutinas** (`WorkoutTemplateManagerView`): editar, eliminar una o eliminar todas las rutinas desde la sección Fuerza.
- **Asistente en dos velocidades** (`WeeklyPlanOnboardingView`): modo rápido de 4 pantallas (perfil, modalidades, días, revisión) para el usuario básico, y modo avanzado ("Opciones de alto rendimiento") que suma fase, editor por día y marcas 1RM. Botón **Atrás** en todos los pasos.
- **Desafío diario (opt-in):** toggle en «¿Qué incluye tu semana?». Mini-rutina ligera distinta al estímulo del día (`DailyChallengeEngine`, anti-overlap muscular). Cada desafío se materializa como `WorkoutTemplate`, aparece en Plantillas y usa el editor compartido. Movilidad y recuperación también son rutinas completas; cardio se prescribe como un ejercicio con duración.

## Plantillas como fuente de verdad

- `WorkoutTemplateKind` distingue fuerza, cardio, movilidad, recuperación, rendimiento y desafío diario sin crear editores paralelos.
- El catálogo incluido se materializa una sola vez con `sourceID` estable y aparece en Plantillas antes de crear un plan.
- `WeeklyRoutine.sessionTemplateIDs` y `dailyChallengeTemplateIDs` enlazan la agenda con rutinas editables. Los JSON anteriores siguen leyendo `dailyChallenges` y `exercisesText` y se migran localmente al abrir Entrenamiento.
- `TemplateCodec` admite series/repeticiones (`3x10`), una cantidad directa (`30`) y tiempo (`45s`, `12 min`).
- Cardio, movilidad, recuperación y desafíos abren una sesión cronometrada; fuerza conserva el registro por series, kilos y repeticiones.
- **Tipos de sesión más allá del gym**: movilidad/flexibilidad, recuperación/fisioterapia, técnica, pliometría (contactos), aceleración/velocidad (reps × metros) y método de contraste (giant sets), con parámetros propios por tipo. La pliometría mide volumen en contactos; el contraste se limita a 2-4 giant sets; la velocidad usa repeticiones de 10-60 m.
- **Marcas 1RM opcionales** (sentadilla, banca, peso muerto, militar) guardadas en el plan; nunca se inventan si el usuario no las da.
- **Revisión con "Qué esperar de este plan"** (`PlanExpectationEngine`): expectativas prudentes por objetivo/nivel/fase y precauciones (cero descansos, ≥3 sesiones RPE 8+, potencia sin base técnica, minutos por debajo de lineamientos).
- **Edición por día desde la tira semanal**: tocar un día abre `TrainingDayEditorSheet` con tipo, horario, duración, RPE y parámetros pro.
- **Coaching consciente del tipo de sesión**: las sesiones de alta demanda neuronal (plio, velocidad, contraste) se sugieren mover/adaptar cuando la recuperación es baja o hay molestias altas; los días de recuperación tras racha reciben refuerzo positivo.

## Referencias de producto

- **TrainingPeaks:** sesiones estructuradas con duración, intensidad objetivo, calendario, eventos y comparación entre plan y ejecución.
- **WHOOP:** objetivo diario de carga adaptado a recuperación, sueño y carga reciente; separa el plan de la respuesta fisiológica.
- **Garmin:** disposición para entrenar, carga aguda, estado de HRV, recuperación y sugerencias diarias como señales complementarias, no como una orden única.
- **Apple Health:** entrenamientos, duración, energía, frecuencia cardiaca, zonas cuando están disponibles y esfuerzo manual/estimado de 1 a 10 en iOS 18.

Recvel adopta los patrones conceptuales útiles, no sus marcas, fórmulas propietarias, textos ni recursos visuales.

## Arquitectura funcional

### Programa

- Experiencia: inicial, intermedia, avanzada o competitiva.
- Objetivo: salud general, hipertrofia, fuerza máxima, resistencia o rendimiento deportivo.
- Fase: base, desarrollo, pico, descarga o mantenimiento.
- Distribución de fuerza, deporte cardiovascular y fecha de evento opcional.

### Sesión

Cada día puede definir:

- tipo: fuerza (rutina), cardio (deporte), movilidad, recuperación/fisioterapia, técnica, pliometría, aceleración/velocidad, contraste o descanso;
- foco o plantilla;
- duración;
- RPE objetivo de 1 a 10;
- hora de inicio;
- horario fijo, preferido o flexible;
- intención cardiovascular: recuperación, suave, tempo, intervalos, técnica, partido o sesión larga;
- parámetros por tipo (avanzado): contactos de salto, giant sets, repeticiones y metros de sprint, zona FC objetivo, %1RM del levantamiento principal y nota libre.

La carga interna prevista usa **sRPE = minutos x RPE objetivo**. La carga ejecutada usa duración real x esfuerzo reportado o importado. Es una unidad interna para comparar al usuario consigo mismo, no una equivalencia de carga mecánica ni de riesgo.

### Autorregulación

Antes de entrenar, el usuario puede registrar energía, molestias musculares, motivación y dolor o limitación. El motor cruza este registro con recuperación, sueño, esfuerzo anterior, días consecutivos, foco muscular y horario. Las salidas posibles son mantener, moderar, cambiar foco, mover horario o recuperar.

Las recomendaciones son transparentes y conservadoras:

- no convierten HRV o Recovery en diagnóstico;
- no prohíben entrenar un músculo por una regla rígida de 48 horas;
- no afirman que todo ejercicio nocturno empeore el sueño;
- ante dolor o limitación no empujan a completar la sesión;
- explican qué datos influyeron y muestran la evidencia.

## Evidencia científica

- El RPE de sesión es una medida práctica, válida y ampliamente aplicable de carga interna, aunque puede complementarse con señales fisiológicas: [Haddad et al., PMID 29163016](https://pubmed.ncbi.nlm.nih.gov/29163016/).
- Atletas y entrenadores pueden percibir de forma distinta la intensidad; por eso Recvel prioriza el reporte del usuario: [Arney et al., PMID 35244801](https://pubmed.ncbi.nlm.nih.gov/35244801/).
- Full body y rutinas divididas producen resultados similares cuando el volumen semanal se iguala: [Ramos-Campo et al., PMID 38595233](https://pubmed.ncbi.nlm.nih.gov/38595233/).
- La periodización mejora especialmente la fuerza máxima; en personas entrenadas puede ser útil variar la carga dentro de la semana: [Williams et al., PMID 35044672](https://pubmed.ncbi.nlm.nih.gov/35044672/).
- La hora de ejercicio, por sí sola, no determina un peor sueño. El efecto depende de intensidad, proximidad al sueño y respuesta individual: [PMID 41032147](https://pubmed.ncbi.nlm.nih.gov/41032147/) y [PMID 36540196](https://pubmed.ncbi.nlm.nih.gov/36540196/).

## Datos de Apple Health

Recvel puede usar sesiones, hora real, duración, deporte, energía, frecuencia cardiaca, zonas, esfuerzo manual y esfuerzo estimado cuando HealthKit los entregue. No puede conocer con fiabilidad el grupo muscular, series, repeticiones, dolor o intención de la sesión sin entrada del usuario. Esos datos permanecen locales y editables.

## Criterios de aceptación

- El JSON anterior de `WeeklyRoutine` debe seguir decodificando (incluye los campos pro de `ScheduledSessionDetails`, todos opcionales).
- Una agenda profesional conserva fase, nivel y configuración por día.
- La pantalla semanal muestra carga prevista, minutos, distribución e intensidad.
- El registro diario se guarda localmente y puede reemplazarse el mismo día.
- El motor diferencia horario fijo de flexible y sesiones suaves de intensas.
- Las recomendaciones funcionan con datos parciales y nunca inventan HealthKit.
- El usuario básico configura su plan en 4 pantallas; el avanzado controla cada día con tipos de alto rendimiento.
- La biblioteca permite guardar, aplicar, renombrar, duplicar, eliminar un plan o eliminarlos todos; las rutinas de fuerza pueden eliminarse una por una o todas desde su gestor.
- Build y pruebas se ejecutan exclusivamente en iPhone 16 Pro con iOS 18.6.
