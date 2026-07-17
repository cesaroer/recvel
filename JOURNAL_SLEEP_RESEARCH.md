# Journal y disciplina de sueno — metodologia

## Referencias de producto

- Stoic permite un check-in unico o separar **Morning Preparation** y **Evening Reflection**, con prompts personalizables, historial y streak opcional: [Stoic Help — Home Screen](https://help.getstoic.com/stoic-user-guide/mooMJC6qGFVeG62FpCwNAw/home-screen/6f9eBdDY7kpekp8AYu18Xq), [Journaling and Customization](https://help.getstoic.com/faq/3sfUSwpkyPFw22e8F1CRHk/journaling-and-customization/6f9eBdDY7njMvRmxFbraod).
- Bevel Journal registra comportamientos y no presenta un insight hasta tener al menos **5 Si y 5 No**. Su documentacion dice explicitamente que son correlaciones, no causalidad: [Bevel Journal Common Questions](https://help.bevel.health/en/articles/11968449).
- Recvel adapta la arquitectura — registro rapido, historial y asociaciones bajo demanda — sin copiar textos, nombres, assets ni algoritmos propietarios.

## Evidencia y limites del diario

- Una revision sistematica de 51 estudios encontro resultados prometedores pero heterogeneos para escritura positiva; bienestar subjetivo fue mas consistente y salud fisica/psicologica tuvo resultados mixtos: [PLOS ONE 2024](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0308928).
- Una revision/meta-analisis de intervenciones de gratitud encontro beneficios promedio, pero muchos estudios tuvieron alto riesgo de sesgo: [PMC10393216](https://pmc.ncbi.nlm.nih.gov/articles/PMC10393216/).

Por ello Recvel usa intencion/control, hechos positivos, gratitud y aprendizaje como invitaciones de autoconocimiento. No promete tratar ansiedad, depresion, trauma ni otra condicion. La app recomienda detener la escritura y buscar apoyo apropiado si aumenta el malestar o existe riesgo inmediato.

## Asociaciones del Journal

Para cada comportamiento se unen `HabitLog` y `DailyScoreRecord` por dia calendario. Solo se calcula:

`media(Recovery | Si) - media(Recovery | No)`

cuando existen al menos 5 dias en cada grupo. Ausencia de respuesta significa desconocido y se excluye. El resultado se etiqueta como **asociacion personal, no causalidad**; puede reflejar confusores o causalidad inversa.

## Journal Pro implementado (15 julio 2026)

- El dia del Journal se asigna desde la hora habitual de despertar hasta el siguiente despertar mediante `JournalDayEngine`; un evento a las 02:00 pertenece al dia iniciado la manana anterior.
- El header muestra mes, semana seleccionable y estados `sin registro`, `parcial` y `completo`; tocar el mes abre el calendario mensual completo.
- El orden de producto es calendario, `Tu registro de hoy`, `Diario mental`, entradas de dia/noche e Insights.
- `JournalCatalog` incluye senales automaticas (pasos, cardio, luz diurna, fuerza, zona 2, stress, mindfulness, siestas, nutricion y sobrepasar carga), entradas hibridas y entradas manuales configurables.
- Medicacion, ciclo, sexualidad y otros tags sensibles son opt-in y permanecen apagados por defecto. Los tags personalizados son booleanos en v1.
- `JournalAutoEntryEngine` usa valores medidos y umbrales editables; ausencia de dato sigue siendo desconocido, nunca `No`.
- `JournalProImpactEngine` analiza por separado Recovery o Sleep, ordena por magnitud y conserva el minimo de 5 `Si`/5 `No`.
- Recordatorios locales de manana, noche y continuidad no usan analytics ni servicios externos.

## Disciplina de sueno

Cada recomendacion se persiste como `PlannedSleepNight` en la fecha en que comienza la noche. No se compara historial contra la recomendacion actual.

La sesion real viene exclusivamente de `HKCategoryType.sleepAnalysis`, normalizada en `HealthDataProvider`:

- inicio real: primer intervalo dormido/etapa de la sesion principal;
- fin real: ultimo intervalo de la sesion principal;
- duracion: union de etapas dormidas, sin siestas.

Estado por noche:

- **Seguido:** inicio a <=30 min del plan.
- **Cerca:** diferencia >30 y <=60 min.
- **Fuera:** diferencia >60 min, cuando si existe una sesion medida.
- **Sin datos:** no existe sesion Apple Health; no es fallo y no entra al score.

Score (solo tras 5 noches medidas):

- horario de inicio, 70 puntos: completo hasta 30 min; descenso lineal a cero entre 30 y 90 min;
- duracion, 20 puntos: proporcion de horas dormidas respecto al objetivo, limitada a 100%;
- consistencia de despertar, 10 puntos: completo hasta 30 min; descenso lineal a cero entre 30 y 90 min.

Apple Health no registra que la persona completo los pasos de la rutina, por lo que la rutina se excluye del score. Los ciclos de ~90 min siguen siendo una heuristica poblacional con variacion individual, no una medicion clinica.
