# Stress, VO2 Max y Bio Age — investigacion y plan de producto

Documento canonico de investigacion, decisiones y estado de implementacion para **Stress**, **VO2 Max** y **Bio Age beta** en Home.

Ultima actualizacion de investigacion: **julio 2026**. Complementa (no reemplaza) [AI_CONTEXT.md](AI_CONTEXT.md), [COMPETITORS.md](COMPETITORS.md) y [README.md](README.md).

---

## 1. Estado actual en Recvel (codigo, julio 2026)

| Tema | En codigo hoy | En docs |
| --- | --- | --- |
| **Stress dedicado** | Implementado: score 0–100, cuatro bandas, confianza y drivers HRV/RHR contra baseline | Activacion intradia se conserva como contexto; no equivale a estres mental |
| **HRV** | SDNN diario desde HealthKit → Recovery | Evidencia HRV en AI_CONTEXT |
| **RHR** | FC en reposo → Recovery / activacion | Evidencia RHR en AI_CONTEXT |
| **VO2 max** | Implementado: query discreta, valor/fecha/fuente, Home y tendencia | Se presenta como estimacion de Apple, no laboratorio |
| **Bio Age** | Implementado con lentes separadas **Cardio · FRIEND beta** y **Sangre · PhenoAge** | RHR/sueno/pasos son contexto y no modifican anos; PhenoAge exige 9 analitos |

Archivos clave existentes:

- `Recvel/Services/HealthDataProvider.swift` — autorizacion y query de VO2; carga de activacion
- `Recvel/Services/HealthIntelligenceEngine.swift` — `StressEngine` y lente cardiorrespiratoria `BioAgeEngine`
- `Recvel/Services/BiomarkerEngine.swift` — catalogo, formula PhenoAge, unidades, confianza, factores y Clinical Records
- `Recvel/Services/ScoreEngine.swift` + `BaselineEngine.swift` — Recovery desde HRV/RHR/sueno/respiracion
- `Recvel/Views/HealthIntelligenceViews.swift` — cards y detalles Stress/VO2/Bio Age

### Auditoria independiente del plan anterior

1. **Acierto:** separar activacion por FC de estres emocional y exigir baseline personal.
2. **Correccion:** Apple Watch no ofrece HRV continua. Las muestras SDNN son oportunistas y espaciadas; una UI "en tiempo real" debe mostrar frescura y huecos, no interpolar certeza.
3. **Correccion:** no hay una ecuacion publicada que permita sumar VO2, RHR, sueno y pasos con pesos elegidos por producto y llamarlo edad biologica validada.
4. **Decision vigente:** Bio Age tiene dos relojes independientes. FRIEND usa exclusivamente VO2 para edad cardiorrespiratoria. PhenoAge usa exclusivamente edad cronologica y los nueve analitos publicados. Nunca se promedian ni se ponderan entre si.
5. **Transparencia:** los coeficientes y bandas de `StressEngine` son una heuristica Recvel version 1, inspirada en patrones de competidores, no el algoritmo de StressWatch/Bevel ni un dispositivo medico validado.

## Implementacion Bio Age vigente (15 julio 2026)

- `PhenoAgeEngine` implementa la ecuacion de Levine con albumina, creatinina, glucosa, log(PCR), linfocitos, VCM, RDW, fosfatasa alcalina, leucocitos y edad cronologica. Fuente primaria: [PLOS Medicine](https://journals.plos.org/plosmedicine/article?id=10.1371/journal.pmed.1002718).
- Unidades canonicas: albumina `g/L`, creatinina `umol/L`, glucosa `mmol/L`, PCR `mg/L`, linfocitos/RDW `%`, VCM `fL`, fosfatasa `U/L`, leucocitos `10^9/L`. El resolver acepta conversiones comunes `g/dL`, `mg/dL` y `K/uL` con tests deterministas.
- Un panel es valido solo con los nueve valores, todos positivos y con antiguedad maxima de seis meses. No hay imputacion.
- Confianza wearable alta requiere al menos 20 dias medidos de los ultimos 28. Laboratorio completo y reciente se marca alta; un panel parcial permanece faltante.
- Clinical Records/FHIR se autoriza solo al pulsar importar. Requiere `health-records`, permiso clinico separado y procesa JSON FHIR localmente. Fuente: [Apple Health Records](https://developer.apple.com/documentation/healthkit/accessing-health-records).
- La tarjeta de Home es ancha y la pantalla usa medio aro, particulas, selector de lente, factores de cuatro semanas y catalogo con detalle y alta manual. `Reduce Motion` produce un estado estatico completo.
- La pantalla dice explicitamente que no es una edad biologica clinica, prediccion de longevidad ni diagnostico.

---

## 2. Competidores (como lo muestran)

### 2.1 StressWatch (referencia de bandas)

Fuente primaria: [docs StressWatch — principio de medicion](https://docs.ideation.love/stresswatch/en/).

- Mide **estres fisico / presion corporal**, no diagnostica ansiedad ni “estres mental”.
- Senales: **HRV + FC en reposo** vs **baseline personal** historico.
- Apple Health expone **SDNN**. Recvel no debe describirla como RMSSD ni asumir que ambas escalas son intercambiables.
- Cuatro niveles (traduccion Recvel propuesta):

| StressWatch | Recvel (ES) | Idea fisiologica |
| --- | --- | --- |
| Excellent / Great | **Excelente** | HRV alta y RHR baja vs tu historial |
| Normal | **Normal** | Ambas cerca del baseline |
| Attention needed | **Atencion** | HRV baja **o** RHR alta |
| Pressure overload | **Sobrecarga** | HRV baja **y** RHR alta de forma marcada |

Actualizacion frecuente en su producto; en Recvel v1 el score diario + curva de activacion 24h basta (sin watchOS companion).

### 2.2 Bevel

Fuentes: [Key Bevel Terms](https://help.bevel.health/en/articles/11251073) · [Biological Age basics](https://www.bevel.health/blog/biological-age-the-basics) · [COMPETITORS.md](COMPETITORS.md).

- **Stress Score** 0–100 (mas bajo = mas relajado) desde FC + HRV, ajustando por movimiento; mapa a lo largo del dia.
- **Energy Bank**: recovery + sueno + strain + stress (no es el mismo que Stress).
- **VO2 Max**: **no lo calcula**; lee Apple Health y contextualiza.
- **Biological Age**: semanal; sueno, actividad, RHR, VO2, lifestyle y opcionalmente bloodwork; muestra **confianza** por completitud/frescura de datos.

### 2.3 WHOOP

- **Stress Monitor**: escala corta (0–3) en tiempo real, FC + HRV vs baseline; distingue activacion fisiologica de percepcion emocional ([Stress Monitor](https://www.whoop.com/us/en/thelocker/introducing-stress-monitor-a-new-way-to-monitor-manage-stress/)).
- **Healthspan / WHOOP Age**: VO2, RHR, consistencia de sueno, fuerza, etc., semanal.

### 2.4 Oura / Garmin / Athlytic (resumen)

- Oura: Daytime Stress vs Cumulative Stress (horizonte distinto).
- Garmin: Body Battery, HRV Status, VO2 + Training Status / Race Predictor.
- Athlytic Age: VO2 + recuperacion de FC en sesiones intensas.

Regla Recvel: inspiracion de **patron UX y honestidad**, no copia de algoritmos propietarios ni naming.

---

## 3. Evidencia cientifica (PubMed / PMC / sociedades)

### 3.1 HRV y estres / carga autonomica

**Bien respaldado (con matices):**

- HRV es biomarcador no invasivo de regulacion autonomica; parametros clasicos SDNN (variabilidad total) y RMSSD (parasimpatico corto plazo) estan estandarizados desde el Task Force ESC/NASPE 1996.
- Meta-analisis en medicos: RMSSD, SDNN, LF y LF/HF difieren entre periodos de estres vs recuperacion (tamano de efecto moderado; calidad de estudios solo moderada; **no** permite conclusiones clinicas de burnout).  
  Fuente: [Continuous HRV monitoring, stress and recovery in doctors — PMC12794872](https://pmc.ncbi.nlm.nih.gov/articles/PMC12794872/).
- Guias de medicina ocupacional 2024: HR/HRV utiles como indicadores de carga fisiologica; recomiendan SDNN, RMSSD, potencia LF/HF; minimo tipico ~5 min en laboratorio.  
  Fuente: [Guideline HR/HRV occupational medicine — J Occup Med Toxicol 2024](https://link.springer.com/article/10.1186/s12995-024-00414-9).
- Revision 2025–2026: HRV como biomarcador digital de rendimiento/resiliencia; HRV nocturna refleja carga alostatica acumulada; confusores: movimiento, sueno, enfermedad.  
  Fuente: [HRV dual-use digital biomarker — PMC12849089](https://pmc.ncbi.nlm.nih.gov/articles/PMC12849089/).
- Revision de funcion autonomica con HRV: uso en deporte (recuperacion/sobreentrenamiento) y en investigacion de estres/ansiedad, **sin** equivaler HRV a diagnostico psiquiatrico.  
  Fuente: [Assessment of autonomic function using HRV — PMC12085924](https://pmc.ncbi.nlm.nih.gov/articles/PMC12085924/).
- Una revision sistematica de wearables para estres/salud mental encontro que HRV aporta mas que FC media, pero tambien heterogeneidad de sensores, contextos y etiquetas; no valida una banda comercial concreta.  
  Fuente: [Wearables for mental health and stress — PMID 34065620](https://pubmed.ncbi.nlm.nih.gov/34065620/).
- Un estudio con ECG de Apple Watch mostro que features de HRV pueden discriminar una tarea de estres en condiciones controladas; esto demuestra factibilidad, no precision de Stress Recvel en vida diaria.  
  Fuente: [Apple Watch ECG and stress — PMID 37475772](https://pubmed.ncbi.nlm.nih.gov/37475772/).

**Limites criticos para UI:**

- La HRV **no distingue la causa** (entreno, cafeina, enfermedad, discusion, mal sueno).
- LF/HF como “balance simpatovagal” esta sobresimplificado (ver tambien AI_CONTEXT).
- Apple Watch entrega **SDNN** agregado; no RMSSD nativo. Recvel debe decirlo en copy.

**Frase de cautela (producto):**

> El indicador de Stress de Recvel estima **presion fisiologica** a partir de tu HRV (SDNN de Apple Health) y FC en reposo respecto a **tu** baseline. No mide estres emocional, ansiedad ni ninguna condicion de salud mental.

### 3.2 FC en reposo (RHR)

- RHR mas baja se asocia a menor mortalidad cardiovascular y por todas las causas a nivel poblacional; util como biomarcador de aptitud, no como termometro clinico dia a dia con el mismo rigor que HRV en ciencia del deporte.  
  Fuentes ya citadas en AI_CONTEXT: [RHR y mortalidad](https://pubmed.ncbi.nlm.nih.gov/24290115/) · [Fenland Study](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10174582/).

### 3.3 VO2 max estimado por Apple Watch

- VO2 max / cardiorespiratory fitness predice eventos CV y mortalidad (contexto epidemiologico; el wearable **estima**, no mide calorimetria).
- Apple documenta que Series 3+ guarda estimaciones tras caminata, carrera o senderismo exterior con GPS/senal suficientes; el rango estimable es 14–60 ml/kg/min y no se genera necesariamente en cada workout.  
  Fuente: [Apple Developer — `vo2Max`](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/vo2max).
- Validacion Apple Watch vs calorimetria indirecta (cinta, protocolo Astrand modificado, n=30): subestimacion media ~6.1 ml/kg/min; MAPE ~13.3%; limites de acuerdo amplios.  
  Fuente: [Lambe et al., PLOS ONE 2025 — PubMed 40373042](https://pubmed.ncbi.nlm.nih.gov/40373042/) · [PLOS ONE full text](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0323741).
- Apple Watch Series 7: MAPE ~15.8%, ICC pobre (~0.47); mejor en personas con buena forma.  
  Fuente: [JMIR Biomed Eng 2024](https://biomedeng.jmir.org/2024/1/e59459).
- Series 10 (2026): subestimacion ~6.3 ml/kg/min; MAPE ~13%; utilidad mas poblacional que individual.  
  Fuente: [Mayo Clinic Proceedings Digit Health 2026](https://doi.org/10.1016/j.mcpdig.2026.100357).

**Producto:** mostrar valor Apple + **tendencia**; nunca “VO2 de laboratorio”. Bevel hace lo mismo.

La relevancia no depende de prometer longevidad individual: un meta-analisis de fitness cardiorrespiratorio **estimado** encontro una asociacion de menor mortalidad por cada MET adicional, pero es evidencia poblacional y observacional, no una prediccion personal de Recvel. Fuente: [eCRF y mortalidad — PMID 34225102](https://pubmed.ncbi.nlm.nih.gov/34225102/).

### 3.4 Edad biologica — que SI y que NO

#### Lo clinicamente establecido (y que Recvel **no** puede calcular sin labs)

- **Phenotypic Age (PhenoAge)** de Levine et al.: edad fenotipica a partir de **edad cronologica + 9 biomarcadores de sangre** (albumina, creatinina, glucosa, CRP, % linfocitos, MCV, RDW, fosfatasa alcalina, leucocitos). Predice morbimortalidad mejor que la edad sola en NHANES.  
  Fuentes: [Liu/Levine et al., PLOS Medicine 2018 — e1002718](https://journals.plos.org/plosmedicine/article?id=10.1371/journal.pmed.1002718) · marco epigenetic DNAm PhenoAge [Levine et al., Aging 2018 — PMID 29676998](https://pubmed.ncbi.nlm.nih.gov/29676998/).
- Sin panel de sangre, **no** se debe llamar al score de Recvel “PhenoAge” ni “edad biologica clinica”.

#### Lo que SI respalda un score wellness wearable (asociaciones, no diagnostico)

- Senales de wearables (VO2 estimado, RHR, actividad) se correlacionan con aceleracion de relojes epigeneticos / PCPhenoAge en estudios pequenos.  
  Fuente: [Wearable-ome meets epigenome — bioRxiv 2023](https://doi.org/10.1101/2023.04.11.536462).
- Relojes de envejecimiento basados en PPG/actividad (p. ej. PpgAge) se asocian a enfermedad y conducta **independiente** en parte de VO2; usan datos tipo Apple Watch a escala.  
  Fuente: [Wearable-based aging clock — PMC12537950](https://pmc.ncbi.nlm.nih.gov/articles/PMC12537950/).
- CRF / VO2max se asocia con PhenoAge / aceleracion fenotipica en NHANES (poblacion joven).  
  Fuente: [CRF and phenotypic age — NHANES — PMC12286991](https://pmc.ncbi.nlm.nih.gov/articles/PMC12286991/).
- “Cardio Age” derivado de wearables se asocia a sueno, pasos y cambios de RHR/VO2 en el tiempo (estudio 2026, n=442; preimpresion / preprint — citar con cautela).  
  Fuente: [Wearable-derived cardiovascular fitness age — 2026](https://doi.org/10.64898/2026.03.20.26348891).
- Regularidad de sueno (SRI) predice mortalidad mejor que la sola duracion (UK Biobank) — ya en AI_CONTEXT; factor valido para Bio Age wellness.  
  Fuente: [Windred et al., SLEEP 2024 — PMC10782501](https://pmc.ncbi.nlm.nih.gov/articles/PMC10782501/).

**Conclusion de producto revisada:** las asociaciones anteriores justifican mostrar los biomarcadores y sus tendencias, pero **no justifican inventar pesos para convertirlos en anos**. La v1 transforma VO2 en una edad equivalente respecto a medianas por edad/sexo de FRIEND. RHR, sueno y actividad aparecen como contexto sin alterar el numero. No implementar PhenoAge sin labs ni afirmar que calculamos la edad biologica real.

---

## 4. Diseno implementado en Recvel

### 4.1 StressEngine (nuevo)

**Entradas (ya en dispositivo):**

- `snapshot.hrv` (SDNN ms), `snapshot.restingHeartRate`
- Historial 30d → `BaselineEngine.deviation` / mediana
- La curva `activation` 24h se muestra aparte y **no entra al score**, porque actualmente no filtra movimiento ni workouts con suficiente rigor.

**Salida:**

```text
StressAssessment {
  level: excelente | normal | atencion | sobrecarga | sinDatos
  score0to100   // opcional para gauge (alto = mas presion)
  confidence: baja | media | alta
  summary: String  // ES, no clinico
  drivers: [HRV, RHR, ...]  // vs baseline personal
}
```

**Heuristica de bandas (personal, no poblacional):**

1. Filtrar a los 30 dias anteriores y usar mediana robusta por senal.
2. Convertir el cambio porcentual favorable/adverso de HRV y RHR a una presion centrada en 45.
3. Bandas v1: 0–30 Excelente, 31–55 Normal, 56–75 Atencion, 76–100 Sobrecarga.
4. Exigir 3 dias comparables para emitir numero; con menos datos se muestra `Sin datos`.
5. Confianza alta requiere ambas senales y 21 dias; media requiere ambas y 7; el resto es baja.

Los multiplicadores (HRV 220, RHR 260) y cortes son **parametros de producto no validados**. Deben versionarse y calibrarse contra datos etiquetados antes de cualquier claim de precision.

Misma filosofia StressWatch + honestidad SDNN de AI_CONTEXT.

**Presentacion: "calm score" (actualizado julio 2026).** El indice interno del motor sigue siendo "mas bajo = mas relajado" (0 = calma, 100 = sobrecarga) y NO cambio. Pero la UI antes mostraba ese indice crudo como "0/100" junto a la etiqueta "Excelente", lo que se leia como una calificacion reprobatoria contradictoria. Ahora la capa de presentacion (`StressEngine.presentation(for:)`, funcion pura) invierte el numero a un **calm score** = `100 - indice`: 100 = Excelente, anillo lleno = bien, etiqueta pequena "CALMA" en vez de "/100". Consistente con Recovery/Sleep (lleno = bueno). El test `testStressBandsUsePersonalHRVAndRestingHeartRateBaseline` sigue verde porque opera sobre el `level`/`score` interno; se agrego `testStressPresentationInvertsIndexToCalmScore`.

### 4.6 Emotion log + hints de posibles factores (nuevo, julio 2026)

**Grafica de activacion → barras.** La curva 24h del detalle paso de area/linea a **barras por hora coloreadas por intensidad** (patron StressWatch/Garmin): `StressEngine.barIntensity(_ value:)` clasifica cada `ActivationPoint` (0...3) en baja (<0.8, verde), media (<1.8, ambar) o alta (naranja). **Sigue sin entrar al score** y el pie de texto lo declara explicitamente ("Activacion por frecuencia cardiaca. No entra en el indice de estres.").

**Emotion log (`@Model EmotionLog`).** Multi-check-in auto-reportado en el detalle de stress (tope suave **6/dia**, contador `n/6`): cada “Anadir registro” inserta un `EmotionLog` con timestamp (ya no upsert 1/dia). Grid de `StressEmotion` + nota opcional; lista del dia con hora; grafica “Emociones de hoy” (hora × valencia −2…+2) y promedio. Guarda `linkedStressScore` = indice **interno** del motor. Independiente del ayuno (`FastingFeelingLog` / `FastingMood`, tambien multi hasta 6 por sesion). Copy wellness: autoconocimiento, no diagnostico.

**Hints (`StressEngine.stressHints(...)` + `emotionDayAdvice`).** Cruzan SOLO registros del usuario con senales fisiologicas: alcohol/cafeina/enfermedad/viaje del `HabitLog`, sueno corto, y **promedio del dia** de emociones (`emotionDayAdvice`: tenso → respiracion/caminata/hidratacion; positivo → refuerzo). Regla dura: **jamas inferir emociones desde HRV**. Tests: `testStressHintsReflectSelfReportedEmotionWithoutInference`, `testEmotionDayAdviceUsesAverageNotHRV`, `testEmotionDayCapConstantIsSix`. Respiracion 1 min opcional. Copy de asociacion, nunca causal ni diagnostico.

### 4.2 VO2 Max (HealthKit → UI)

1. Query `HKQuantityTypeIdentifier.vo2Max` en `HealthDataProvider` (ml/(kg·min)).
2. Campo `vo2Max: Double?` (+ fecha del sample reciente) en `DailyHealthSnapshot`.
3. Card Home: valor, tendencia 30–90d, “Fuente: Apple Health”.
4. Para fechas sin muestra nueva, Home usa la ultima muestra disponible dentro del historial cargado; si no existe ninguna en 30 dias, consulta una sola muestra de fallback hasta 180 dias y conserva/muestra su fecha real.

### 4.3 BioAgeEngine (edad cardiorrespiratoria beta)

**Entradas:**

- Edad cronologica (`NutritionProfile.birthDate`)
- Sexo opcional
- VO2 (obligatorio) y tabla de medianas FRIEND por edad/sexo
- RHR, consistencia de sueno y pasos solo como factores contextuales

**Salida:**

```text
BioAgeEstimate {
  chronologicalYears
  estimatedYears
  deltaYears          // estimado - cronologico (negativo = "mas joven" en la heuristica)
  confidence
  factors: [...]      // contexto; no altera anos en v1
}
```

Sin edad, sexo de referencia o VO2 no se emite un numero. La confianza maxima actual es **media**, porque Apple Watch estima VO2 y Recvel todavia no tiene validacion longitudinal propia. La interpolacion usa medianas FRIEND de treadmill en puntos medios por decada y limita el resultado a 20–89 anos.

### 4.4 UI Home

Orden sugerido (mantener narrativa, no grid 2x2):

1. Recovery hero  
2. Rail Sleep | Strain | Energy  
3. Plan de hoy  
4. **Stress** (banda grande + 2 drivers) → detalle; activacion 24h puede vivir **dentro** del detalle para no duplicar  
5. **VO2 Max**  
6. **Bio Age** (disclaimer + confianza)  
7. Factores Recovery / tendencias  

Detalle: `StressDetailView`, `VO2DetailView`, `BioAgeDetailView` en `HealthIntelligenceViews.swift`, con toolbar Liquid Glass, metodologia, frescura y cautelas.

### 4.5 Pruebas

- Unit tests de umbrales Stress y Bio Age con/sin VO2/edad.
- UI identifiers en cards.
- Build verde.

---

### 4.7 Bio Age — replica 1:1 de la referencia Bevel (nuevo, julio 2026)

`Recvel/Views/BioAgeProViews.swift` replica el hero de Bio Age de Bevel usando
`Bevel_references/BioAge_revel.mp4` y `Bevel_references/BioAgeScreenBevel.png`.
Hay dos capas de fidelidad: geometria y lenguaje visual.

**Geometria** (resuelta con el circulo que pasa por los 3 puntos medidos en el
frame de referencia; todas las constantes son proporciones del ancho `W`):

| Elemento | Offset desde el borde superior del hero |
|---|---|
| Titulo "Edad biologica" (24pt bold SF) | `0.071 W` |
| Subtitulo "Al <fecha>" (15pt) | `0.136 W` |
| Numero grande (64pt bold SF) | `0.321 W` |
| Etiquetas de rango rotadas (valor ±5) | angulo ±45° · radio `1.18 R` |
| Punto marcador blanco con halo | `0.619 W` |
| Valor exacto (17pt semibold) | `0.686 W` |

Dial: centro del circulo **arriba** del numero en `0.147 W`, radio `R = 0.472 W`.

**Lenguaje visual** (muestreado del PNG de referencia — esto fue lo que hizo la
diferencia entre "parecido" y 1:1):

- **Paleta 100% neutra.** Todo es gris (blanco sobre `#1D1F22 → #101113`); en
  esta superficie NO se usa el verde de la app. El unico acento es el naranja
  de estados tipo "Fair/High" (`BioAgeInk.warn`).
- **Disco elevado**: el interior del circulo es MAS CLARO que el fondo (radial
  blanca 8.5% → 1.5% cargada hacia arriba), como superficie flotante.
- **Surco de ticks**: los ticks no flotan — viven dentro de una banda circular
  OSCURA (`0.036 W` de grosor, negro 30%) que recorre los **360 grados** y sale
  de pantalla por arriba. Ticks cada 1.6°, brillo pseudoaleatorio 7-29%.
- **Etiquetas rotadas tangencialmente** (±45°), blanco 42%, fuera de la banda.
- **Bokeh**: circulos blancos desenfocados (gradiente radial) que derivan
  lentamente + estrellas pequenas que titilan (`BioAgeBokehField`, TimelineView
  a 20 fps, estatico con Reduce Motion).
- **Tipografia SF Pro estandar** (sin `design: .rounded`) en todo el hero.
- **Sin titulo en el nav**: como Bevel, solo los botones circulares flotantes
  (atras y "...", ambos en blanco — sin el tint verde global).
- **Full-bleed**: el hero no vive en tarjeta; el fondo (`BioAgeBackdrop`) es de
  pantalla completa con dos brillos de nebulosa sutiles.

**Animaciones** (del video de referencia): particulas blancas que convergen y
revelan el numero (1.5 s, easing cubico), barrido de entrada de los ticks desde
el vertice inferior hacia arriba (spring), numero con fade + scale 0.92→1 y
`contentTransition(.numericText())`, bokeh en deriva continua. Todo respeta
Reduce Motion (estado final estatico).

**Polvo estelar (`StardustField`, en `GlassComponents.swift`)**: verificado con
diffs de frames del video a 10 fps — en Bevel, TODA la pantalla tiene motas
diminutas que derivan lentamente y titilan, no un fondo estatico. El componente
es reutilizable: cada mota tiene direccion propia (angulo aureo), velocidad de
4-14 pt/s, titileo sinusoidal y wrap en los bordes; 1 de cada 11 es una mota
grande con halo. Canvas + TimelineView a 30 fps; con Reduce Motion queda
estatico. Esta activo en: Bio Age (detalle, 110 motas + entrypoint, 16),
`DetailScaffold` (Sueno/Recovery/Strain/Energia, 70), 
`IntelligenceDetailScaffold` (Stress/VO2, 70) y `TonightDetailView` (70).
La prueba de movimiento esta en el UI test: captura `bio-age-pro-hero` y
`bio-age-pro-hero-motion` con 1.2 s de separacion — el diff entre ambas debe
mostrar motas desplazadas (si el campo fuera estatico serian identicas).

**Resto de la pantalla en la misma linea**: filas "Factores de edad" al estilo
"Other Biomarkers" de Bevel (titulo blanco 17pt, palabra de estado coloreada +
valor secundario, sparkline a la derecha con punto final y base punteada,
tarjetas con radio 16). Nuestro contexto extra (lente, delta, confianza,
resumen, frescura) va DEBAJO del bloque copiado, en gris neutro.

El entrypoint (`BioAgeHomeCard`) reusa `BioAgeTickDial` en modo `compact`
(sin disco ni etiquetas) sobre 104 pt, tarjeta neutra sin tint.

**Verificacion visual:** el UI test `testJournalProAndBioAgeProSurfaces`
captura `bio-age-pro-hero` (detalle) y `bio-age-entry-card` (entrypoint):

```bash
xcodebuild -project Recvel.xcodeproj -scheme Recvel \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:RecvelUITests/RecvelUITests/testJournalProAndBioAgeProSurfaces \
  -resultBundlePath /tmp/bio.xcresult test
xcrun xcresulttool export attachments --path /tmp/bio.xcresult --output-path /tmp/bio_att
```

### 4.8 Metricas principales estilo Bevel (nuevo, julio 2026)

Analisis de `Bevel_references/mainmetrics_bevel.mp4` (2:23, incluye las pantallas
de Resources). Bevel repite UN patron en Sleep, Recovery, Strain y Stress; lo
replicamos como componente unico y llenamos los huecos que teniamos.

#### 4.8.1 `MetricDetailView` — el patron repetido

`Recvel/Views/DetailViews.swift`. Estructura identica a Bevel:
valor grande + estado + rango personal · chips de metricas hermanas (saltar sin
volver atras) · grafico con banda personal, promedio y punto final · selector
30D/3M/6M/1Y · tabla "Analisis de tendencia" · "Recursos" educativos.

Se alimenta de `MetricDescriptor` (modelo) y un closure de series, asi cada
seccion declara sus metricas sin duplicar UI. Motor: `MetricTrendEngine`
(`HealthIntelligenceEngine.swift`) compara la mediana de cada ventana
(3/7/14/30/90 d) contra la ventana previa de la misma longitud; `direction()`
interpreta el signo segun `higherIsBetter` y aplica tolerancia para no llamar
"tendencia" al ruido.

Catalogos: `SleepMetricCatalog` y `RecoveryMetricCatalog`. Cada card de Sleep y
Recovery abre su detalle (`detail.sleep.metric.*`, `detail.recovery.metric.*`),
igual que en Bevel.

**Nota de cobertura (honestidad).** `HealthDataProvider.refresh()` lee **30 dias**
de Apple Health (`stride(from: -29, through: 0)`), pero el selector ofrece
30D/3M/6M/1Y como Bevel. Al elegir una ventana mas larga, `coverageNote` avisa
que solo hay 30 dias leidos y que no es un hueco en el historial del usuario.
Si algun dia se amplia la ventana del provider, esa nota desaparece sola.

#### 4.8.2 Sleep Bank (`SleepBankEngine`)

Ventana rodante de **14 dias** contra una meta ajustable (`sleepGoalHours`,
default 8 h, editable desde la tarjeta).

Evidencia: la deuda de sueno se mide convencionalmente en ventanas de 7-14 dias;
14 captura el patron semanal completo con fin de semana. Reglas de copy:

- Nunca decimos que "saldaste" la deuda. Tras una semana de restriccion, 2-3
  noches de recuperacion restauran la alerta subjetiva y parte del rendimiento,
  pero el tiempo de reaccion y algunos marcadores metabolicos tardan mas.
- El sueno de fin de semana compensa **parcialmente** la deuda entre semana; no
  restaura del todo la funcion cognitiva ni la salud metabolica.
- Con menos de 3 noches (`hasEnoughData`) no afirmamos un balance: "Calibrando".

#### 4.8.3 Coaching de sueno (`SleepCoachingEngine`)

Cada `SleepCoachingTip` lleva un campo `evidence` OBLIGATORIO que la UI muestra
plegable: no damos una instruccion sin decir de donde sale. Reglas y sus fuentes:

| Regla | Disparador | Evidencia citada |
|---|---|---|
| Duracion corta | < 7 h | Consenso AASM/SRS: 7 h+ para adultos |
| Deuda acumulada | balance < -3 h | Van Dongen et al., Sleep 2003 (restriccion cronica acumula deficit aunque la somnolencia subjetiva se estabilice) |
| Consistencia | variabilidad > 60 min | Huang & Redline, Diabetes Care 2019 |
| Eficiencia baja | < 85% | CBT-I (control de estimulos), primera linea AASM |
| Profundo bajo | < 10% de la noche | Ondas lentas tipicamente 13-23%; alcohol lo suprime (Ebrahim, ACER 2013) |
| Refuerzo positivo | score >= 85 sin otros flags | Phillips et al., Sci Rep 2017 (regularidad predice calidad) |

#### 4.8.4 SpO2 y temperatura de muneca en Recovery

`wristTemperature` es campo nuevo en `DailyHealthSnapshot`, leido de
`HKQuantityTypeIdentifier.appleSleepingWristTemperature`.

**Decision documentada: la temperatura de muneca va en Recovery, NO en Stress.**
El usuario pregunto si podia detectar episodios de ansiedad. La respuesta
investigada es que **no**:

- Apple SOLO registra esta senal **mientras duermes**. No existe lectura diurna
  continua, asi que es imposible detectar un episodio agudo con ella.
- Los estudios que detectan estres por temperatura usan sensores de
  investigacion (Empatica E4) con registro continuo, y aun asi es la senal con
  **menos validacion**: la relacion entre lo que mide un termistor de muneca y
  el estado fisiologico es indirecta y muy dependiente del contexto (ejercicio,
  ambiente, alcohol, ciclo menstrual) — exactamente la objecion del usuario.
- Bevel tampoco la usa en Stress: la pone en Recovery.

Donde SI tiene evidencia (y como la enmarcamos): deteccion pre-sintomatica de
enfermedad — una desviacion > 0.5 °C sobre el baseline personal sostenida varias
noches precedio enfermedad confirmada 1-2 dias antes en ~75% de los casos
(estudio Fitbit, 47.000 participantes); y fase lutea del ciclo menstrual.

SpO2: el recurso educativo documenta el sesgo de la oximetria de pulso en piel
mas oscura (Sjoding et al., NEJM 2020), presente tambien en oximetros clinicos.

#### 4.8.5 Clasificacion de aptitud (`FitnessClassificationEngine`)

"Tipo de entrenamiento" en Strain: Atleta / Alto rendimiento / Buena forma /
Promedio / Bajo el promedio / Sedentario, con pantalla de detalle que explica
POR QUE caes ahi (percentil, escala completa, distancia al siguiente escalon).

Fuente: Kaminsky et al., "Reference Standards for Cardiorespiratory Fitness...
Treadmill", Mayo Clin Proc 2015 — tabla completa **verificada contra la fuente
primaria** (PMC4919021). N = 4.611 hombres, 3.172 mujeres. Percentiles
publicados: 5, 10, 25, 50, 75, 90, 95 por decada y sexo; interpolamos entre
ellos y no extrapolamos fuera de 20-79 anos.

Honestidad obligatoria en la UI: FRIEND reporta los percentiles pero **NO define
categorias**; los nombres son decision de producto. Ademas FRIEND mide con
ergoespirometria maxima y Apple Watch **estima** desde caminatas/carreras, con
error mayor: por eso la confianza nunca es alta con una sola lectura.

> **Bug corregido (julio 2026).** Las medianas FRIEND de `BioAgeEngine` estaban
> sesgadas **1.5-3.8 ml/kg/min por debajo** de lo publicado, lo que producia
> edades biologicas artificialmente jovenes. Se corrigieron contra la fuente
> primaria (PMC4919021) y ademas:
>
> - El tope inferior era `>=`, asi que un VO2 que IGUALABA la mediana de la
>   decada mas joven caia en el tope y devolvia 20 en vez de interpolar. Ahora
>   la comparacion es estricta.
> - El tope superior extrapolaba hasta 89 anos; FRIEND no publica datos sobre
>   79, asi que ahora no extrapolamos fuera del rango publicado.
>
> Impacto en la edad equivalente de un hombre (antes -> ahora):
>
> | VO2 max | Antes | Ahora |
> |---|---|---|
> | 46.5 | 20.0 | 27.7 |
> | 42.0 | 31.6 | 35.9 |
> | 38.0 | 38.9 | 44.6 |
> | 33.0 | 48.8 | 54.2 |
> | 28.0 | 57.6 | 65.5 |
> | 25.0 | 64.1 | 73.4 |
>
> Guardias en `RecvelTests/EngineTests.swift`:
> `testBioAgeReferenceMatchesPublishedFriendMedians` verifica que un VO2 igual a
> la mediana de una decada devuelva su edad central (fallaria si alguien vuelve
> a tocar la tabla), y `testBioAgeBetaMapsVO2ToPublishedCardiorespiratoryReference`
> fija el caso 46.5 -> 27.68.

#### 4.8.6 Respiracion guiada (entrypoint permanente)

`BreathingExerciseView` YA existia pero solo era alcanzable si aparecia un hint
con `offersBreathing: true` (dormir poco o registrar una emocion tensa), asi que
en la practica quedaba escondido. Ahora tiene entrypoint permanente en
`StressDetailView` (`detail.stress.breathingEntry`).

Se reescribio estilo Meditopia: 4 tecnicas con duracion 1/3/5 min, circulo guia
con progreso, conteo de ciclos, y **cada tecnica muestra su evidencia y la
FUERZA de esa evidencia** (no las vendemos todas por igual):

| Tecnica | Fuerza | Evidencia |
|---|---|---|
| Suspiro ciclico (default) | Ensayo aleatorizado | Balban et al., Cell Rep Med 2023: 111 adultos, 28 dias, 5 min/dia. Mayor mejora del animo positivo y mayor reduccion de la frecuencia respiratoria en reposo; **supero a la meditacion mindfulness** y a las otras tecnicas |
| Resonancia (6 rpm) | Moderada | Maximiza la arritmia sinusal respiratoria y la HRV a corto plazo (Lehrer & Gevirtz, Front Psychol 2014); efecto sostenido en ansiedad menos establecido |
| Cuadrada (4-4-4-4) | Limitada | En el mismo ensayo mejoro el animo menos que el suspiro ciclico; su ventaja es la simplicidad |
| 4-7-8 | Preliminar | Estudios pequenos y de baja calidad metodologica |

Todo local: sin cuenta, sin red, sin permisos. Respeta Reduce Motion (guia por
texto en vez de circulo animado).

**Dos accesos con intencion distinta:**

- Desde un **hint** de emocion tensa o sueno corto: la sesion **arranca sola**
  (`autoStart: true`). La intencion ya es empezar, no configurar.
- Desde el **entrypoint permanente** de "Herramientas": abre el selector de
  tecnica y duracion.

> **Bug de SwiftUI corregido.** La primera version usaba
> `.sheet(isPresented: $showBreathing)` con un `@State` aparte para `autoStart`.
> El sheet leia el valor del ciclo ANTERIOR, asi que el hint siempre abria el
> selector en vez de arrancar. Se refactorizo a `.sheet(item: $breathingRequest)`
> con un wrapper `BreathingRequest` que lleva `autoStart` consigo: el item y su
> parametro viajan juntos, sin condicion de carrera. Lo cazo el UI test
> `testStressEmotionLoggingFlow`.

#### 4.8.7 Bugs encontrados en autorevision (julio 2026)

Tres defectos detectados revisando el codigo de esta entrega, todos corregidos:

1. **Sleep Bank mostraba dos numeros distintos.** La tarjeta usa la ventana
   rodante de 14 dias del engine, pero la serie del chip acumulaba TODO el
   historial. Con 30 dias de datos la diferencia llegaba a **16 h** (tarjeta
   -4 h vs chip -20 h). Ahora la serie calcula el balance rodante de 14 dias en
   cada fecha, asi el ultimo punto coincide con el numero grande. Guardia:
   `testSleepBankRollingWindowMatchesCardValue`.

2. **La card de tendencia de Recovery usaba el futuro y fabricaba ceros.**
   Calculaba el score con `history: orderedWeek` completo, es decir usando dias
   POSTERIORES para el baseline de un dia pasado, y aplicaba `?? 0` cuando no
   habia score — inyectando un 0 falso en la grafica, contra la regla de no
   inventar datos. Ademas divergia de la serie del detalle. Unificado: ambos
   usan solo dias anteriores y omiten los dias sin score.

3. **Crash potencial en `MetricDetailView`.** `descriptors[0]` revienta con un
   catalogo vacio. Sustituido por `descriptors.first ?? .unavailable`.

#### 4.8.8 Cobertura de pruebas

Unit (`RecvelTests/EngineTests.swift`): Sleep Bank (deuda, superavit, ventana,
datos insuficientes), clasificacion FRIEND (percentiles publicados, se niega a
adivinar sin edad/sexo/VO2 o fuera de 20-79, confianza, siguiente escalon),
MetricTrendEngine (ventana vs previa, nil sin ambas, direccion con
`higherIsBetter`), coaching (duracion corta, deuda, refuerzo positivo).

UI (`RecvelUITests/RecvelUITests.swift`):
`testSleepMetricCardsOpenMetricDetail`, `testSleepBankAndCoachingAreVisible`,
`testRecoveryExposesOxygenAndWristTemperature`,
`testStressHasPermanentBreathingEntrypoint`.

## 5. Checklist de implementacion

- [x] Leer VO2 Max de HealthKit → `DailyHealthSnapshot` + historial
- [x] `StressEngine` + bandas ES + confianza
- [x] `BioAgeEngine` cardiorrespiratorio + factores contextuales + disclaimer
- [x] Secciones Home + DetailViews Liquid Glass
- [x] Unit tests deterministas y UI identifiers
- [x] Corregir docs que decian “VO2 ya se lee” antes de existir query
- [ ] Validar muestras y autorizacion en Apple Watch/iPhone real
- [ ] Calibrar Stress v2 con dataset etiquetado y protocolo predefinido
- [ ] Evaluar un reloj biologico publicado solo si sus inputs, licencia y validacion encajan

---

## 6. Mapa de fuentes (URLs)

| Tema | Fuente |
| --- | --- |
| StressWatch principio | https://docs.ideation.love/stresswatch/en/ |
| StressWatch overload | https://docs.ideation.love/stresswatch/en/principle/when-will-stresswatch-prompt-stress-overload.html |
| Bevel Stress / VO2 / Bio Age | https://help.bevel.health/en/articles/11251073 |
| Bevel Bio Age basics | https://www.bevel.health/blog/biological-age-the-basics |
| WHOOP Stress Monitor | https://www.whoop.com/us/en/thelocker/introducing-stress-monitor-a-new-way-to-monitor-manage-stress/ |
| HRV medicos meta-analisis | https://pmc.ncbi.nlm.nih.gov/articles/PMC12794872/ |
| HRV biomarcador digital 2026 | https://pmc.ncbi.nlm.nih.gov/articles/PMC12849089/ |
| HRV autonomico review | https://pmc.ncbi.nlm.nih.gov/articles/PMC12085924/ |
| Guia ocupacional HR/HRV | https://link.springer.com/article/10.1186/s12995-024-00414-9 |
| Apple Watch VO2 PLOS ONE | https://pubmed.ncbi.nlm.nih.gov/40373042/ |
| Apple Watch VO2 JMIR | https://biomedeng.jmir.org/2024/1/e59459 |
| Apple HealthKit VO2 oficial | https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/vo2max |
| FRIEND referencias VO2 por edad/sexo | https://pmc.ncbi.nlm.nih.gov/articles/PMC4919021/ |
| eCRF y mortalidad, meta-analisis | https://pubmed.ncbi.nlm.nih.gov/34225102/ |
| Apple Watch ECG y estres | https://pubmed.ncbi.nlm.nih.gov/37475772/ |
| Wearables, salud mental y estres | https://pubmed.ncbi.nlm.nih.gov/34065620/ |
| PhenoAge NHANES | https://journals.plos.org/plosmedicine/article?id=10.1371/journal.pmed.1002718 |
| DNAm PhenoAge | https://pubmed.ncbi.nlm.nih.gov/29676998/ |
| Wearable aging clock | https://pmc.ncbi.nlm.nih.gov/articles/PMC12537950/ |
| CRF ↔ PhenoAge NHANES | https://pmc.ncbi.nlm.nih.gov/articles/PMC12286991/ |
| Wearable ↔ epigenoma | https://doi.org/10.1101/2023.04.11.536462 |
| Sleep regularity UK Biobank | https://pmc.ncbi.nlm.nih.gov/articles/PMC10782501/ |

---

## 7. Relacion con otros documentos

| Documento | Relacion |
| --- | --- |
| [AI_CONTEXT.md](AI_CONTEXT.md) | Contrato operativo; evidencia HRV/VO2/estres; **complementado** con seccion Stress/Bio Age |
| [COMPETITORS.md](COMPETITORS.md) | Matriz Bevel/WHOOP; **complementado** con StressWatch |
| [README.md](README.md) | Vision y backlog; **complementado** y corregido VO2 |
| [HANDOFF.md](HANDOFF.md) | Mapa de docs; apunta a este archivo |
