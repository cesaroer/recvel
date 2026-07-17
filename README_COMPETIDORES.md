# Recvel — Análisis de Competidores

> Este documento resume las funciones, métricas y modelos de los principales competidores de Recvel: apps de salud/bienestar que leen datos de wearables y los convierten en insights accionables.

---

## 1. Bevel (bevel.health)

**Posicionamiento:** "The Connected Health Coach". App que unifica datos de wearables, nutrición y registros clínicos con un coach de IA.

### Métricas y scores principales
- **Strain:** esfuerzo diario cardiovascular/muscular (0–100%).
- **Recovery:** readiness basado en HRV, FC en reposo y sueño.
- **Sleep:** puntuación con etapas y recomendación de horas necesarias.
- **Biological Age:** score de envejecimiento biológico.
- **Nutrición:** log de comidas, macros, calorías, puntuación de alimentos.

### Funciones clave
- Integración con Apple Watch, Oura, Garmin y Amazfit.
- **Bevel Intelligence:** coach de IA 24/7 que responde preguntas con datos propios y fuentes científicas.
- **Health Records:** almacena laboratorios, notas clínicas y resultados de sangre.
- **Cycle Tracking:** insights según ciclo menstrual.
- **Strength Training:** registro de levantamientos.
- **Journal, Caffeine Tracking, Water Tracking, Smart Alarm.**
- **Widgets** para Home Screen.

### Diseño
- Interfaz oscura con tarjetas translúcidas.
- Tipografía clara, números grandes, iconografía suave.
- Estética "premium health coach" con toques de vidrio.

### Fuente de datos
- Wearables (Apple Watch, Oura, Garmin, Amazfit).
- Registros clínicos (Labcorp, Quest, etc.).
- Entrada manual de comidas y hábitos.

### Modelo de negocio
- Descarga gratuita.
- Suscripción premium para funciones avanzadas e IA.

### Qué tomar para Recvel
- El concepto de "coach conectado" y fuentes citadas.
- Integración multi-wearable vía HealthKit.
- Diseño oscuro glassmorphism con tarjetas grandes.
- **Evitar:** dependencia de backend y registros clínicos en la primera versión.

---

## 2. WHOOP

**Posicionamiento:** Wearable sin pantalla + app de alto rendimiento enfocada en optimización del sueño, recovery y strain.

### Métricas y scores principales
- **Recovery:** 0–99% basado en HRV, RHR, sueño y frecuencia respiratoria.
- **Strain:** 0–21, esfuerzo cardiovascular y muscular.
- **Sleep Performance:** 0–100% comparado con necesidad de sueño.
- **Sleep Planner:** calcula cuántas horas necesitas dormir.
- **Stress Score:** 0–3 en tiempo real con breathwork.
- **Healthspan / Pace of Aging:** métricas de longevidad.

### Funciones clave
- WHOOP Coach (IA generativa con datos biométricos).
- Journal con 160+ comportamientos (alcohol, cafeína, medicación, etc.).
- Menstrual Cycle Insights.
- Haptic Alarm.
- ECG (función médica regulada por FDA).
- Teams y chat social.

### Diseño
- Dark-first, muy limpio.
- Anillos de progreso grandes y coloridos.
- Gráficos de tendencias simples.
- Tipografía SF Pro, números prominentes.

### Fuente de datos
- WHOOP Strap/Ring (PPG, acelerómetro, temperatura, ECG).
- Integración bidireccional con Apple Health / Health Connect.

### Modelo de negocio
- Hardware + suscripción obligatoria (~$30/mes o $239/año).

### Qué tomar para Recvel
- Los cuatro scores principales (Sleep, Recovery, Strain, Energy/Stress).
- El journal de hábitos y su impacto en métricas.
- El concepto de recomendaciones basadas en readiness.
- **Evitar:** dependencia de hardware propio y suscripción obligatoria.

---

## 3. Amazfit / Zepp

**Posicionamiento:** Ecosistema de wearables accesibles con app Zepp que ofrece métricas de salud, entrenamiento y nutrición.

### Métricas y scores principales
- **HybridCharge / BioCharge:** energía diaria combinando actividad y recuperación.
- **Training Focus:** recomendación de fuerza vs. resistencia.
- **Sleep Score:** etapas, respiración, calidad.
- **Stress:** monitor continuo.
- **SpO2, HRV, RHR, pasos, calorías.**

### Funciones clave
- Log de nutrición por foto con IA.
- Zepp Aura: coach de bienestar con IA.
- Biblioteca de entrenamientos (HYROX, etc.).
- Tienda de esferas y mini-apps.

### Diseño
- Dashboard con tarjetas de actividad/sueño/recuperación.
- Calendario para cambiar de día.
- Log de comidas destacado.

### Fuente de datos
- Relojes/bandas Amazfit (PPG, GPS, SpO2, acelerómetro).
- Cámara del teléfono para comidas.
- Integración parcial con Apple Health.

### Modelo de negocio
- App gratuita.
- Zepp Aura Premium opcional.

---

## 4. Cal AI

**Posicionamiento:** App de tracking calórico impulsada por IA, enfocada en perder peso con fotos de comida y planes personalizados.

### Métricas y scores principales
- **Objetivo calórico diario** calculado a partir de edad, altura, peso, actividad y objetivo.
- **Macros:** calorías, proteínas, carbohidratos y grasas.
- **Proyección de peso:** curva estimada con/without plan.
- **Streaks / adherencia** implícitos en el onboarding.

### Funciones clave
- **Log de comidas por foto o texto** con reconocimiento de alimentos.
- **Plan calórico personalizado** según perfil.
- **Onboarding corto y progresivo:** actividad -> edad -> altura -> objetivos.
- **Value prop visual:** gráfico de tendencia de peso a 6 meses.

### Diseño
- Interfaz clara, fondo blanco, tipografía grande, selectores nativos.
- Un paso por pantalla con progress bar superior.
- Botón "Continuar" fijo abajo.

### Fuente de datos
- Entrada manual del usuario (perfil).
- Cámara del teléfono para fotos de comida.
- Integración con Apple Health para peso (según versión).

### Modelo de negocio
- Descarga gratuita.
- Suscripción premium para funciones avanzadas de IA y planes.

### Qué tomar para Recvel
- Onboarding progresivo que pida actividad, edad, altura/peso y objetivo.
- Proyección de peso con incertidumbre, no línea única.
- Sugerencias de próxima comida basadas en macros restantes.
- Plan nutricional diario/semanal adaptado al historial.
- **Evitar:** preguntas de marketing puro ("¿dónde nos conociste?") y claims sin fuente.

### Qué tomar para Recvel
- Log de comidas por foto con IA.
- Energía diaria combinada.
- **Evitar:** dependencia de hardware Amazfit.

---

## 4. Garmin Connect

**Posicionamiento:** Plataforma deportiva profunda para atletas de endurance y aventura.

### Métricas y scores principales
- **Body Battery:** energía basada en estrés, descanso y sueño (motor Firstbeat).
- **Training Readiness / Training Status / HRV Status.**
- **VO2 max, tiempo de recuperación, carga de entrenamiento.**
- **Sleep Score** con etapas y SpO2.

### Funciones clave
- Análisis deportivo avanzado (running, ciclismo, triatlón, natación).
- Creación de entrenamientos y rutas.
- Garmin Coach.
- Connect IQ (apps y esferas).
- LiveTrack y detección de incidentes.

### Diseño
- Pantalla de inicio personalizable con widgets.
- Mapas, gráficos y métricas avanzadas.
- Estética orientada a atletas.

### Fuente de datos
- Dispositivos Garmin (GPS, PPG, barómetro, HRV).
- Integración con Apple Health, Strava, MyFitnessPal.

### Modelo de negocio
- App gratuita; requiere hardware Garmin.

### Qué tomar para Recvel
- Body Battery como inspiración para Energy Score.
- Training readiness basado en HRV.
- **Evitar:** complejidad excesiva para usuario casual.

---

## 5. Oura

**Posicionamiento:** Anillo inteligente centrado en bienestar, longevidad y recuperación.

### Métricas y scores principales
- **Sleep Score, Readiness Score, Activity Score.**
- **HRV, RHR, temperatura corporal, SpO2, frecuencia respiratoria.**
- **Resiliencia al estrés, edad cardiovascular.**
- **Cycle Insights.**

### Funciones clave
- Oura Advisor (IA).
- Modo Descanso, radar de síntomas.
- Tags/journal.
- Recordatorios de hora de acostarse.

### Diseño
- Minimalista y nórdico.
- Pestañas Today / Vitals / My Health.
- Cards diarias con recomendaciones contextuales.

### Fuente de datos
- Anillo Oura (PPG infrarrojo, temperatura NTC, acelerómetro, SpO2).
- Integración con Apple Health y Natural Cycles.

### Modelo de negocio
- Hardware + suscripción ($5.99/mes o $69.99/año).

### Qué tomar para Recvel
- Readiness como score principal.
- Tags/journal para correlacionar hábitos.
- Enfoque en bienestar más que rendimiento puro.
- **Evitar:** suscripción obligatoria y hardware propio.

---

## 6. Apple Fitness / Apple Health

**Posicionamiento:** Experiencia nativa de Apple para actividad y salud.

### Métricas y scores principales
- **Anillos Move / Exercise / Stand.**
- **Fitness cardiovascular (VO2 max).**
- **Training Load** (carga de entrenamiento).
- **Sleep Score** con etapas y detección de apnea.
- **App Vitals:** FC, FR, temperatura nocturna.

### Funciones clave
- HealthKit como hub central de datos.
- ECG, notificaciones de ritmo irregular.
- Apple Fitness+ (contenido por suscripción).
- Compartir salud con familia/médico.

### Diseño
- Limpio, tarjetas de resumen, gráficos interactivos.
- Favoritos personalizables.
- Integración profunda con iOS.

### Fuente de datos
- Apple Watch, iPhone, AirPods, dispositivos de terceros via HealthKit.

### Modelo de negocio
- Apple Health y Fitness gratuitos.
- Apple Fitness+ de pago.

### Qué tomar para Recvel
- Usar HealthKit como fuente única de verdad.
- Aprovechar métricas nativas como VO2max y Training Load.
- **Diferenciador:** Recvel ofrece interpretación más profunda y diseño premium sin suscripción.

---

## 7. Athlytic

**Posicionamiento:** App local-first basada exclusivamente en Apple Health. Competidor directo de lo que busca Recvel.

### Métricas y scores principales
- **Recovery:** 0–100% con HRV y RHR vs. baseline de 60 días.
- **Exertion:** 0–10 según umbral personal de FC.
- **Target Exertion Zone.**
- **Sleep Quality.**

### Funciones clave
- Solo usa Apple Health (no hardware propio ni cuenta).
- Procesamiento local y privacidad primero.
- Diario/Impact Analysis con auto-tags.
- App para Apple Watch con zonas de FC.
- Widgets y complicaciones.

### Diseño
- Simple, centrado en readiness/exertion/sueño.
- Tarjetas claras, colorimetría de zonas de FC.

### Modelo de negocio
- Descarga gratuita con prueba.
- Suscripción premium para funciones completas.

### Qué tomar para Recvel
- Demuestra que es viable hacer una app tipo WHOOP solo con Apple Health.
- Procesamiento local como diferenciador.
- **Diferenciador:** Recvel suma nutrición con IA, journal más rico y diseño glassmorphism tipo Bevel.

---

## 8. Tabla comparativa

| App | Hardware propio | Suscripción | Local-first | Nutrición IA | HealthKit | Apple Watch | Widgets |
|---|---|---|---|---|---|---|---|
| **Bevel** | No | Sí | No | Sí | Sí | Sí | Sí |
| **WHOOP** | Sí | Obligatoria | No | No | Sí | Sí | No |
| **Amazfit/Zepp** | Sí | Opcional | No | Sí (foto) | Parcial | No | Sí |
| **Garmin** | Sí | No | No | No | Sí | Sí | Sí |
| **Oura** | Sí | Obligatoria | No | No | Sí | Sí | Sí |
| **Apple Fitness** | No | Opcional (Fitness+) | Sí (nativo) | No | Nativo | Nativo | Sí |
| **Athlytic** | No | Opcional | Sí | No | Sí | Sí | Sí |
| **Recvel** | No | No | **Sí** | **Sí** | **Sí** | **Sí** | **Sí** |

---

## 9. Diferenciadores de Recvel

1. **Sin hardware, sin suscripción, sin backend.** Funciona con el Apple Watch que ya tienes.
2. **Local-first real.** Datos que no salen del dispositivo.
3. **Nutrición con IA on-device.** Texto + foto sin depender de servidores propios.
4. **Diseño Bevel/WHOOP.** Glassmorphism oscuro, anillos grandes, gráficos limpios.
5. **Ciencia citada.** Cada recomendación puede mostrar su fuente (PubMed/NIH).
6. **Journal integrado.** Correlación de hábitos con métricas fisiológicas.

---

## 10. Fitness de Bevel: referencia `Bevel_ref_2.mp4`

La grabacion muestra que Bevel no presenta Fitness como una lista de workouts. Lo organiza como una lectura longitudinal y progresiva:

1. Consistencia: calendario de actividad de dos meses visibles y resumen acumulado de 30 dias.
2. Dosis diaria: Strain Performance compara carga observada contra una banda objetivo.
3. Cardio: Cardio Load, Cardio Focus y Heart Rate Recovery tienen tarjetas compactas y details con periodo, grafica, breakdown y explicacion.
4. Fuerza: volumen por musculo, progresion, selector de metrica y plantillas reutilizables.
5. Captura: el menu `+` conecta registro, plantillas y acciones relacionadas sin convertir el flujo principal en un modal generico.

### Implementacion equivalente en Recvel

| Capacidad | Fuente Recvel | Limite honesto |
|---|---|---|
| Calendario / actividad | Workouts HealthKit + registros manuales | La actividad sin workout puede no aparecer como sesion |
| Strain Performance | ScoreEngine + objetivo modulado por Recovery | Guia de bienestar, no riesgo de lesion |
| Cardio Load | Tiempo ponderado en zonas FC | Fallback por duracion cuando faltan zonas |
| Cardio Focus | Z1-Z2 / Z3-Z4 / Z5 | Requiere muestras de FC suficientes |
| HRR 1 min | FC al final y muestra 45-90 s post-workout | Protocolo, calor y postura cambian el valor |
| Fuerza | Tipo/duracion HealthKit + volumen manual | HealthKit no entrega series x reps x peso de forma general |
| Plantillas | SwiftData local | No sincroniza entre dispositivos sin backend/iCloud |

Recvel adopta la arquitectura informativa y densidad de Bevel, no su marca, textos ni assets. Conserva sus propios colores, componentes Liquid Glass, explicaciones cientificas y estados sin datos.


---

## Complemento julio 2026 — StressWatch / Stress / VO2 / Bio Age

Para no divergir del set principal (`COMPETITORS.md` + evidencia PubMed), el plan de producto y las citas cientificas estan en:

**[README_StressAndBio.md](README_StressAndBio.md)**

Puntos que este documento paralelo debe respetar:

1. Bevel **no calcula** VO2; lo toma de Apple Health (igual deberia Recvel).
2. Biological Age de competidores ≠ PhenoAge clinico (Levine, 9 labs).
3. StressWatch es la referencia mas clara de **bandas** (Great/Normal/Attention/Overload) sobre HRV+RHR vs baseline; Recvel usara SDNN de Apple, no RMSSD.
4. En codigo Recvel (julio 2026): Stress, query/tendencia VO2 y Bio Age cardiorrespiratoria beta ya estan implementados. Activacion fisiologica sigue separada; la calibracion en dispositivo real queda pendiente.
