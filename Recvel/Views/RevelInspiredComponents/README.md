# RevelInspiredComponents

Componentes de UI derivados de las pantallas de referencia de Bevel
(`Bevel_references/`), guardados aparte para poder reutilizarlos en cualquier
superficie de la app.

**Regla:** aqui solo entran los componentes que el usuario pida explicitamente.
Nada mas se mueve a esta carpeta por iniciativa propia.

## Inventario

| Componente | Origen medido | Uso |
| --- | --- | --- |
| `ReportInk` | Paleta del Home de Bevel (fondo plano, tarjetas un punto mas claras) | Paleta compartida de estos componentes |
| `ReportRing` + `HatchPattern` | Anillos Strain/Recovery/Sleep del Home: pista hundida, arco con degradado y halo, trama diagonal = "estimado / fuera de rango" | Anillo de score con etiqueta |
| `ReportMetricRow` + `ReportSparkline` | Filas "Other Biomarkers": insignia + palabra de estado + valor, sparkline con punto final y linea base punteada | Fila de metrica con tendencia |
| `SegmentedLoadBar` | Barra de energia (ticks verticales llenos vs apagados) | Progreso segmentado |

Medidos sobre fotogramas de `BioAge_revel.mp4` extraidos con
`ffmpeg -vf fps=1` mas recortes a resolucion nativa (1290x2796), no de memoria.

Estos componentes se escribieron para la primera version del Reporte de la
mañana. La version vigente de esa pantalla sigue la linea de la pantalla
**Bio Age** de la referencia (fondo de nebulosa, dial de ticks, particulas), asi
que estos quedan disponibles para otras superficies.
