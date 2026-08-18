# Investigación: Datos para Plan de Nutrición Científico (IA)

**Fecha:** 2026-08-13
**Propósito:** Definir qué datos debe recolectar el cuestionario del asistente de plan de nutrición con Gemini, basándose SOLO en evidencia científica verificada.

**Fuentes:** PubMed/NCBI, ISSN Position Stands (2015–2021), Academy of Nutrition and Dietetics, ACSM, IOC RED-S Consensus 2018, WHO Healthy Diet, IOM DRI 2005, NEJM, JAMA, Examine.com.

---

## 1. Datos que YA tiene la app (NO preguntar de nuevo)

| Dato | Fuente en app |
|---|---|
| Peso, altura, edad, sexo | `NutritionProfile` |
| Objetivo (perder grasa, músculo, etc.) | `NutritionProfile.goal` |
| Entrenamientos/semana | `NutritionProfile.weeklyWorkouts` |
| Estilo de dieta (vegana/vegetariana/flexible) | `NutritionProfile.dietStyle` |
| Alergias, alimentos que no gustan | `NutritionProfile` |
| Comidas por día | `NutritionProfile.mealsPerDay` |
| Sueño, recuperación, strain | `DailyScoreRecord` / HealthKit |
| Pasos diarios | HealthKit `stepCount` |
| % grasa corporal / masa magra | HealthKit `bodyFatPercentage` / `leanBodyMass` (si el wearable lo reporta) |
| Energía activa | HealthKit `activeEnergyBurned` |
| Agua y cafeína registrada | HealthKit `dietaryWater` / `dietaryCaffeine` |
| Historial de comidas | `MealLog` |

---

## 2. Datos que SÍ debe preguntar el cuestionario

### 🔴 Prioridad 1 — Seguridad (Paso "Tu salud")

**Embarazo/lactancia** (solo si sexo = femenino)
- Proteína ≥1.7 g/kg/día en embarazo/lactancia (evidencia IAAO). Contraindica déficit calórico agresivo.
- *Ref: Examine.com Protein Guide; IOM RDA*

**Condiciones médicas** (diabetes/prediabetes, hipertensión, enfermedad renal, celiaquía, tiroides)
- Diabetes → consenso de nutrición terapéutica (Evert et al., *Diabetes Care* 2019, PMID 31000505)
- Hipertensión → DASH + sodio bajo reduce PAS hasta 11.5 mmHg (DASH-Sodium, *NEJM* 2001, PMID 11136953)
- Enfermedad renal → proteína alta NO aplica sin supervisión (WHO 2026)
- *Estas condiciones activan disclaimer + ajustes del plan, no bloquean.*

**Medicamentos** (warfarina, levotiroxina, metformina, estatinas)
- Warfarina → vitamina K (verduras verdes) CONSISTENTE (PMID 27693910)
- Levotiroxina → en ayunas, lejos de café/calcio/hierro (PMID 19942153)
- Metformina crónica → riesgo deficiencia B12 (PMID 26900641)
- Estatinas → evitar toronja (PMID 28414144)

**Historia de TCA + regularidad menstrual** (mujeres)
- Baja disponibilidad energética → disfunción menstrual, pérdida ósea (IOC RED-S 2018, PMID 29773536)
- La amenorrea/ciclo irregular es señal de alarma → no prescribir déficit agresivo

**Cribado de TCA (pantalla propia, no un toggle)**
- Un sí/no de “historia de TCA” no cribaba nada. La Academy SOP 2022 (peso adulto) pide documentar historia, atracones, restricción, purga y ejercicio excesivo **antes** de un plan de pérdida de peso.
- **SCOFF** (5 ítems sí/no, corte ≥2): instrumento breve más usado en primaria (Morgan, Reid, Lacey, *BMJ* 1999, PMID 10582927). Meta-análisis: Se 0.86 / Sp 0.83 (Kutz et al., *JGIM* 2020). Versión española: Se 97.7% / Sp 94.4% (García-Campayo et al., *J Psychosom Res* 2005, PMID 16185998). **No diagnostica**; un positivo cambia el plan (sin déficit agresivo) y pide valoración profesional.
- El SCOFF se diseñó antes del BED en DSM-5 y **cubre mal el atracón**. Por eso se añade frecuencia: nunca / menos de semanal / semanal o más (umbral DSM-5: ≥1 episodio/semana × 3 meses). Si es semanal, la restricción precipita más atracones: primero regularizar comidas.
- Ejercicio para compensar lo comido: indicador de conducta compensatoria (Academy 1.1C1). Recvel es una app de entrenamiento; no se debe prescribir cardio extra como “castigo”.
- **No se usa** PHQ-2/PHQ-9: Carraça 2018 deja muchos predictores psicológicos con evidencia insuficiente, y no somos una clínica de salud mental.
- **No se usa** un chip de “problemas psicológicos”: no está validado y se confunde con diagnóstico.

### 🟡 Prioridad 2 — Cambian los números (Paso "Tu actividad")

**Actividad diaria fuera del gimnasio (NEAT / ocupación)**
- NEAT varía hasta **2,000 kcal/día** entre individuos similares (Endotext 2022, PMID 25905303; Levine *Science* 1999, PMID 9880251)
- "Entrenamientos/semana" solo NO basta para el TDEE → preguntar tipo de trabajo: sedentario / de pie / físico
- Los pasos diarios ya se leen de HealthKit

**Hora de entrenamiento, duración y ayunas**
- Solo importa en escenarios específicos (ISSN Nutrient Timing 2017, PMID 28919842):
  - >60–70 min intenso → 30–60 g carbs/hora durante
  - <4 h entre sesiones → 1.2 g/kg/h carbs recuperación
- Permite programar comidas peri-entreno en el plan

**Cafeína habitual y horario**
- 400 mg incluso **6 h antes de dormir** altera el sueño (Drake 2013, PMID 24235903)
- Sinergia: la app ya tiene datos de sueño → detectar causa de mal sueño
- Dosis ergogénica: 3–6 mg/kg, ~60 min pre-ejercicio (ISSN Caffeine 2021, PMID 33388079)

**Clima caluroso / sudoración**
- Hidratación individualizada por tasa de sudoración (ACSM 2007, PMID 17277604)
- AI agua: 3.7 L hombres / 2.7 L mujeres, más con calor/ejercicio (IOM 2005)

**Historial de intentos de bajar de peso**
- Menos intentos previos es el predictor pretratamiento **más consistente** de un mejor resultado (Carraça, Santos, Mata, Teixeira, *Obes Facts* 2018, DOI 10.1159/000485838; r=0.10).
- Umbral práctico: 1 vez / 2–3 veces / más de 3 veces. ≥3 ciclos de pérdida ≥4.5–9 kg es el criterio de cycling moderado/severo (Mason et al., *Metabolism* 2012).
- El cycling **no impide** volver a perder peso ni “rompe el metabolismo” a largo plazo (Mason 2012). Sirve para **bajar el ritmo**: déficit ~0.5%/semana, no un crash.

**Barreras percibidas** (Welsh et al., *J Acad Nutr Diet* 2012, PMC3175339)
- Tres factores: falta de conocimiento, **falta de control**, **falta de tiempo**. Bajar esas barreras se asoció con más pérdida de peso.
- Comer fuera / food away from home sube kcal y baja calidad de dieta (USDA ERS).
- Preguntar “problemas psicológicos” es clínico de más. El cribado va en SCOFF + atracón, no en un chip.
- Dansinger *JAMA* 2005: adherencia r=0.60 vs tipo de dieta r=0.07 — las barreras diseñan el plan, no un diagnóstico.

### 🟢 Prioridad 3 — Adherencia (Paso "Tu estilo de vida")

**Presupuesto** (bajo/medio/alto)
- Inseguridad alimentaria → ingesta inadecuada de nutrientes (Academy 2017, PMID 29173349)
- Filtra cortes de carne, pescados, suplementos del plan

**Cocina/región preferida**
- La pérdida de peso se asocia con **adherencia (r=0.60, p<0.001)** y NO con el tipo de dieta (r=0.07) — Dansinger, *JAMA* 2005, PMID 15632335
- WHO 2026: la dieta varía según contexto cultural y alimentos locales

**Tiempo para cocinar**
- Predictor de adherencia; filtra recetas elaboradas vs. rápidas

**Suplementos actuales y disposición**
- Con evidencia: creatina 3–5 g/d (PMID 28615996), cafeína (PMID 33388079), beta-alanina 4–6 g/d (PMID 26175657), proteína en polvo (PMID 28642676)
- **B12 obligatoria en veganos** (Academy 2016, PMID 27886704)

---

## 3. Datos que NO se preguntan (mitos descartados)

| Pregunta tentadora | Veredicto |
|---|---|
| Chip de “problemas psicológicos” o “como con estrés” como cribado | ❌ No validado. El cribado es SCOFF + frecuencia de atracón |
| PHQ-2 / PHQ-9 en este flujo | ❌ Dominio distinto; predictores psicológicos mixtos (Carraça 2018) |
| EDE-Q (28 ítems) o diagnóstico de TCA | ❌ Fuera de alcance; el SCOFF solo sugiere, no diagnostica |
| Frecuencia de comidas para "acelerar metabolismo" | ❌ Impacto limitado (ISSN Timing, PMID 28919842). Solo logística para proteína cada 3–4 h |
| "¿Desayunas?" (obligatoriedad) | ❌ Sin efecto metabólico relevante (PMID 32304359) |
| Tipo de dieta específica (keto vs. baja grasa) | ❌ Igualmente efectivas (ISSN, PMID 28630601). Solo como preferencia |
| Ayuno intermitente como superior | ❌ Sin ventaja sobre restricción continua (ISSN) |
| "Ventana anabólica de 30 min" | ❌ El efecto anabólico dura ≥24 h (ISSN Protein, PMID 28642676) |
| "8 vasos de agua" fijo | ❌ Rango amplio compatible con hidratación normal (IOM 2005) |
| Nutrigenómica, tipo sanguíneo, tests IgG | ❌ Ninguna guía los requiere |
| % grasa por DEXA obligatorio | ❌ Útil pero opcional (todos los métodos tienen limitaciones) |

---

## 4. Rangos científicos para el prompt de Gemini

### Proteína (g/kg/día)
| Contexto | Rango | Fuente |
|---|---|---|
| General ejercitante | 1.4–2.0 | ISSN 2017 |
| Ganancia muscular | 1.6–2.2 | Morton 2018 meta |
| Pérdida grasa, magro entrenado | 2.3–3.1 g/kg FFM | ISSN Diets 2017 |
| Pérdida grasa, sobrepeso | 1.2–1.6 | Wycherley 2012 |
| Embarazo/lactancia | ≥1.7 | IAAO |
| Por comida | 0.25–0.40 g/kg (~20–40 g) cada 3–4 h | ISSN |
| Pre-sueño | Caseína 30–40 g | ISSN |

### Carbohidratos
- Volumen alto: 8–12 g/kg/día
- Durante >60–70 min: 30–60 g/hora
- Recuperación <4 h: 1.2 g/kg/h

### Velocidad de pérdida de peso
- 0.5–1.0% peso/semana (preservar masa magra)

### Límites poblacionales (WHO 2026)
- Frutas+verduras ≥400 g/día; fibra ≥25 g/día
- Azúcares libres <10% kcal; grasa 15–30% kcal; saturada <10%; sal <5 g/día; potasio ≥3,510 mg/día

### Cafeína
- Ergogénica: 3–6 mg/kg ~60 min pre-ejercicio
- Nunca dentro de 6 h antes de dormir
- Máximo prudente ~400 mg/día

---

## 5. Precauciones que el plan DEBE respetar

1. **NO déficit agresivo** en: embarazo/lactancia, TCA, ciclo irregular, ya delgados
2. **Enfermedad renal/hepática** → derivar a profesional, no hiperproteica
3. **Diabetes/hipertensión** → disclaimer de supervisión + ajustes (DASH, etc.)
4. **Levotiroxina** → nunca con desayuno/café/calcio/hierro
5. **Metformina + vegano** → alerta B12 doble
6. **Cafeína** → cortar 6 h antes de la hora de cama (integrar con sueño)
7. **Hidratación** → no superar ~1 L/hora (hiponatremia)
8. **≥60 años** → proteína por comida alta (0.40–0.60 g/kg, resistencia anabólica)
9. **Veganos** → verificar B12, hierro, zinc, yodo, calcio, omega-3

---

## 6. Estructura del cuestionario resultante

Cuatro pasos de UI. Lo que la app ya tiene se infiere; no se pregunta.

| Paso | Título | Campos | Skip si... |
|---|---|---|---|
| 1 | Tu salud | Condiciones médicas, **ninguna de estas**, embarazo/ciclo (si ♀) | Nunca (seguridad) |
| 2 | Relación con la comida | Diagnóstico previo + **SCOFF** (5 ítems) + frecuencia de atracón + ejercicio compensatorio | Nunca (seguridad) |
| 3 | Medicamentos | Warfarina, levotiroxina, metformina, estatinas, **no tomo ninguno**, otros | Nunca |
| 4 | Tu actividad diaria | Ocupación (sedentario/de pie/físico) | Nunca (NEAT no se tiene) |
| 5 | Tu historial | Intentos de bajar de peso + barreras (tiempo, comer fuera, salidas, seguir un plan) | Nunca |
| 6 | A tu manera | Presupuesto, cocina preferida, tiempo cocinando, suplementos | Nunca |

### Se infiere, no se pregunta

| Dato | Fuente |
|---|---|
| Objetivo, comidas/día, dieta, alergias, peso/altura/sexo/edad | `NutritionProfile` |
| Sueño, recuperación, strain, pasos, % grasa, energía activa | HealthKit / `DailyScoreRecord` |
| Cafeína habitual | HealthKit `dietaryCaffeine` |
| Hora y duración de entreno | `WeeklyRoutineStore` (`startDate`, `minutes(forWeekday:)`) |

### Fuera del cuestionario a propósito

Hora/duración de entreno, cafeína y clima no merecen pantalla: la primera ya está en la rutina, la segunda en HealthKit, y el clima no está en la app (el prompt usa hidratación IOM + ACSM como base). Preguntarlos duplicaba datos y alargaba el flujo.

Después del plan (no antes) el usuario puede pedir cambios en chat.
