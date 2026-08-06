# Recvel Copy Style Guide

> Fuente de verdad para todo texto visible en iOS, Apple Watch, widgets,
> Live Activities y notificaciones. Si otro README contradice esta guía,
> prevalece este documento.

## 1. Historia de producto

Recvel convierte señales personales de salud, descanso, actividad y nutrición
en decisiones claras, privadas y accionables. No intenta hablar como un
médico ni como un entrenador que grita. Explica qué cambió, contra qué se
compara, qué puede significar y cuál es el siguiente paso más razonable.

Promesa editorial:

> Tus datos, explicados con ciencia y contexto para que decidas mejor hoy.

La privacidad local es una cualidad del producto, no un eslogan alarmista:
decimos exactamente qué permanece en el dispositivo y cuándo algo podría
salir de él.

## 2. Voz

La voz base es **ciencia cercana**: precisa, breve, humana y sin jerga
innecesaria. Se adapta por contexto sin cambiar de personalidad:

| Contexto | Tono | Ejemplo |
|---|---|---|
| Entrenamiento y Carga | Directo, energético, orientado al rendimiento | "Hoy conviene una carga moderada." |
| Sueño y Recuperación | Sereno, prudente, sin culpa | "Acostarte cerca de las 22:45 puede ayudarte a recuperar parte de tu deuda de sueño." |
| Estrés y Diario | Observacional, cuidadoso | "Tu activación fisiológica estuvo sobre tu rango habitual. Esto no identifica la causa." |
| Nutrición y Ayuno | Práctico, neutral, seguro | "La foto sugiere entre 520 y 680 kcal. Ajusta la porción antes de guardar." |
| Edad fisiológica | Científico y transparente | "Esta estimación compara tu VO2 max con referencias poblacionales; no mide envejecimiento biológico completo." |

### Reglas de redacción

- Español mexicano neutro, trato de `tú` y sin modismos marcados.
- Sentence case en títulos, botones y etiquetas.
- Una idea principal por oración. Preferir verbos concretos.
- Explicar términos técnicos en el punto donde ayudan a decidir.
- Usar `puede`, `sugiere`, `se asocia` y `estimación` cuando la evidencia no
  permite causalidad o certeza individual.
- Las acciones deben ser específicas y proporcionales al dato.
- Nunca culpabilizar por dormir, comer, descansar o saltarse un registro.
- Nunca inferir emociones, enfermedad o lesiones a partir de wearables.

### Patrones prohibidos

- Metáforas ambiguas: "Construye sin vaciarte", "carga el tanque".
- Antropomorfismos sin sustento: "Tu cuerpo exige", "tus señales admiten".
- Absolutos: "esto mejorará", "necesitas", "garantizado", "exacto".
- Diagnósticos o tratamiento: "detectamos ansiedad", "corrige tu insomnio".
- Spanglish evitable: `briefing`, `baseline`, `feature`, `reset`, `mock`,
  `free tier`, `workout` o `journal` dentro del copy en español.
- Abreviaciones coloquiales: usar `entrenamiento` y `entrenamientos`, nunca
  `entreno` o `entrenos` en títulos, métricas, recordatorios o accesibilidad.
- Preguntas usadas como encabezado descriptivo: escribir `Lo que influye en tu
  Recuperación`, no la pregunta aislada `Qué influye`.
- Motivación genérica: "Tú puedes", "sin excusas", "da el 110 %".

## 3. Arquitectura del mensaje

Una recomendación completa sigue este orden:

1. **Dato:** qué se observó.
2. **Contexto:** comparación con el rango habitual, objetivo o período.
3. **Interpretación:** qué podría significar, sin inventar causalidad.
4. **Acción:** una conducta concreta y opcional.
5. **Límite:** confianza, datos faltantes o naturaleza estimada.

No todas las superficies necesitan los cinco pasos. Widgets y Apple Watch
usan dato + acción; una vista de detalle puede mostrar la secuencia completa.

Ejemplo:

- Antes: "Construye sin vaciarte."
- Título: "Hoy conviene una carga moderada."
- Detalle: "Tus señales de recuperación están cerca de tu rango habitual.
  Entrena con margen y ajusta la intensidad según cómo te sientas."

## 4. Glosario de producto

Los identificadores internos y `rawValue` persistidos no se traducen. Esta
tabla controla únicamente la presentación.

| Concepto interno | Español (México) | English |
|---|---|---|
| Recovery | Recuperación | Recovery |
| Strain | Carga | Load |
| Sleep | Sueño | Sleep |
| Energy | Energía | Energy |
| Stress | Estrés fisiológico | Physiological stress |
| Calm score | Calma | Calm |
| Fitness | Entrenamiento | Training |
| Journal | Diario | Journal |
| Bio Age | Edad fisiológica | Physiological age |
| Baseline | Referencia personal / rango habitual | Personal baseline / usual range |
| Score | Puntuación | Score |
| Insights | Hallazgos | Insights |
| Briefing | Resumen de la mañana | Morning summary |
| Check-in | Registro | Check-in |
| Workout | Entrenamiento | Workout |
| Demo data | Datos de demostración | Demo data |
| Reset | Restablecer | Reset |
| API key | Clave de API | API key |
| Keychain | Llavero | Keychain |

Usamos las siglas internacionales `HRV`, `RHR`, `VO2 max`, `SpO2`, `SDNN`,
`REM` y `MET`. En tipografía compatible se presentan como `VO₂ máx.` y
`SpO₂`.

## 5. Definiciones científicas

Las siglas llevan ayuda en su primera aparición relevante dentro de una
pantalla de detalle. No se agrega el icono a entrypoints de Home, tab bar,
widgets, Live Activities ni vistas compactas de Apple Watch.

| Sigla | Nombre | Copy breve aprobado | Límite obligatorio |
|---|---|---|---|
| HRV | Variabilidad de la frecuencia cardíaca | Variación entre latidos; ayuda a observar cambios en regulación autonómica y recuperación. | Apple Health aporta principalmente SDNN y una lectura aislada no identifica la causa del cambio. |
| RHR | Frecuencia cardíaca en reposo | Latidos por minuto cuando estás en reposo; su tendencia aporta contexto sobre aptitud y recuperación. | Calor, enfermedad, alcohol, hidratación y otros factores pueden modificarla. |
| VO₂ máx. | Consumo máximo de oxígeno | Estimación de capacidad cardiorrespiratoria durante el ejercicio. | Apple Watch realiza una estimación submáxima; sirve mejor para tendencias que como valor de laboratorio. |
| SpO₂ | Saturación de oxígeno | Porcentaje estimado de hemoglobina que transporta oxígeno. | Las lecturas de consumo no sustituyen una evaluación clínica. |
| SDNN | Desviación estándar de intervalos normales | Método de HRV que resume la variabilidad total observada. | Depende de la duración, calidad y contexto de la medición. |
| REM | Movimiento ocular rápido | Etapa de sueño asociada con actividad cerebral elevada. | Las etapas de wearables son estimaciones y tienen más error que la duración total. |
| MET | Equivalente metabólico | Unidad relativa para comparar el costo energético de una actividad. | Es una aproximación poblacional, no una medición metabólica individual. |

El popover muestra la definición breve y se oculta al volver a tocar, al tocar
fuera o después de cinco segundos. Con VoiceOver o Switch Control no se cierra
automáticamente. `Ver metodología` abre una ficha persistente con límites y
fuentes. Las fuentes proceden de `AI_CONTEXT.md`,
`README_StressAndBio.md`, `JOURNAL_SLEEP_RESEARCH.md` y
`Calorie_AI_Research.md`.

## 6. Microcopy

### Acciones

- Usar verbos: `Guardar comida`, `Iniciar entrenamiento`, `Revisar permisos`.
- `Listo` solo confirma una tarea; no sustituye una acción específica.
- Destructivos describen el alcance: `Borrar datos locales`.

### Estados

- Carga: `Actualizando tus datos...`
- Sin datos: decir qué falta y cómo obtenerlo.
- Datos parciales: mostrar lo disponible y bajar la confianza.
- Error: explicar que ocurrió y ofrecer una acción recuperable.
- Éxito: confirmar qué cambió, sin celebración excesiva.

### Confianza

- `Alta`: suficientes datos recientes para una tendencia personal estable.
- `Media`: útil como orientación, con historial o señales incompletas.
- `Baja`: estimación preliminar; pedir confirmación o más datos.
- Nunca usar confianza alta para convertir una estimación de consumo en una
  verdad clínica.

### Números y unidades

- Formatear con la configuración regional activa; no concatenar decimales manualmente.
- Mantener un espacio entre valor y unidad: `58 ms`, `52 lpm`, `7.6 h`.
- Español: `kcal`, `lpm`, `min`. Inglés: `kcal`, `bpm`, `min`.
- Los rangos usan lenguaje explícito: `520-680 kcal estimadas`.

## 7. Localización

- Idiomas soportados: `es-MX` y `en`; fallback editorial: `es-MX`.
- Selector: `Automático`, `Español (México)`, `English`.
- Las claves son semánticas: `score.recovery.title`, no frases fuente.
- Los motores devuelven claves + argumentos; las vistas resuelven el idioma.
- Texto del usuario, nombres personalizados y nombres de fuentes no se
  traducen.
- Cambiar idioma debe actualizar app, widgets, Live Activities,
  notificaciones pendientes y Apple Watch.
- Revisar expansión de texto y Dynamic Type; nunca abreviar una idea hasta
  volverla ambigua.

## 8. Accesibilidad

- Toda imagen accionable tiene etiqueta localizada.
- Una puntuación se lee con nombre, valor, estado y confianza.
- No depender solo del color para comunicar estado.
- La ayuda temporal permanece visible con tecnologías de asistencia.
- Los textos de gráficas describen tendencia y período, no cada pixel visual.

## 9. Checklist editorial

- [ ] Existe en español e inglés.
- [ ] Usa el glosario oficial.
- [ ] Se entiende sin conocer a un competidor.
- [ ] Distingue dato, interpretación y recomendación.
- [ ] Evita causalidad, diagnóstico y precisión falsa.
- [ ] Incluye confianza o límite cuando corresponde.
- [ ] Cabe en tamaños compactos y Dynamic Type.
- [ ] Tiene etiqueta de accesibilidad si es interactivo.
