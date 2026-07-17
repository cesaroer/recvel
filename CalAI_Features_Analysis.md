# Cal AI — Análisis de features y onboarding

Análisis basado en `calai_reference.mp4` (42s, onboarding completo de Cal AI).
Fecha: 2026-07-13

## 1. Onboarding de Cal AI: qué pide

El onboarding de Cal AI dura ~40 segundos y consta de 6 pasos:

| Paso | Pregunta | Tipo de input | Para qué lo usa |
| --- | --- | --- | --- |
| 1 | "¿Cuántos entrenamientos haces por semana?" | Selección única: 0-2 / 3-5 / 6+ | Calibrar actividad física y multiplicador de gasto energético |
| 2 | "¿Cuándo naciste?" | Date picker (mes/día/año) | Calcular edad y ajustar TMB (Mifflin-St Jeor) |
| 3 | "¿Dónde oíste hablar de nosotros?" | Selección única (App Store, amigo, Google, YouTube, X, Facebook, Instagram, TV) | **Marketing puro — omitir en Recvel** |
| 4 | "¿Has probado otras apps para controlar calorías?" | Sí / No | Probablemente ajustar copy/tone de la app |
| 5 | Pantalla de value prop | Gráfico "Weight trend" con comparativa "With Cal AI" vs "Without a plan" | Convencimiento antes de pedir datos sensibles |
| 6 | "¿Cuánto mides?" | Altura con selector ft/in o cm | Calcular IMC y TMB |

**Datos que no se ven en el video pero que Cal AI pide típicamente después:**
- Peso actual y objetivo
- Género
- Objetivo (perder peso, mantener, ganar músculo)
- Velocidad de progreso deseada (0.25, 0.5, 0.75, 1 kg/semana)
- Restricciones dietéticas / alergias / preferencias (vegano, keto, etc.)

## 2. Features clave de Cal AI inferidas del onboarding

- **Plan calórico personalizado:** calcula objetivos diarios de kcal, proteína, carbohidratos y grasas a partir de datos antropométricos + actividad.
- **Tracking por foto/texto:** log rápido de comidas con IA.
- **Proyección de peso:** gráfica de tendencia a 6 meses con/without plan.
- **Adherencia / retention messaging:** "80% de usuarios mantienen pérdida de peso a 6 meses".
- **Onboarding progresivo:** primero actividad, edad, marketing, experiencia previa, value prop, altura; luego probablemente peso y objetivo.

## 3. Features de Cal AI que podemos adaptar a Recvel

### 3.1 Core (ya alineado con Recvel)

| Feature | Cal AI | Recvel v1 |
| --- | --- | --- |
| Calorías por foto/texto | Si | Si (NutritionEstimator local + confirmación) |
| Objetivos diarios de macros | Si | Si (basado en perfil + HealthKit) |
| Edad, altura, peso | Si | Si |
| Actividad semanal | Si | Si, pero podemos cruzar con workouts reales de HealthKit |

### 3.2 Features nuevas que enriquecen Recvel

| Feature | Descripción | Tipo de implementación |
| --- | --- | --- |
| **Plan nutricional diario generado** | Sugerencia de desayuno/almuerzo/cena/aperitivos para cumplir macros restantes | Local con reglas + opcional LLM gratis (modo personal) |
| **Sugerencia de próxima comida** | "Para alcanzar tu proteína hoy, prueba pollo a la plancha + ensalada" | Local con reglas o LLM |
| **Proyección de peso / body composition** | Curva estimada de peso en 4/8/12 semanas según déficit/superávit real | Fórmula basada en 3,500 kcal ≈ 0.45 kg de grasa (Hall 2011 con notas) |
| **Ajuste dinámico de objetivos** | Si 7 días seguidos comes menos proteína, bajar ligeramente meta o sugerir fuentes | Reglas locales |
| **Meal history insights** | "Esta semana has comido mucho sodio / poca fibra" | Agregación local de logs |
| **Recomendación pre-entreno/post-entreno** | "Tienes strain alto hoy; prioriza carbohidratos y 30g proteína post-workout" | Cruce de ScoreEngine + Nutrition |
| **Lista de compras** | Generar lista desde el plan semanal | Local desde meal plan |
| **Recordatorios contextuales** | "Es hora de cenar; te quedan 40g de proteína" | Notificaciones locales |
| **Comidas favoritas / recurrencia** | Aprender platos frecuentes y sugerirlos primero | SwiftData local |
| **Modo "chef"** | Generar receta con lo que tienes en casa ajustando a macros | LLM gratis (modo personal) o reglas locales |

### 3.3 Features de Cal AI que NO deberíamos copiar

- Preguntas de marketing puras ("¿dónde nos conociste?") en onboarding principal.
- Claims sin fuente ("80% mantiene pérdida de peso"). Si usamos proyecciones, deben mostrar incertidumbre y citar estudios.
- Pedir género solo como binario; ofrecer "otro/preferido no decir" si es relevante para fórmulas.

## 4. Onboarding recomendado para Recvel

El objetivo es recopilar lo mínimo imprescindible para calcular objetivos nutricionales y generar planes sin fricción. Omitimos marketing.

### Paso 1 — Bienvenida + permisos HealthKit
- Breve value prop: "Recvel conecta tu salud, sueño y nutrición en un solo lugar. Todo en tu dispositivo."
- Botón para autorizar HealthKit (lectura de peso, altura, fecha de nacimiento, FC, HRV, sueño, workouts).
- Si el usuario concede acceso, **precargar edad, peso y altura** desde HealthKit.

### Paso 2 — Perfil antropométrico (solo si no hay HealthKit)
- Fecha de nacimiento
- Altura (cm / ft-in)
- Peso actual
- Género (para fórmulas de TMB; opcional "otro/preferido no decir" usando Mifflin promedio)

### Paso 3 — Objetivo corporal
- Perder grasa
- Mantener
- Ganar músculo
- Recomponer

### Paso 4 — Velocidad / agresividad
- Conservador (0.25 kg/semana)
- Moderado (0.5 kg/semana)
- Agresivo (1 kg/semana)
- Incluir advertencia si agresivo (>1% peso corporal/semana)

### Paso 5 — Actividad y entrenamiento
- "¿Cuántos entrenamientos haces por semana?" (0-2 / 3-5 / 6+) — copia directa de Cal AI.
- Opcional: "¿Prefieres que use tus workouts reales de Apple Watch?" (si hay datos de HealthKit).

### Paso 6 — Restricciones y preferencias dietéticas
- Dietas: omnívoro, vegetariano, vegano, keto, mediterránea, baja en sodio, etc.
- Alergias/intolerancias: gluten, lácteos, frutos secos, mariscos, soja.
- Alimentos que no te gustan (libre).

### Paso 7 — Resumen del plan
- Mostrar TMB, TDEE estimado, objetivo calórico, macros objetivo.
- Botón "Ajustar manualmente" para usuarios avanzados.
- CTA "Empezar".

## 5. Integración con el resto de Recvel

El plan nutricional debe reaccionar a:

- **Recovery bajo:** sugerir más alimentos antiinflamatorios, omega-3, antioxidantes; reducir déficit agresivo.
- **Strain alto:** aumentar carbs alrededor del entrenamiento, asegurar 30g proteína post-workout.
- **Sleep malo:** evitar cafeína después de cierta hora, sugerir magnesio/triptófano (con disclaimer no médico).
- **Peso registrado en HealthKit:** reajustar TDEE y proyección cada 7-14 días.
- **Historial de comidas:** evitar repetir platos aburridos, sugerir alternativas similares en macros.

## 6. Próximos pasos sugeridos

1. **Modelar `UserProfile` en SwiftData** con los campos del onboarding (edad, altura, peso, género, objetivo, velocidad, actividad, restricciones).
2. **Crear `NutritionTargetEngine`** para calcular TMB (Mifflin-St Jeor), TDEE (multiplicador + workouts de HealthKit), macros (0.8-2.2g proteína/kg, 20-35% grasa, resto carbs).
3. **Diseñar flujo de onboarding** con las 7 pantallas, leyendo lo posible desde HealthKit.
4. **Crear `MealPlanEngine`** local: dado objetivos restantes del día, sugerir comidas usando USDA + reglas + preferencias.
5. **Añadir vista "Plan de hoy"** en dashboard o tab de nutrición con desayuno/almuerzo/cena/aperitivos.
6. **Vista "Sugerencia inteligente"** tras registrar una comida: "Te faltan 25g de proteína; prueba..."
7. **Opcional (modo personal):** integrar Gemini/Groq para generar planes semanales y recetas.

## 7. Notas de diseño

- Mantener Liquid Glass: tarjetas grandes, fondo oscuro, tipografía clara.
- Usar anillos de progreso para macros (como NutritionView actual).
- Proyecciones de peso: gráfica simple con banda de incertidumbre, no línea única.
- Onboarding: un paso por pantalla, botón "Continuar" abajo, progress bar arriba (igual que Cal AI).
