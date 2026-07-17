# Calorie AI Research - Recvel

Investigacion actualizada: 2026-07-13

Este documento es la fuente de verdad para el feature de nutricion con IA de Recvel. Los READMEs anteriores se usaron solo como referencia. Cuando habia contradicciones, este documento reemplaza la decision anterior.

## Decision final

Para v1, Recvel **no va a fine-tunear modelos**. La estrategia correcta es tomar modelos ya existentes, correrlos localmente cuando sea viable, pedirles una salida estructurada y obligar a confirmacion humana antes de guardar.

Restriccion adicional del usuario: este feature debe usar piezas **open source, open weights permisivas o datos abiertos**, sin pagar licencias, SDKs comerciales, suscripciones, tokens ni proveedores cloud. Apple/Core ML/Vision pueden usarse como APIs de plataforma porque vienen con iOS/Xcode, pero no deben convertirse en dependencia de un modelo propietario o pago.

Regla de licencia:

- Preferir: Apache 2.0, MIT, BSD, CC0/public domain.
- Permitido con cuidado: ODbL/Open Food Facts, solo si se respeta atribucion y share-alike de la base de datos.
- Evitar: licencias non-commercial, research-only, custom comercial, SDKs cerrados, APIs por token, modelos que requieran contrato o suscripcion.
- Si una licencia no esta clara, el modelo/dataset queda bloqueado hasta verificarla.

La app puede recibir:

- Foto de comida.
- Texto libre.
- Voz transcrita a texto.
- Codigo de barras u OCR de etiqueta.

Pero la app no debe prometer "calorias exactas" desde una foto. El output correcto es una propuesta editable con rango y confianza.

```text
Foto / texto / voz / barcode
        |
        |-- Modelo local existente o Vision/OCR
        v
JSON estructurado:
  alimentos visibles
  porcion aproximada
  kcal/macros estimados
  incertidumbres
  confianza
        |
        v
Base nutricional local + ajustes de porcion
        |
        v
Pantalla editable
        |
        v
Confirmacion del usuario -> SwiftData / HealthKit opcional
```

La experiencia debe sentirse como "IA que te ayuda a registrar rapido", no como "IA que sabe exactamente lo que comiste".

## Restriccion de licencias: open source / gratis, sin pagos

Recvel **no paga licencias, suscripciones, royalties, tokens ni SDKs comerciales** para este feature. Todo componente integrado debe ser open source, open weights con licencia permisiva, dominio publico o una API de plataforma incluida en iOS sin costo extra. Esta restriccion es dura y filtra todas las decisiones de este documento.

Interpretacion practica:

- **Core del feature:** modelos/datos/librerias open source o permisivos.
- **APIs Apple incluidas en iOS:** Vision, NaturalLanguage, Core ML y AVFoundation se pueden usar porque no agregan costo ni dependencia externa, aunque no sean open source.
- **No core:** Apple Foundation Models puede quedar como experimento opcional porque no es open source; el feature debe funcionar sin eso.
- **Bloqueado:** SDKs comerciales, APIs por token, modelos non-commercial/research-only, licencias GPL/AGPL o cualquier cosa que requiera contrato.

### Licencias de modelos candidatos

| Modelo | Licencia/costo | Usable en Recvel v1 | Nota |
| --- | --- | --- | --- |
| SmolVLM / SmolVLM2 | Apache 2.0 / gratis | Si | Candidato principal VLM |
| Moondream2 | Apache 2.0 / gratis | Si | Candidato alterno VLM |
| Qwen2.5-0.5B/1.5B-Instruct | Apache 2.0 en variantes publicas pequenas | Si, si se verifica LICENSE exacto | Candidato texto local |
| Qwen2.5-VL-3B-Instruct | Qwen Research / non-commercial | No | Bloqueado para producto |
| Qwen2.5-VL-7B/32B | Apache 2.0 en variantes mayores | No v1 | Licencia mejor, demasiado pesado para iPhone |
| Apple FastVLM | Research/non-commercial | No | Bloqueado hasta licencia permisiva |
| Apple Foundation Models | Propietario Apple, gratis | No core | Opcional, no open source |
| Clasificadores Food-101 open source | MIT/Apache segun repo | Solo benchmark/fallback | No son ruta principal |

### Licencias de datasets nutricionales

| Dataset | Licencia | Usable en Recvel |
| --- | --- | --- |
| USDA SR Legacy / FNDDS / Foundation Foods | Dominio publico / CC0 | Si, fuente principal |
| Open Food Facts | ODbL | Si con atribucion/share-alike; cuidado al embeber subsets |
| Nutrition5k | CC-BY 4.0 | Si con atribucion, para benchmark/investigacion |
| Food-101 | Licencia academica/dataset de imagenes | Solo benchmark/referencia, no redistribuir imagenes |

### Herramientas permitidas

| Herramienta | Licencia/costo | Usable |
| --- | --- | --- |
| MLX Swift / MLX Examples | MIT / gratis | Si |
| llama.cpp / GGUF runtime | MIT / gratis | Si |
| coremltools | BSD-style / gratis | Si |
| GRDB.swift | MIT / gratis | Si |
| swift-transformers / exporters open source | Apache 2.0 / gratis | Si, previa verificacion |
| Apple Vision / NaturalLanguage / Core ML | APIs de plataforma / gratis | Si |
| Passio Nutrition AI | Comercial/API/SDK externo | No |
| OpenAI / Anthropic / Google Cloud Vision | APIs comerciales por uso | No |

### Resumen de descartados

- **Passio Nutrition AI:** SDK/API comercial; no open source/cero costo.
- **OpenAI, Anthropic, Google Cloud Vision:** cloud y pago por request/token.
- **Apple FastVLM:** licencia de investigacion/no comercial.
- **Qwen2.5-VL-3B-Instruct:** licencia non-commercial para esa variante.
- **Foundation Models como dependencia core:** gratis pero propietario/no open source.
- **Modelos GPL/AGPL:** evitar por obligaciones de distribucion incompatibles con la estrategia App Store.

### Verificacion con fuente primaria (julio 2026) — precision adicional por repositorio

La tabla de arriba agrupa "Clasificadores Food-101 open source" bajo "MIT/Apache segun repo". Verifique el campo de licencia real, uno por uno, visitando cada ficha de Hugging Face — el resultado importa porque varios de los candidatos mencionados en investigacion anterior de este mismo documento **no tienen licencia permisiva confirmada** y quedan bloqueados hasta verificar con el autor:

| Modelo | Licencia confirmada en la ficha | ¿Usable sin costo/permiso? |
| --- | --- | --- |
| `AlexKoff88/mobilenet_v2_food101` | Apache 2.0 | Si |
| `prithivMLmods/Food-101-93M` | Apache 2.0 (y el modelo base `google/siglip2-base-patch16-224` tambien es Apache 2.0, no hereda restriccion) | Si |
| `Lumia101/Food101-EfficientNet-B0` | MIT | Si |
| `skylord/swin-finetuned-food101` | **Sin campo de licencia declarado** (equivale a "todos los derechos reservados" por defecto) | **No, bloqueado hasta verificar con el autor** |
| `Kaludi/food-category-classification-v2.0` | **Sin campo de licencia declarado** | **No, bloqueado** |
| `paolopertino/mobilenet-finetuned-food101` | Licencia marcada como **"other"** (no es una licencia estandar reconocida) | **No, requiere leer el texto completo de esa licencia antes de usar** |
| `nateraw/vit-base-food101` | **Sin campo de licencia declarado** | **No, bloqueado** |

Tambien verifique **SmolVLM-256M-Instruct y SmolVLM2-2.2B-Instruct: Apache 2.0 confirmado en ambos**, y **Moondream2: Apache 2.0 confirmado** — los tres candidatos VLM de este documento son realmente libres de costo y uso comercial, consistente con la tabla de arriba.

**Hallazgo importante no capturado antes en este documento: Depth Anything V2 tiene licencias distintas por tamano.** Solo la variante **Small es Apache 2.0** (usable); **Base y Large son CC-BY-NC-4.0 (no comercial, bloqueadas)**. Si en el futuro se integra Depth Anything para apoyar estimacion de volumen (seccion de porcion de este documento), debe ser explicitamente la variante Small, no asumir que todas comparten licencia.

`google/mobile_food_segmenter_V1` (segmentador de Google en Kaggle) es consistente con Apache 2.0 por convencion de los demas modelos TF Hub de Google migrados a Kaggle, pero el badge de licencia no se pudo confirmar por fetch automatizado (la pagina de Kaggle renderiza via JavaScript) — **verificar manualmente en el navegador antes de integrarlo**, no asumir.

**USDA FoodData Central confirmado CC0/dominio publico sin distincion entre colecciones** (SR Legacy, FNDDS, Foundation Foods y **tambien Branded Foods**, aunque contenga datos enviados por la industria, la compilacion en FDC sigue siendo obra del gobierno de EE.UU. y por tanto dominio publico).

**Open Food Facts (ODbL) — que significa en terminos simples para Recvel, sin ambiguedad:** ODbL **no tiene ningun componente monetario**. Si Recvel empaqueta un subconjunto de esos datos dentro de la app: (1) debe atribuir la fuente, (2) solo si Recvel **redistribuye la base de datos modificada como base de datos** (no la app en si) debe compartir esas modificaciones bajo la misma licencia. La obligacion de compartir-igual **no aplica al codigo Swift ni a la app completa**, solo a la base de datos en si si se redistribuye modificada. Recvel puede vender/monetizar la app libremente. Las imagenes de usuarios de OFF son CC-BY-SA por separado, con la misma logica de atribucion.

**Confirmado que las tres alternativas de pago quedan correctamente descartadas, con evidencia especifica de por que no hay tier gratuito viable para produccion:**

- **Passio Nutrition AI:** pricing por planes escalonados basados en tokens, sin ningun free tier de produccion, ni siquiera un trial gratuito.
- **Foodvisor Vision API:** no publica pricing; requiere "Contact Sales" / acuerdo comercial.
- **OpenAI GPT-4o API:** sin tier gratuito de API (solo $5 de credito inicial para cuentas nuevas, no perpetuo).
- **Google Gemini API:** el tier gratuito existe y es util para uso personal/experimental, pero no debe tratarse como dependencia de produccion porque tiene cuotas, politicas de datos distintas al paid tier y disponibilidad variable por modelo.

**Herramientas de desarrollo, todas confirmadas gratis y sin costo adicional al feature:** `coremltools` (BSD 3-Clause), MLX y MLX Swift (MIT), Xcode/Core ML runtime/Vision framework/ARKit (incluidos con las herramientas de Apple; el unico costo fijo es la membresia anual de Apple Developer Program de $99/ano, que aplica a cualquier app iOS y no es especifico de este feature).

## Modo personal / experimental con APIs gratis

El usuario aclaro que, si la app o build es solo para uso personal, **si puede aceptar APIs gratuitas, modelos non-commercial o servicios no 100% open source**, siempre que no haya pago. Esto crea un segundo modo separado del core de produccion:

- **Core Recvel v1:** local-first, sin pagos, sin cloud, licencias permisivas.
- **Modo personal experimental:** puede usar free tiers y modelos non-commercial, sabiendo que las fotos/textos salen del dispositivo y que el proveedor puede cambiar cuotas o condiciones.

Reglas para este modo:

1. Guardar esta capacidad detras de un flag/configuracion local, no activarla por defecto.
2. Mostrar aviso de privacidad: "esta foto/texto se enviara a un proveedor externo".
3. Nunca mezclar API key en el repo.
4. Tratar resultados como estimacion editable, igual que local.
5. No usar este modo para App Store/publicacion sin revisar terminos.

### APIs gratis o free tier utiles

#### APIs de nutricion y barcode (lookup nutricional)

| API | URL | Free tier | Limite/dia | API key | Datos | Latencia | Attribution | Decision |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Open Food Facts | world.openfoodfacts.org/data | 100% gratis (ODbL) | "1 scan = 1 call" | No | Barcode -> producto, macros, Nutri-Score, NOVA, ingredientes | 200-500ms | Si (ODbL) | Usar en core y modo personal (barcode) |
| USDA FoodData Central | fdc.nal.usda.gov/api-guide | Si | 1,000/hora con key | Si (gratis) | Macros completos, 150+ micros, Foundation/Survey/Branded/SR | 100-400ms | Sugerida (CC0) | Usar en core y modo personal (lookup numerico) |
| Edamam | developer.edamam.com | Developer (~1,000/dia) | ~1,000/dia | Si (app_id+key) | Macros, diet labels, parseo de ingredientes en NL | 200-600ms | Si | POC personal: Nutrition Analysis es muy potente para texto libre |
| Nutritionix | nutritionix.com/business/api | Developer (~500/dia) | ~500/dia | Si (AppID+Key) | NLP ("I ate 2 eggs and toast") -> items + macros; instant/search/UPC | 300-700ms | Si | POC personal: el NLP de foods es excelente para diario |
| Spoonacular | spoonacular.com/food-api | $0/mes | **50 points/dia**; 1 req/s | Si | Recipes + nutrition + ingredients + grocery(UPC) + meal planning + image classify | 300-800ms | Si (backlink) | POC personal: API mas versatil pero tier free muy limitado |
| FatSecret | platform.fatsecret.com | Basic 5k/dia; Premier Free ilimitado (startups) | 5k/dia o ilimitado | Si (OAuth) | Search/autocomplete, barcode, macros, recipes | 200-600ms | Si (Basic/free) | **Tier free mas generoso** (5k/dia o ilimitado) |
| Calorie Mama | caloriemama.ai/api | Solo trial/demo | Por acuerdo | Si | Imagen -> food classification + nutrients | <1s | Probable | No confirma free permanente; descartado |
| Clarifai Food | clarifai.com | 5,000/mes | Por plan | Si | Image classification >1k concepts (incluye foods) | ~500ms | Si (free) | POC personal: 5k/mes decente para experimentar |
| Google Vision | cloud.google.com/vision | 1,000/mes | Por uso | Si | LABEL_DETECTION incluye food concepts | ~500ms | No | POC personal: 1k/mes suficiente para prototipo |

#### APIs de LLM/VLM (reconocimiento de comida por foto/texto)

| API | Free permanente | Tarjeta | Limites free aprox. | Vision | Modelos VLM | Latencia | Uso comercial |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **Google Gemini** | Si | No | 15 RPM / 1,500 RPD / 1M TPM | Si (multi-imagen) | Gemini 2.5 Flash/Pro, Flash-Lite | 0.5-6s | Si (ToS) |
| **Groq** | Si | No | 30 RPM / 1,000 RPD / 30K TPM | Si | Llama 4 Scout, gpt-oss-120B | 0.3-0.8s | Si |
| **HuggingFace Inf. Providers** | Si (creditos) | No | Creditos mensuales | Si | Llama 4, Qwen-VL, Pixtral, gpt-oss | variable | Si |
| **OpenAI** | $100/mes (geografia) | No | Sujeto a pais | Si | GPT-4o-mini (paid), GPT-5.4-nano | 1-4s | Si |
| **Anthropic Claude** | No | Si | N/A | Si | Claude Sonnet, Haiku | 1-5s | Si (paid) |
| **Cohere** | Si | No | 1,000 calls/mes, 20 RPM | Si | Command A Vision | 1-3s | Solo dev/eval |
| **Mistral La Plateforme** | Solo Vibe chat | Si API | API: de pago | Si | Pixtral 12B/Large | 1-3s | open-weights si |
| **Azure OpenAI** | Trial $200/30d | Si | N/A | Si | GPT-4o | 1-4s | Si (paid) |
| **Together AI** | $1 inicial | No | No recurrente | Si | Llama 4, Qwen3-VL | 0.3-2s | Si |
| **Replicate** | No | Si | N/A | Si | YOLOv8, FoodSeg103 (comunidad) | 1-10s | Si |
| **Roboflow** | Si | No | 1,000 imgs/mes | Si | Food-101, FoodSeg103 (Universe) | 0.2-0.8s | No comercial en free |
| **OpenRouter** | Si | No | 50-1,000 RPD | Si | Gemini Flash Exp, Llama 4 Scout | 1-4s | Si |
| **Cloudflare Workers AI** | Si | No | 10k/dia | No | Llama 3, Mistral 7B | 0.5-1s | Si |
| **Silicon Flow** | Si | No | Limites generosos | Si | Qwen2.5-VL, Llama 4 | 1-3s | Si |
| **Novita AI** | Si | No | Limitado | Si | Llama 3.1, Llama 4 vision | variable | Si |

**Top 3 para POC personal de foto -> comida:**
1. **Google Gemini 2.5 Flash (free)** — mejor calidad/costo; multi-imagen; 1,500 RPD suficientes para POC/MVP. Disponible en LatAm.
2. **Groq + Llama 4 Scout (free)** — latencia ultra baja (<1s); ideal para chat streaming con imagenes.
3. **OpenRouter** con `google/gemini-2.0-flash-exp:free` o `meta-llama/llama-4-scout-17b-16e-instruct:free` — fallback gratuito, 50-1,000 RPD.

#### Modelos locales gratis en iPhone (incluso non-commercial)

| Modelo | Licencia | Tamaño | Vision | iOS (CoreML/MLX/llama.cpp) | Latencia iPhone | Food-specific | Decision |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **Apple FastVLM** | Apple Research (non-commercial) | 0.5B ~7GB fp16; 1.5B int8; 7B int4 | Si (VLM) | Si, app nativa iOS en repo | 0.5B: <1s TTFT; 5-10 tok/s | No (general) | Modo personal: usable si no se publica |
| Apple FastViT | Apple Sample Code | T8 ~14 MB; SA36 ~160 MB | Si (clasificador) | Si, .mlpackage oficiales | T8: 0.8ms; SA36: 3.5ms | No (ImageNet) | Fine-tunear con Food-101 |
| DeepSeek-VL2-tiny | MIT-like (DeepSeek License) | 3B (~2GB int4) | Si (VLM) | Via MLX/llama.cpp experimental | 1-3 tok/s iPhone Pro | No (general) | Experimento local |
| **MiniCPM-V 2.6** | MiniCPM License (gratis tras registro) | 8B (~5GB int4; gguf ~3GB) | Si (VLM) | Si via llama.cpp fork OpenBMB; demo iPad | 3-7 tok/s iPad/iPhone Pro q4 | No (general) | Experimento local fuerte |
| **Phi-3-Vision 128K** | MIT | 4.2B (~2.5GB q4) | Si (VLM) | Si via MLX Swift (MLXVLM) | 2-5 tok/s iPhone Pro q4 | No (general, fuerte OCR) | **Mejor gratis+permissivo+iOS-first** |
| Llama 3.2 Vision 11B | Llama 3.2 Community (gratis, NO UE) | 11B (~6.5GB q4) | Si (VLM) | Si via MLX Swift (MLXVLM) | 1-4 tok/s iPhone Pro q4 | No (general) | No UE; viable en LatAm |
| Pixtral 12B | Apache 2.0 | 12B (~7GB q4) | Si (VLM) | No CoreML; no soporte MLX/llama.cpp estable | Inestable en iPhone | No (general) | Descartado para movil |
| LLaVA-OneVision-0.5B | Apache 2.0 | 0.5B (~1.5GB q4) | Si (VLM) | Si via MLX Swift | 5-15 tok/s iPhone Pro | No (general) | **Candidato local ligero** |
| SmolVLM-256M | Apache 2.0 | 256M (~1GB q4) | Si (VLM) | Via MLX/llama.cpp experimental | ~3-8 tok/s iPhone Pro | No (general) | Candidato local ultra-ligero |
| Moondream2 | Apache 2.0 | ~2B (~1.5GB q4) | Si (VLM) | Via MLX/llama.cpp | ~2-5 tok/s iPhone Pro | No (general) | Candidato local alterno |
| WhisperKit | MIT | tiny ~75 MB; large ~1.5 GB | No (audio) | Si, CoreML nativo iOS | tiny: ~50ms RTF 0.1 | N/A | Para voz -> texto en nutricion |
| Food-101 clasificadores | MIT/Apache segun repo | MobileNetV2 ~7-14 MB; ViT ~85-330 MB | Si (food-specific) | Convertible a CoreML via coremltools | 3-50ms | **Si (101 clases)** | **Mejor para etiquetado exacto de comida** |

**Notas legales:**
- **Apple FastVLM**: licencia dice "Research Purposes does not include any commercial exploitation, product development or use in any commercial product or service." Una app personal no publicada encaja en research; si se publica en App Store, queda fuera. Usar solo en modo personal.
- **Llama 3.2 Vision**: bloqueado para residentes/empresas de UE. En LatAm si sirve.
- **MiniCPM-V**: registro gratuito para uso comercial; de otra forma research.

**Top 3 modelos locales para foto -> comida (gratis, modo personal):**
1. **Phi-3-Vision (MIT)** — mejor balance gratis+permisivo+iOS-first; 4.2B corre en iPhone Pro.
2. **LLaVA-OneVision-0.5B (Apache 2.0)** — ultra ligero, ~1.5GB, 5-15 tok/s; similar a SmolVLM.
3. **Apple FastVLM (non-commercial)** — mejor latencia nativa iOS, pero solo modo personal no publicable.

### Recomendacion practica para POC personal

La ruta mas rapida para lograr una experiencia tipo Cal AI sin pagar:

1. Foto -> **Gemini 2.5 Flash/Flash-Lite free tier** con prompt JSON estricto.
2. Resolver alimentos contra **USDA FoodData Central API**.
3. Si hay barcode -> **Open Food Facts API**.
4. Mostrar pantalla editable con chips de incertidumbre y slider.
5. Guardar resultado local.

Prompt sugerido para Gemini/free VLM API:

```text
Analyze this meal image for personal meal logging.
Return strict JSON only.
Do not claim exact calories.
List visible foods, likely portions, uncertainties, and kcal/macros as ranges.
Prefer conservative estimates.
If sauce, oil, sugar, drink, or portion size is unclear, ask at most two questions.
```

Ventajas:

- Permite comparar la UX contra Cal AI casi inmediatamente.
- No requiere empaquetar modelos pesados en iPhone.
- Puede servir como benchmark para decidir si SmolVLM/Moondream local son suficientes.

Riesgos:

- No es local-first.
- Puede enviar fotos de comida a terceros.
- Free tiers pueden cambiar, rate-limit, usar datos para mejorar productos o bloquear uso comercial.
- No debe estar activado por defecto en una app publica.

Fuentes: [Gemini API pricing/free tier](https://ai.google.dev/gemini-api/docs/pricing), [Groq rate limits/free plan](https://console.groq.com/docs/rate-limits), [Hugging Face Inference Providers](https://huggingface.co/docs/inference-providers/index), [Cloudflare Workers AI pricing](https://developers.cloudflare.com/workers-ai/platform/pricing/), [USDA FoodData Central API](https://fdc.nal.usda.gov/api-guide) y [Open Food Facts API](https://openfoodfacts.github.io/openfoodfacts-server/api/).

## Meta de paridad con apps comerciales

Si, la funcionalidad debe sentirse lo mas parecida posible a apps comerciales como MyFitnessPal Meal Scan, Foodvisor, Cal AI y SnapCalorie. La diferencia es que Recvel v1 mantiene la restriccion local-first y sin fine-tuning, asi que la paridad se define por **flujo, UX, velocidad de correccion y transparencia**, no por prometer el mismo error de un sistema cloud/propietario.

| App / patron | Tecnica publica o inferida | Error reportado/referido | Que copia Recvel conceptualmente | Que no puede prometer Recvel v1 |
| --- | --- | --- | --- | --- |
| MyFitnessPal / Meal Scan | Foto + clasificacion + base grande + edicion/manual slider | ~25-40% MAPE citado en estudios/reportes de dietary assessment, variable por comida | Foto rapida, candidatos, busqueda/base local, ajuste de porcion y confirmacion | Misma cobertura de base global ni backend propietario |
| Foodvisor | Segmentacion + referencia visual/plato + base nutricional + edicion | ~20-30% en contextos reportados, no universal | Separar alimentos visibles, detectar incertidumbres, pedir metodo/porcion | Segmentacion perfecta ni deteccion de condimentos invisibles |
| Cal AI | LMM multimodal cloud tipo GPT-4o/Gemini + base propia + feedback | ~25-35% tipico segun benchmarks informales; reviewers reportan fallos con comida oculta | UX de "snap -> estimate -> edit", lenguaje simple, macros instantaneos | Igualar razonamiento cloud con VLM pequeno local |
| SnapCalorie | Modelo propietario + datos/calorimetria + posible depth/LiDAR | ~20% declarado/reportado, pero metodologia no totalmente replicable | Usar profundidad/LiDAR si existe y tratar porcion como problema central | Replicar modelo/dataset propietario sin entrenar |

### Objetivo Recvel por modo de entrada

| Modo | Objetivo de experiencia | Precision esperada honesta | Confianza UI |
| --- | --- | --- | --- |
| Barcode/OCR de etiqueta | Igual o mejor que apps comerciales en empaquetados | Alta si la etiqueta/producto se lee bien | Alta |
| Texto/voz con cantidades | Muy competitivo; mas rapido que busqueda manual | Media-alta si hay unidades claras | Media/alta |
| Foto simple + confirmacion de porcion | Similar al flujo Cal AI/Foodvisor, con edicion mas honesta | Media; rango amplio si no hay escala | Media |
| Foto de plato mixto sin escala | Comercialmente atractivo pero tecnicamente incierto | Baja-media; error puede ser grande | Baja/media |
| Foto + LiDAR/depth en iPhone Pro | Mejor que foto 2D para volumen, si se implementa bien | Media-alta para volumen visible; aun depende de densidad/ingredientes | Media/alta |

### Como acercarnos al "feeling" comercial sin backend

1. **Primer resultado en segundos:** mostrar estimate inicial del VLM aunque sea imperfecto.
2. **Edicion de una mano:** chips para `+ aceite`, `+ salsa`, `doble porcion`, `quitar bebida`, `tamano grande`.
3. **Slider de porcion tipo comercial:** pequeno/normal/grande + gramos editables.
4. **Recalculo instantaneo:** macros y kcal cambian en vivo desde base local.
5. **Aprendizaje local del usuario:** si confirma "mi bowl de pollo" varias veces, Recvel lo sugiere la proxima vez sin cloud.
6. **Barcode/OCR como atajo premium:** productos empaquetados deben sentirse casi automaticos.
7. **Rangos visibles:** mostrar `520-720 kcal` y luego cerrar el rango cuando el usuario confirma porcion.

### Benchmark objetivo para POC

El POC no debe declarar MAPE de produccion hasta medirlo. Se recomienda construir un set propio de 100-200 comidas reales:

- 40 alimentos simples.
- 40 platos mixtos caseros.
- 40 comidas de restaurante/takeout.
- 40 productos empaquetados.
- 20 comidas mexicanas/LatAm dificiles para modelos generales.

Metas internas razonables:

- **Barcode/OCR:** error bajo si etiqueta/producto correcto.
- **Texto con cantidades:** acercarse a +/-15-25% contra una referencia manual.
- **Foto simple con porcion confirmada:** acercarse a +/-25-35%.
- **Foto mixta sin confirmacion:** aceptar que puede superar +/-40%; UI debe pedir correccion.

Conclusion de paridad: Recvel puede competir en sensacion de producto y flujo de registro. Para competir en precision con Cal AI/SnapCalorie sin cloud ni fine-tuning, necesita apoyarse fuerte en confirmacion rapida, historial local, barcode/OCR, base nutricional y, despues, depth/LiDAR opcional.

## Investigacion competitiva detallada: como lo hacen otros

Esta seccion resume investigacion de competidores enfocada solo en el feature de registro nutricional por foto/texto/voz. La conclusion transversal es muy clara: las mejores apps no dependen de una sola prediccion de IA. Combinan captura rapida, sugerencias, base nutricional grande, correccion de porcion y feedback continuo.

### Tabla competitiva

| Competidor | Inputs | Stack probable/publico | Flujo UX | Manejo de porcion | Leccion para Recvel |
| --- | --- | --- | --- | --- | --- |
| MyFitnessPal Meal Scan | Camara, galeria, busqueda manual, barcode | ML + computer vision + modelos propios entrenados con millones de imagenes + base verificada | Foto -> sugerencias -> elegir item -> ajustar serving -> add to diary | Serving size editable antes y despues de guardar | Priorizar base de datos, edicion granular y confianza sobre magia rapida |
| Cal AI | Foto principalmente; texto en versiones/flows modernos | LMM/IA multimodal cloud + base nutricional, ahora integrada con base MyFitnessPal | Snap -> estimate instantaneo -> usuario acepta/corrige | Rapido, menos granular que MFP; orientado a baja friccion | UX veloz vende; para Recvel hay que imitar velocidad, no claims exactos |
| Foodvisor | Foto, barcode, manual/voz segun mercado | Deep learning para reconocimiento + estimacion de cantidad + Ciqual/Open Food Facts | Foto -> reconoce alimentos/cantidad -> usuario revisa/corrige -> consejos | Usa forma/tamano/color/brillo; usuario puede revisar alimentos, condimentos y coccion | Mostrar componentes editables y pedir metodo/condimentos cuando afecten kcal |
| Lose It! Snap It | Foto + busqueda/manual + barcode | Reconocimiento visual historico tipo clasificador + base de alimentos | Foto -> guesses -> usuario corrige/loggea | Aproximado; requiere input manual cuando falla | Foto como atajo a logging, no como verdad final |
| Oura Meals | Foto + AI Advisor + CGM Dexcom/Stelo opcional | Generative AI sobre foto + contexto de salud/glucosa | Foto -> macros/nutritional value -> insights no juzgadores -> correlacion glucosa | No enfocado en precision calorica pura; lo conecta a respuesta metabolica | Recvel debe conectar comida con recovery/sueno/energia, no solo kcal |
| Zepp / Amazfit | Foto y descripcion de texto | LLM para interpretar imagen/texto y generar nutrition estimate | Describe o fotografia comida -> estimate -> aceptar | Reviewers reportan buen estimate general, porcion irregular | Texto libre + foto debe ser una experiencia central, especialmente para comida compleja |
| Passio Nutrition AI | Foto, texto, voz, barcode | SDK/API nutrition AI, documentacion reciente orientada a servicios remotos | SDK devuelve alimentos/nutrientes estructurados | Lo resuelve como producto vertical especializado | Re-evaluar solo si existe modo offline verificable o si se acepta cloud |
| SnapCalorie | Foto; posible depth/propietario | Modelo propietario + datos propios/calorimetria/estimacion de volumen | Foto -> estimate de energia/macros | Parece tratar volumen como problema central | Depth/LiDAR futuro es clave para cerrar brecha de precision |

### MyFitnessPal Meal Scan

MyFitnessPal documenta Meal Scan como feature Premium disponible en iOS/Android modernos. Su FAQ dice que usa machine learning y computer vision para detectar comida desde imagenes, con modelos propios entrenados en millones de imagenes, y luego sugiere alimentos verificados desde su base. El flujo publico es relevante: el usuario toma o sube foto, escoge uno de los alimentos sugeridos, ajusta serving size si hace falta y lo agrega al diario. Tambien permite busqueda manual si falta un alimento.

La adquisicion de Cal AI por MyFitnessPal en 2026 confirma una diferencia de posicionamiento: Cal AI optimiza velocidad y baja friccion; MyFitnessPal optimiza precision y granularidad. TechCrunch reporto que Cal AI ya se integro con la base de MyFitnessPal, que incluye millones de alimentos, decenas de miles de marcas y cientos de cadenas de restaurantes. Esa base es una ventaja enorme que un modelo local pequeno no reemplaza.

Que copiar:

- Foto o galeria como entrada inicial.
- Lista de sugerencias, no una sola respuesta.
- Ajuste de serving antes de guardar.
- Busqueda manual dentro del flujo cuando la IA falla.
- Edicion despues de guardar.

Que no copiar literalmente:

- Premium/paywall.
- Dependencia de backend y base propietaria.
- Promesa implicita de precision si Recvel no tiene el mismo coverage.

Fuentes: [MyFitnessPal Meal Scan FAQ](https://support.myfitnesspal.com/hc/en-us/articles/360045761612-Meal-Scan-FAQ) y [TechCrunch - MyFitnessPal adquiere Cal AI](https://techcrunch.com/2026/03/02/myfitnesspal-has-acquired-cal-ai-the-viral-calorie-app-built-by-teens/).

### Cal AI

Cal AI representa el patron comercial mas viral: tomar foto, obtener calorias/macros en segundos y reducir al minimo el trabajo del usuario. La cobertura de prensa lo describe como una app que usa IA para estimar nutricion desde imagen, separando componentes visibles y cruzandolos con una base de datos. Tambien documenta fallos tipicos: comida oculta en recipientes altos, mantequilla, miel, condimentos o ingredientes que la camara no ve.

La senal estrategica mas importante no es solo la tecnologia, sino la tension de producto: hay usuarios que prefieren rapidez sobre exactitud. Esa es una verdad de mercado. Recvel debe ofrecer un "quick estimate" igual de satisfactorio, pero visualmente marcado como editable y con chips de incertidumbre.

Que copiar:

- Resultado instantaneo tipo "estimate first".
- Lenguaje simple: kcal, protein, carbs, fat.
- Edicion posterior rapida.
- Experiencia gamificada/ligera, sin hacer sentir al usuario que esta llenando un formulario medico.

Que mejorar:

- Mostrar incertidumbres visibles: aceite, salsa, bebida, porcion oculta.
- Preguntar una o dos cosas maximo para cerrar el rango.
- Aprender localmente comidas repetidas.

Fuentes: [The Times - prueba de Cal AI](https://www.thetimes.co.uk/article/food-photo-app-counts-calories-does-it-work-g2wpxd09m) y [TechCrunch - adquisicion por MyFitnessPal](https://techcrunch.com/2026/03/02/myfitnesspal-has-acquired-cal-ai-the-viral-calorie-app-built-by-teens/).

### Foodvisor

Foodvisor es una referencia clasica para "foto del plato -> calorias". Fuentes publicas describen que analiza color, forma, tamano y brillo para estimar naturaleza y cantidad del alimento, y que usa bases nutricionales como Ciqual y Open Food Facts. La literatura academica de evaluacion de apps la destacaba como una de las pocas apps capaces de reconocer automaticamente alimentos y computar volumen/nutricion, aunque con necesidad de mejorar.

Lo mas importante para Recvel no es copiar su algoritmo, sino su UX conceptual: separar alimentos visibles, permitir revisar, agregar condimentos y definir metodo de coccion. Esa capa es crucial porque los errores grandes suelen venir de cosas invisibles en la foto.

Que copiar:

- Componentes editables por alimento.
- Campo/acciones para metodo de coccion.
- Condimentos y extras como primer-class citizens.
- Integracion barcode/Open Food Facts para empaquetados.

Riesgos observados:

- Dificultad con platos cocinados/mezclados.
- Condimentos invisibles no detectables por vision.
- Necesidad de usuario revisando el resultado.

Fuentes: [evaluacion academica de apps de food tracking](https://arxiv.org/abs/2208.02490) y [Foodvisor - resumen tecnologico y limites](https://fr.wikipedia.org/wiki/Foodvisor).

### Lose It! Snap It

Lose It! fue temprano con Snap It: foto de comidas/snacks para aproximar calorias. La historia del producto y pruebas de usuarios muestran el patron "foto como atajo" mas que "foto como verdad". Cuando falla, el usuario acaba corrigiendo manualmente.

Que copiar:

- Foto como diario visual ademas de conteo.
- Que la imagen ayude a memoria y adherencia, incluso si la prediccion falla.
- Mantener fallback manual siempre visible.

Que evitar:

- Hacer que corregir errores tome mas tiempo que registrar manualmente.

Fuentes: [Lose It! Snap It - resumen historico](https://en.wikipedia.org/wiki/Lose_It%21_%28app%29) y [SELF - prueba de Snap It](https://www.self.com/story/snap-it-photo-food-journal-for-weight-loss).

### Oura Meals

Oura no compite por el mejor contador de calorias puro; compite por contexto metabolico. Su feature Meals usa foto y Oura Advisor para estimar macros/nutritional value y, si el usuario usa Dexcom Stelo, relacionarlo con glucosa. Esta es una pista fuerte para Recvel: en una app de recovery, la nutricion debe conectarse con sueno, energia, entrenamiento y respuesta fisiologica, no vivir aislada.

Que copiar:

- Insights no juzgadores.
- Conectar comidas con senales de salud: sueno, energia, recovery, entrenamientos.
- No convertir todo en una obsesion por kcal.

Que adaptar:

- Recvel no tiene CGM en v1, pero puede correlacionar comidas con energia subjetiva, sueno y training readiness mediante Journal local.

Fuente: [The Verge - Oura Meals y glucose tracking](https://www.theverge.com/news/661069/oura-dexcom-stelo-meals-glucose-metabolic-health-wearables).

### Zepp / Amazfit

Zepp/Amazfit muestra el patron "texto o imagen a estimate" dentro de una app de wearables. Reviews recientes describen que el usuario puede escribir una comida como texto y recibir categorias nutricionales para aceptar. Esto encaja muy bien con Recvel porque muchas comidas complejas se describen mejor que se fotografian.

Que copiar:

- Texto libre como entrada principal, no secundaria.
- Foto + descripcion combinadas.
- Aceptar estimate rapidamente.

Que vigilar:

- Porcion irregular segun reviewers.
- Probable dependencia de LLM/cloud.

Fuentes: [Android Central - Zepp AI food logging](https://www.androidcentral.com/wearables/amazfit-t-rex-3-october-prime-day-2025-deal) y [Digital Camera World - Amazfit V1TAL Food Camera](https://www.digitalcameraworld.com/tech/this-flip-open-food-camera-uses-ai-to-track-everything-you-eat-but-it-is-not-meant-for-foodporn).

### Patrones comunes del mercado

1. **La foto sola no basta.** Todos los productos serios terminan necesitando porcion, serving, contexto o correccion.
2. **La base de datos importa tanto como el modelo.** MyFitnessPal gana por coverage; Foodvisor por bases nutricionales; Cal AI mejora al integrarse con MFP.
3. **La UX ganadora es estimate-first.** El usuario quiere un resultado inmediato y luego corregir, no llenar 12 campos antes de ver algo.
4. **La edicion debe ser tactil y rapida.** Chips, sliders, servings, busqueda manual y favoritos son mas importantes que una explicacion larga.
5. **Los mejores productos conectan comida con objetivos.** Oura lo conecta con glucosa/metabolismo; Recvel debe conectarlo con recovery, sleep, strain y energy.
6. **Cloud domina la precision comercial actual.** Local-first puede competir en privacidad y fluidez, pero necesita ser honesto con rangos/confianza.

### Implicaciones concretas para Recvel

El feature debe tener cuatro capas, en este orden:

1. **Quick Estimate:** foto/texto/voz -> estimate en segundos, visualmente pulido.
2. **Correction Layer:** chips de dudas, slider de porcion, serving, gramos, condimentos, metodo de coccion.
3. **Nutrition Resolver:** base local para convertir alimento+porcion en kcal/macros; el modelo no es la fuente final.
4. **Health Context:** explicar como esa comida se relaciona con energia, recuperacion, sueno, carga y objetivos del usuario.

MVP comercial recomendado:

- Camara + galeria + texto + voz.
- Resultado con kcal range, protein/carbs/fat, confidence y chips de incertidumbre.
- Selector de porcion: pequeno / normal / grande / gramos.
- Acciones rapidas: `+ aceite`, `+ salsa`, `+ bebida`, `+ postre`, `quitar item`.
- Base local curada + favoritos locales.
- Barcode/OCR como ruta de alta confianza.
- Historial de comidas repetidas y "usar de nuevo".
- Copy honesto: "estimado", "ajusta", "confianza".

No implementar todavia:

- Promesas de MAPE publico sin benchmark propio.
- Escribir en HealthKit sin pantalla de confirmacion.
- Alertas de dieta o claims clinicos.
- Cloud/SDK externo sin decision explicita de privacidad.

## Contradicciones encontradas en documentos previos

1. **Fine-tuning vs. no fine-tuning**

El documento anterior proponia Food-101, MobileNet/EfficientNet y conversion Core ML como ruta principal. Eso contradice la decision del usuario: no entrenar ni fine-tunear. Food-101 puede quedar como benchmark o referencia historica, pero no como plan v1.

2. **Clasificador de comida vs. modelo generativo**

Un clasificador Food-101 solo devuelve una etiqueta como `pizza` o `tacos`. No puede razonar sobre porcion, ingredientes visibles, acompanamientos ni formato JSON. Para el flujo deseado conviene un VLM pequeno ya entrenado.

3. **"Comparable a apps comerciales"**

Apps como Cal AI, Zepp, MyFitnessPal Meal Scan, Foodvisor o SnapCalorie suelen usar modelos cloud, bases privadas, LiDAR, feedback de usuarios o pipelines no publicados. No hay evidencia suficiente para prometer paridad con ellas en un sistema 100% local y sin entrenamiento propio.

4. **On-device vs. SDKs comerciales**

SDKs como Passio pueden acelerar producto, pero su documentacion actual apunta a APIs remotas/LLMs cloud para el modo principal de photo logging. Eso no cumple local-first v1 salvo que se apruebe una excepcion de producto.

5. **Calorias desde memoria del modelo**

Pedirle al modelo "cuantas calorias tiene esto" usa conocimiento parametrico y puede alucinar. Mejor: el modelo identifica alimentos y cantidades aproximadas; Recvel calcula con una base local.

## Modelos candidatos sin fine-tuning

### Matriz de licencia y costo

| Componente | Tipo | Licencia/costo | Decision Recvel |
| --- | --- | --- | --- |
| SmolVLM-256M-Instruct | VLM imagen+texto | Apache 2.0 / gratis | **Candidato principal** |
| Moondream2 | VLM imagen+texto | Apache 2.0 / gratis | **Candidato principal alterno** |
| Qwen2.5-0.5B/1.5B-Instruct | Texto | Apache 2.0 / gratis en variantes no-3B | Candidato para texto local si necesitamos LLM |
| Qwen2.5-VL-3B-Instruct | VLM imagen+texto | Qwen Research / non-commercial | **Bloqueado para v1** |
| Qwen2.5-VL-7B/32B | VLM imagen+texto | Apache 2.0 en variantes mayores | Licencia mejor, pero demasiado pesado para v1 iPhone |
| Apple FastVLM | VLM imagen+texto | Research license / no producto comercial | **Bloqueado** salvo licencia nueva |
| Apple Foundation Models | Texto/razonamiento | API propietaria de plataforma, no open source | Opcional experimental, no core OSS |
| Passio Nutrition AI | SDK/API nutrition | Comercial/API/SDK externo | **Bloqueado** por no ser OSS/cero costo |
| USDA FoodData Central/FNDDS | Datos nutricionales | Dominio publico / gratis | **Fuente principal** |
| Open Food Facts | Datos barcode | ODbL / gratis con obligaciones | Permitido con atribucion/share-alike |
| MLX Swift / llama.cpp | Runtime | Open source / gratis | Permitido si cumple rendimiento |

### 1. SmolVLM / SmolVLM2

**Uso recomendado:** candidato principal para POC local de imagen.

Ventajas:

- Modelo vision-language pequeno.
- Licencia permisiva en variantes publicadas por Hugging FaceTB.
- Adecuado para pedir JSON con alimentos visibles, porciones aproximadas y dudas.
- Mucho mas razonable para iPhone que VLMs de 7B+.

Riesgos:

- No es un modelo nutricional.
- La conversion directa a Core ML puede no estar lista segun arquitectura/version; probablemente haya que evaluar MLX Swift, GGUF/llama.cpp o un runtime equivalente.
- Su estimacion de porcion/calorias no debe ser fuente final.

Prompt objetivo:

```text
You are helping log a meal. Return strict JSON only.
Estimate visible foods, likely portion, kcal range and macros.
If uncertain, say what user must confirm.
Never invent hidden ingredients.
```

Salida esperada:

```json
{
  "items": [
    {
      "name": "tacos al pastor",
      "quantity_guess": "3 small tacos",
      "portion_confidence": "medium",
      "kcal_range": [450, 750],
      "protein_g_range": [18, 35],
      "carbs_g_range": [45, 80],
      "fat_g_range": [15, 35],
      "uncertainties": ["oil", "tortilla size", "sauce"]
    }
  ],
  "needs_user_input": ["confirm number of tacos", "confirm drink or sides"],
  "overall_confidence": "medium"
}
```

Fuente: [SmolVLM-256M-Instruct](https://huggingface.co/HuggingFaceTB/SmolVLM-256M-Instruct)

### 2. Moondream2

**Uso recomendado:** candidato fuerte si el runtime iOS resulta mas simple o mas rapido que SmolVLM.

Ventajas:

- VLM pequeno, conocido por correr en entornos ligeros.
- Licencia permisiva.
- Bueno para preguntas visuales simples y descripciones.

Riesgos:

- Mas pesado que un clasificador pequeno.
- No esta especializado en comida ni nutricion.
- Necesita POC real en iPhone para medir latencia, RAM, temperatura y tamano de bundle.

Fuente: [Moondream2](https://huggingface.co/vikhyatk/moondream2)

### 3. Qwen para texto, no Qwen2.5-VL-3B para imagen

**Uso recomendado:** solo texto local, si las reglas/NaturalLanguage no alcanzan.

La familia Qwen es mixta: algunas variantes son Apache 2.0 y otras no. Para Recvel, los candidatos aceptables son modelos de texto pequenos con licencia permisiva, por ejemplo Qwen2.5-0.5B/1.5B-Instruct si se verifica Apache 2.0 antes de integrarlos. Sirven para transformar texto como "2 tacos de pollo, 1 agua de jamaica chica" en JSON.

Bloqueo importante:

- **Qwen2.5-VL-3B-Instruct no queda permitido para v1** porque su variante 3B/VL aparece bajo Qwen Research/non-commercial, no una licencia open source permisiva.
- Qwen2.5-VL-7B/32B tienen mejor situacion de licencia segun listados publicos, pero son demasiado grandes para ser default local en iPhone.
- No usar ningun Qwen sin verificar el archivo `LICENSE` exacto del repositorio/modelo elegido.

Fuentes: [Qwen2.5-VL-3B-Instruct](https://huggingface.co/Qwen/Qwen2.5-VL-3B-Instruct) y [Qwen model family overview](https://en.wikipedia.org/wiki/Qwen)

### 4. Apple FastVLM

**Uso recomendado:** investigacion interna solamente, no producto v1.

Ventajas:

- Muy prometedor tecnicamente para iPhone.
- Apple publico demo y modelos orientados a baja latencia.

Bloqueo:

- La licencia de investigacion de Apple no es apropiada para integrar en un producto comercial sin revisar derechos/licencia. No usar en Recvel app hasta resolver licencia.

Fuente: [Apple ML FastVLM](https://github.com/apple/ml-fastvlm)

### 5. Apple Foundation Models

**Uso recomendado:** opcional experimental, no dependencia core si la regla es open source estricta.

Ventajas:

- On-device.
- Integrado en plataformas Apple modernas.
- Ideal para extraction/classification/summarization con guided generation.
- Puede convertir texto como "2 huevos, una tortilla, medio aguacate" a JSON.

Riesgos:

- No es open source.
- No debe usarse como base de datos nutricional.
- Disponibilidad depende de OS/dispositivo.
- Recvel soporta iOS 17+, asi que necesita fallback.

Decision: bajo la regla "open source/no licencias/no suscripciones", Foundation Models no debe ser la ruta principal. Puede quedar como optimizacion opcional si el usuario acepta APIs propietarias de plataforma, pero el core debe funcionar con parser local/reglas y/o modelos open weights permisivos.

Fuente: [Apple Foundation Models](https://developer.apple.com/documentation/foundationmodels)

## SDKs comerciales evaluados

### Passio Nutrition AI

Passio es la opcion mas cercana a "ya hecho": foto, texto, voz, barcode y resultados nutricionales estructurados.

Ventajas:

- Producto enfocado especificamente en nutrition AI.
- Mucho mas rapido de integrar que resolver VLM + DB + UX desde cero.
- Probablemente mejor cobertura nutricional que un VLM general pequeno.

Problema para Recvel v1:

- Su documentacion actual apunta a APIs remotas/LLMs cloud para capacidades principales recientes.
- Eso rompe la restriccion local-first/sin backend.
- Requiere revisar licencia, costos, privacidad y modo offline real.
- No cumple la nueva restriccion de open source/cero licencias pagadas.

Decision: no usar en v1. Re-evaluar solo si existe una version open source/gratis verificable, cosa que hoy no es el caso.

Fuente: [Passio Nutrition AI](https://passio.gitbook.io/nutrition-ai)

## Base nutricional local

Aunque el modelo genere kcal aproximadas, Recvel debe calcular el valor final con una base local cuando sea posible.

Fuentes recomendadas:

- **USDA FoodData Central / FNDDS:** alimentos genericos, porciones tipicas y nutrientes.
- **Open Food Facts:** productos empaquetados por barcode, con obligaciones de licencia/atribucion.
- **Tabla curada Recvel MX/LatAm:** tacos, tortillas, pan dulce, salsas, bebidas, bowls y comidas comunes que no siempre mapean bien a Food-101/USDA.

Decision:

- v1 debe incluir una base pequena local curada.
- Barcode/OCR debe ser la ruta de mayor confianza.
- Open Food Facts completo no debe empaquetarse; pesa demasiado y tiene licencia ODbL. Usar solo si se acepta descarga/API o un subset curado con atribucion correcta.

Fuentes: [USDA FoodData Central Downloads](https://fdc.nal.usda.gov/download-datasets/) y [Open Food Facts Data](https://world.openfoodfacts.org/data)

## Porcion: el limite central

El problema no es solo reconocer "pizza"; es saber si fueron 90 g, 140 g o 230 g, cuanto aceite tenia, si habia queso extra, si la bebida tenia azucar, etc.

Niveles de confianza:

| Entrada | Confianza esperada | Motivo |
| --- | --- | --- |
| Barcode + etiqueta | Alta | Nutrientes definidos por producto |
| Texto con cantidades claras | Media-alta | "2 huevos", "250 ml", "100 g" |
| Foto de alimento simple + porcion confirmada | Media | El usuario corrige escala |
| Foto de plato mixto | Baja-media | Ingredientes ocultos y porciones ambiguas |
| Foto sin escala ni contexto | Baja | El modelo adivina volumen |

Regla UX:

- Mostrar kcal como rango cuando no haya porcion confirmada.
- Mostrar chips de incertidumbre: "aceite", "salsa", "tamano", "bebida", "acompanamientos".
- Pedir una sola correccion rapida, no un formulario pesado.

## Arquitectura recomendada para Recvel v1

### Ruta A - 100% local, sin fine-tuning

Esta es la ruta alineada con el producto actual.

1. Foto entra a `NutritionEstimator`.
2. Modelo local existente: SmolVLM/Moondream via runtime iOS.
3. El modelo devuelve JSON estricto.
4. Recvel normaliza nombres contra base local.
5. Recvel calcula kcal/macros con porciones tipicas.
6. UI muestra resultado editable.
7. Usuario confirma.
8. Se guarda en SwiftData; HealthKit opcional si se decide escribir nutricion.

Pros:

- Privacidad fuerte.
- Sin backend.
- Sin entrenamiento propio.
- Diferenciador claro frente a competidores cloud.

Contras:

- Accuracy limitada.
- POC tecnico necesario para runtime/modelo.
- No competir en "magia" con GPT-4o cloud.

### Ruta B - texto open-source + VLM local para foto

1. Texto/voz usa parser local deterministico; si no alcanza, un modelo de texto open weights permisivo pequeno.
2. Foto usa SmolVLM/Moondream.
3. Ambos devuelven el mismo schema JSON.
4. Base nutricional local resuelve numeros.

Esta es la ruta preferida bajo la regla open source/no pagos. Foundation Models puede quedar como experimento opcional de plataforma, pero no como requisito ni dependencia principal.

### Ruta C - descartada: SDK comercial

Usar Passio u otro SDK podria acelerar producto, pero no cumple la restriccion actual.

Pros:

- Mas producto inmediato.
- Menos investigacion de modelos.

Contras:

- Posible cloud.
- Costos/licencia.
- Privacidad distinta a la promesa de Recvel.
- Dependencia externa.

Decision actual: no usar Ruta C en v1.

## Schema JSON recomendado

Todos los modelos deben responder al mismo contrato. Nada se guarda si no valida contra este schema.

```json
{
  "source": "image|text|voice|barcode|ocr",
  "meal_name": "string",
  "items": [
    {
      "display_name": "string",
      "canonical_query": "string",
      "quantity_text": "string",
      "grams_estimate": 0,
      "kcal_range": [0, 0],
      "protein_g_range": [0, 0],
      "carbs_g_range": [0, 0],
      "fat_g_range": [0, 0],
      "confidence": "low|medium|high",
      "uncertainties": ["string"],
      "needs_user_confirmation": true
    }
  ],
  "missing_context_questions": ["string"],
  "overall_confidence": "low|medium|high"
}
```

Reglas:

- Si el modelo devuelve un numero unico, Recvel lo convierte a rango.
- Si no hay porcion clara, `confidence` no puede ser `high`.
- Si hay plato mixto, siempre pedir confirmacion.
- No aceptar alimentos sin `canonical_query`.
- No aceptar macros negativos o kcal imposibles.

## Prompt recomendado para imagen

```text
You are a meal logging assistant for a wellness app.
Analyze the image and return strict JSON only.

Rules:
- Do not diagnose health.
- Do not claim exact calories.
- Identify visible foods only.
- Estimate portions conservatively.
- If portion, oil, sauce, sugar, or side dishes are unclear, include them in uncertainties.
- Return kcal/macros as ranges.
- Ask for at most 2 missing context questions.

JSON schema:
{
  "meal_name": string,
  "items": [
    {
      "display_name": string,
      "canonical_query": string,
      "quantity_text": string,
      "grams_estimate": number,
      "kcal_range": [number, number],
      "protein_g_range": [number, number],
      "carbs_g_range": [number, number],
      "fat_g_range": [number, number],
      "confidence": "low" | "medium" | "high",
      "uncertainties": string[],
      "needs_user_confirmation": boolean
    }
  ],
  "missing_context_questions": string[],
  "overall_confidence": "low" | "medium" | "high"
}
```

## Prompt recomendado para texto/voz

```text
Extract a meal log from the user's text.
Return strict JSON only.
Do not use memory to invent exact nutrition.
Preserve quantities and units exactly when present.
If quantity is missing, use a typical portion and mark confidence lower.

User text:
"{{transcript}}"
```

## POC necesario antes de implementacion en app

Antes de meter un VLM al target principal:

1. Probar SmolVLM y Moondream en Mac con 20 fotos reales.
2. Medir si devuelven JSON estable.
3. Probar conversion/runtime iOS: Core ML, MLX Swift o llama.cpp/GGUF.
4. Medir en iPhone real: latencia, memoria, tamano, temperatura y consumo.
5. Comparar contra baseline simple de texto + base nutricional.
6. Decidir si el modelo va embebido o descargable.

Criterios minimos:

- Latencia objetivo: menos de 5-8 s por foto en iPhone reciente.
- No crashear por memoria.
- Bundle razonable o descarga explicita del modelo.
- 80%+ respuestas parseables como JSON en dataset de prueba.
- UI siempre editable.

## Conclusion propia

La mejor ruta para Recvel no es Food-101 ni fine-tuning. Tampoco es prometer que un modelo local pequeno detectara calorias con precision alta desde cualquier foto.

La ruta mas fuerte es:

1. **Texto/voz:** parser local/reglas primero; si hace falta, modelo de texto open weights permisivo y pequeno.
2. **Foto:** SmolVLM o Moondream sin fine-tuning como asistente visual.
3. **Numeros:** base nutricional local, no memoria del modelo.
4. **Precision:** alta solo con barcode/OCR/gramos confirmados.
5. **UX:** resultado rapido, glassy, editable, con chips de incertidumbre y ajuste de porcion.
6. **Licencias:** core open source/open weights permisivo o dominio publico. Modelos Apache 2.0/MIT, datos USDA, herramientas MIT/Apache/BSD. Nada de Passio, OpenAI, Anthropic, Google Cloud ni SDK/herramienta de pago.

Esta decision respeta la promesa de Recvel: local-first, privado, moderno, honesto y **sin licencias pagadas ni suscripciones**. Puede sentirse muy avanzado sin vender una precision que la tecnologia local actual todavia no garantiza.

## Referencias

- [SmolVLM-256M-Instruct](https://huggingface.co/HuggingFaceTB/SmolVLM-256M-Instruct)
- [Moondream2](https://huggingface.co/vikhyatk/moondream2)
- [Qwen2.5-VL-3B-Instruct - referencia de licencia bloqueada](https://huggingface.co/Qwen/Qwen2.5-VL-3B-Instruct)
- [Apple FastVLM - referencia de licencia bloqueada](https://github.com/apple/ml-fastvlm)
- [Apple Foundation Models - API opcional no open source](https://developer.apple.com/documentation/foundationmodels)
- [Apple Core ML](https://developer.apple.com/documentation/coreml)
- [MLX Swift Examples](https://github.com/ml-explore/mlx-swift-examples)
- [Passio Nutrition AI - referencia descartada por licencia/costo](https://passio.gitbook.io/nutrition-ai)
- [USDA FoodData Central Downloads](https://fdc.nal.usda.gov/download-datasets/)
- [Open Food Facts Data](https://world.openfoodfacts.org/data)
- [Nutrition5k](https://github.com/google-research-datasets/Nutrition5k)
- [Survey: image-based food recognition and volume estimation](https://arxiv.org/abs/2106.11776)

---

## 9. Uso personal (julio 2026): APIs con tier gratuito y modelos research-only ahora aceptables

**Cambio de restriccion:** el uso de Recvel es exclusivamente personal, no se distribuye ni se vende. Esto relaja dos reglas de la seccion "Restriccion de licencias" de arriba, que seguian siendo la norma correcta para un producto publico/comercial:

- **Modelos con licencia research-only/non-commercial ya son aceptables** (no hay "product development" ni "commercial exploitation" al ser un proyecto personal no distribuido).
- **APIs en la nube con tier gratuito real (no de pago) ya son aceptables**, aunque no sean open source, siempre que no impliquen costo obligatorio ni una suscripcion.

Sigue **sin ser aceptable**: cualquier cosa que cueste dinero de forma obligatoria (sin tier gratuito perpetuo) o que exija ceder las fotos/datos para entrenamiento como unica via de acceso gratuito.

### 9.1 APIs cloud genericas con tier gratuito — verificadas julio 2026

| API | Tier gratuito real | Limite | Vision de comida util | Recomendacion |
| --- | --- | --- | --- | --- |
| **OpenRouter** (modelos `:free`) | Si, perpetuo | 50 req/dia (hasta 1,000 req/dia si se ha gastado $10+ historico), 20 req/min | Si — `google/gemma-4-31b-it:free`, `google/gemma-4-26b-a4b-it:free`, `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free` aceptan imagen | **Usar ya** como fallback cloud cuando el modelo local no alcance |
| **Google Gemini API (Flash/Flash-Lite)** | Si, pero Gemini **Pro ya no esta en el tier gratis** desde abril 2026 | Cifras exactas ya no publicadas en la pagina oficial de precios; hay que verificar cuota en vivo en [aistudio.google.com/rate-limit](https://aistudio.google.com/rate-limit) por proyecto | Si — modelo grande, buen razonamiento nutricional | **Evaluar**, verificando cuota real antes de depender de ella |
| **Google Cloud Vision (Label/Object Detection generico)** | Si, perpetuo | 1,000 unidades/mes gratis, luego $1.50/1,000 | Baja para macros — solo etiquetas genericas tipo "pizza"/"salad" | **Evaluar** solo como pre-filtro grueso, no como solucion principal |
| **Groq API** | Si, sin tarjeta | ~30 RPM/6,000 TPM/1,000 RPD (varia por modelo) | Incierto — soporte de vision no solido/confirmado en el tier gratis al momento de esta investigacion | **Evaluar** verificando lista de modelos vigente antes de depender |
| **Hugging Face Inference Providers** | Si (creditos mensuales por cuenta) | "Unas cientas de requests/hora", cold starts, modelos <10B | Variable | **Evaluar** para prototipar, no para uso diario confiable |
| **OpenAI API** | **No hay tier gratuito real** en julio 2026 (el credito de bienvenida se descontinuo a mediados de 2025) | Solo hay tokens gratis si aceptas el programa de compartir tus datos para entrenamiento (~1M tokens/dia) | Alta, pero con costo de privacidad real: tus fotos de comida entrenarian el modelo de OpenAI | **Descartar**, salvo que aceptes explicitamente ceder tus fotos de comida para entrenamiento — no recomendado para un feature de salud personal |
| **Together.ai / Fireworks.ai / Replicate** | No — solo creditos iniciales de un solo uso, no tier gratuito perpetuo | Fireworks: ~$1 unico; Together: variable, no recurrente | Alta pero temporal | **Descartar** bajo el criterio de "tier gratuito real y recurrente" |

### 9.2 APIs especificas de nutricion/comida — verificadas julio 2026

| API | Tier gratuito real | Motivo |
| --- | --- | --- |
| **USDA FoodData Central API** (no solo el dump descargable) | **Si, gratis y practicamente ilimitado** | 1,000 requests/hora por API key, sin costo nunca, datos CC0. Solo busqueda de nutrientes por nombre, no reconoce fotos. **Usar ya** como backend de macros una vez identificado el alimento. |
| **Edamam** (Food Database / Nutrition Analysis) | Si, plan "Basic" (verificar vigencia en developer.edamam.com antes de integrar) | ~1,000 req/dia reportado. Solo texto/base de datos, sin analisis de foto. **Evaluar** como alternativa/complemento a USDA. |
| **Spoonacular** | Tier gratis existe pero **muy limitado**: 50 puntos/dia | No esta confirmado si el endpoint de analisis de imagen cabe dentro de esos 50 puntos/dia sin agotarse en 1-2 llamadas — verificar el costo en puntos de ese endpoint especifico antes de integrar. **Evaluar con cautela**. |
| **LogMeal** (API dedicada a reconocimiento de comida) | **No** — solo 30 dias de trial, luego exige plan pago | **Descartar**, no es tier gratuito perpetuo. |
| **Nutritionix** | **No** — el tier gratuito publico fue discontinuado, ahora es solo enterprise desde $299/mes | **Descartar**. |
| **CalorieMama** | **No** — solo 3 meses de trial, luego facturacion mensual obligatoria | **Descartar**. |

### 9.3 Modelos locales research-only ahora aceptables (uso personal, no distribuido)

**Apple FastVLM (0.5B / 1.5B / 7B)** — con la licencia de investigacion ya no siendo bloqueante para un proyecto personal, este es el candidato mas fuerte tecnicamente:

- Ya viene **listo en formato Core ML y MLX directamente en Hugging Face** (`apple/FastVLM-0.5B`, etc.) — no requiere paso de conversion.
- El repo oficial `apple/ml-fastvlm` incluye **apps de demo iOS/macOS ya armadas** para compilar en Xcode.
- Hasta 85x mas rapido en "time to first token" que LLaVA-OneVision-0.5B comparable, y 3.4x mas pequeno.
- **Nota de precaucion incluso para uso personal**: el texto exacto de la licencia (`LICENSE_MODEL`) prohibe "product development" de forma amplia, no solo "venta" — es una zona legal gris incluso para un proyecto personal no distribuido; razonable de usar en un experimento propio, pero no es un "todo claro" al 100%, a diferencia de Apache 2.0/MIT.
- Fuentes: [apple/ml-fastvlm](https://github.com/apple/ml-fastvlm), [LICENSE_MODEL](https://github.com/apple/ml-fastvlm/blob/main/LICENSE_MODEL), [apple/FastVLM-0.5B en Hugging Face](https://huggingface.co/apple/FastVLM-0.5B), [Apple ML Research](https://machinelearning.apple.com/research/fast-vision-language-models).

**Qwen2.5-VL-3B-Instruct** — licencia Qwen Research (non-commercial), buenos resultados en benchmarks generales de VQA (MathVista/DocVQA/RealWorldQA segun Qwen), pero **no se encontro evidencia especifica de alguien corriendolo on-device en iPhone con tiempos medidos** (a diferencia de FastVLM, que si tiene esa validacion). **Evaluar como comparacion**, sin la misma confianza de despliegue en iPhone que FastVLM.

No se encontro ningun otro VLM research-only 2025-2026 optimizado para telefono que supere claramente a estos dos candidatos.

### 9.4 Recomendacion de arquitectura actualizada para uso personal

1. **Foto — modelo local primero:** Apple FastVLM 0.5B o 1.5B (Core ML/MLX listo, demo oficial de Apple) para identificar el plato y estimar porcion/candidatos.
2. **Foto — fallback cloud opcional:** si FastVLM no da suficiente confianza, usar un modelo de vision gratis de **OpenRouter** (`google/gemma-4-31b-it:free` o similar) como segunda opinion, dentro del limite diario gratuito.
3. **Numeros de calorias/macros:** siempre resueltos por **USDA FoodData Central API** (gratis, sin limite practico) contra el alimento identificado — nunca desde la memoria del modelo de vision.
4. **Texto/voz:** parser local + USDA API para el numero; Edamam como respaldo si se confirma vigente.
5. **Se mantiene la regla de UI:** rango editable, confianza visible, confirmacion humana antes de guardar — esto no cambia por usar modelos/APIs distintos, sigue siendo la misma UX honesta del resto de este documento.

Esta seccion no reemplaza la seccion "Restriccion de licencias" de arriba (esa sigue siendo la norma correcta si Recvel alguna vez se distribuye publicamente); documenta especificamente que cambia porque el uso actual es personal.

---

# PROPUESTAS DE NUEVOS FEATURES (fuera del alcance de calorias/IA — seccion aparte)

> **Aviso claro:** todo lo que sigue de aqui en adelante es investigacion para un **feature nuevo, distinto al de calorias/nutricion con IA** que ocupa el resto de este documento. Se guarda aqui porque asi se pidio, pero es una unidad de investigacion separada: **ayuno intermitente (intermittent fasting)**. No mezclar con las decisiones de arquitectura de calorias de las secciones 1-9 de arriba.

## 10. Ayuno intermitente: investigacion de competidores (julio 2026)

### 10.1 Como lo hacen las apps lideres

**Zero (Zero Fasting / Zero Longevity Science)** — la app referente de la categoria.
- Protocolos: 11+ perfiles (circadiano ~12-13h, 16:8, 18:6, 20:4, OMAD, ayunos custom hasta 7 dias tipo "Monk fast" 36h+).
- Etapas metabolicas mostradas, personalizadas por edad/peso/actividad en onboarding: Fat Burning (~16h), Ketosis Zone (24-72h), Deep Ketosis (72h+), Autophagy (desde ~24h, "elevada" 36-72h).
- Timer: anillo circular que cambia de color por zona metabolica.
- "AI Fasting Coach" con planes semanales.
- HealthKit: peso, pasos, calorias, hidratacion.
- Free vs Premium (~$70/ano): gratis = timer y zonas basicas; premium = analiticas de correlacion (peso/FC/sueno/glucosa), "Fat-Burning Mode", contenido de comite medico, retos comunitarios, presets custom.
- Social: app aparte "Zero Social" + retos grupales en premium.
- Fuentes: [Zero App Store](https://apps.apple.com/us/app/zero-fasting-food-tracker/id1168348542), [Zero Longevity blog](https://zerolongevity.com/blog/zero-101/), [Fat Burning Mode](https://zerofasting.zendesk.com/hc/en-us/articles/21216678252187-Fat-Burning-Mode), [pricing](https://zerofasting.zendesk.com/hc/en-us/articles/4402526584091-How-Much-Does-A-Zero-Plus-Subscription-Cost)

**Fastic** — "Body Status" (visualizacion de fases), coach algoritmico + chatbot IA "Fasty" (premium), gamificacion con estrellas/badges/retos, tracker de comidas/agua, sync Apple Health. Premium (~$30-75/ano o $14.99/mes): 4500+ recetas, chat con Fasty, estadisticas avanzadas, Fastic Academy, "Fasting Buddies" (comunidad). Fuentes: [Fastic App Store](https://apps.apple.com/us/app/fastic-weight-loss-fasting/id1459260306), [review](https://www.bentobunny.app/reviews/fastic-review)

**BodyFast** — 10+ planes, progresion pensada para principiantes (empezar corto, subir gradual), "BodyFast Coach" da plan semanal adaptado, HealthKit (peso, cetonas). Premium (~$1.35/semana o $70/ano): plan personalizado, 100+ recetas, retos, SOS de expertos, trofeos, "Joker Day" (dia libre sin romper racha). Free: timer, hasta 10 metodos, tracking peso/medidas/agua. Fuentes: [BodyFast oficial](https://www.bodyfast.app/en/), [App Store](https://apps.apple.com/us/app/bodyfast-intermittent-fasting/id1189568780)

**Simple (AI Weight Loss Coach)** — fusiona ayuno + nutricion + coaching conversacional via chatbot "Avo" (respuestas en tiempo real, "Avo Vision" analiza fotos de comida/menu). Free: 2 respuestas Avo/dia, 1 foto Avo Vision/dia. Premium: uso ilimitado. Fuentes: [Simple.life](https://simple.life/), [Ask Avo](https://help.simple.life/en/articles/9887914-how-to-use-avo-your-24-7-health-coach)

**LIFE Fasting Tracker (LifeOmic)** — diferenciador: "LIFE Circles", comunidad social donde ves en tiempo real quien mas esta ayunando, das/recibes animo en circulos personalizados, comparte datos con clinicos/investigadores via "Precision Health Cloud". Reputacion de ser la suscripcion mas barata de la categoria. Fuentes: [Medium — LifeOmic](https://medium.com/lifeomic/life-the-socially-connected-intermittent-fasting-app-that-leverages-precision-medicine-ab9382de0c5f), [App Store](https://apps.apple.com/us/app/life-fasting-tracker/id6743002173)

**Wearables/competidores generales de wellness:**
- **Garmin**: si tiene integracion nativa — "Intermittent Fasting Widget" (Connect IQ) con Start/Stop Fasting en el reloj. Fuente: [Garmin IF widget](https://apps.garmin.com/en-US/apps/99b3664b-f421-4706-b346-b0527dbf0eb1)
- **Whoop**: no tiene tracker de ayuno nativo; solo un "team"/comunidad de "Intermittent Fasters" dentro de su feature social, sin logica de producto dedicada.
- **Oura**: no se encontro feature de ayuno dedicado; solo permite "tags" de comportamiento (alcohol, comidas tardias, meditacion) correlacionados con recovery.
- **Bevel**: no tiene tracker de ayuno dedicado (tiene nutrition tracking con IA y monitoreo de glucosa, pero ningun modulo de ayuno explicito encontrado a julio 2026).

### 10.2 Patron visual del "reloj de ayuno" (para replicar conceptualmente, sin copiar assets)

Patron convergente en todas las apps lideres, util como referencia de diseno propio para Recvel (consistente con el sistema Liquid Glass ya usado en el resto de la app):

- **Anillo circular de progreso** (no barra lineal), tiempo transcurrido/restante en numeros grandes al centro.
- El anillo se rellena progresivamente y **cambia de color por segmento/fase metabolica** (ej. azul = estado alimentado/digestion, verde/amarillo = quema de glucogeno, naranja = quema de grasa, purpura = cetosis).
- Marcadores/hitos en el anillo indicando la hora aproximada de cada fase, tappables para explicacion educativa breve.
- Cuenta regresiva al objetivo de la ventana actual + boton grande "Start/End Fast".
- Tarjeta secundaria explicando la fase actual en 1-2 lineas.
- Historial tipo calendario/racha con barras horizontales por dia mostrando duracion de cada ayuno.
- Fuentes: [Fasted app](https://getfasted.app/), [Design+Code SwiftUI fasting timer tutorial](https://designcode.io/quick-apps-swiftui-fasting-timer-app-1/), [Fasting Phases Calculator](https://fastingphases.com/)

### 10.3 Base cientifica real de las "etapas metabolicas" — punto critico para el copy de Recvel

Hallazgo importante: **el marketing de estas apps es mas preciso y confiado de lo que la evidencia en humanos respalda.**

- **Glucogeno hepatico**: se agota en **18-24h**, esto si tiene buen respaldo fisiologico clasico establecido.
- **Cetosis**: el rango marketeado varia mucho entre apps (12-18h hasta 24-72h) porque depende fuertemente de la dieta previa, ejercicio y estado metabolico individual. **No hay una hora universal fija** — cualquier app que afirme "a las X horas entras en cetosis" simplifica un proceso muy variable entre personas.
- **Autofagia — el punto mas debil cientificamente**:
  - La mayoria de la evidencia de "inicio a las 24-48h" viene de **estudios en ratones**, no humanos.
  - En humanos **no hay un punto horario confirmado**: dificil de medir en personas vivas, varia por organo, edad y salud metabolica.
  - Un estudio con 21 voluntarios a las 24h de ayuno **no encontro diferencias significativas** en marcadores de autofagia en musculo esqueletico.
  - La evidencia de autofagia significativa a las 16h (la ventana mas popular de marketing, 16:8) es **debil/escasa**.
  - Conclusion: cuando una app lider dice "autophagy begins ~24h, significativamente elevada 36-72h", presenta como preciso algo que en la ciencia real es un rango amplio con base mayormente animal.
- Fuentes: [ScienceInsights — autophagy onset](https://scienceinsights.org/when-do-you-reach-autophagy-during-fasting/), [PMC — RCT crossover autophagy fasting](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11677747/), [ScienceDirect — prolonged IF autophagy inflammasome senescence](https://www.sciencedirect.com/science/article/pii/S2666149723000063), [Superpower — glycogen depletion](https://superpower.com/guides/how-long-to-deplete-glycogen), [Cleveland Clinic — autophagy](https://my.clevelandclinic.org/health/articles/24058-autophagy)

**Regla de copy recomendada para Recvel (consistente con el resto del proyecto):** evitar afirmaciones tipo "ahora estas en autofagia" y usar lenguaje matizado tipo *"en ayunos prolongados, la investigacion sugiere que procesos como la autofagia podrian activarse en algun punto entre 24-48h, aunque la evidencia en humanos es limitada y mayormente proviene de estudios animales"*. Mostrar fases como **estimaciones poblacionales aproximadas**, nunca como una medicion del estado real del usuario.

### 10.4 HealthKit y ayuno

**No existe un `HKCategoryType` ni `HKWorkoutActivityType` nativo especifico para "fasting"** en el SDK de Apple (confirmado en la documentacion oficial de Apple Developer). Las apps lideres guardan el ayuno como dato custom en su propia base de datos, y solo sincronizan con HealthKit los tipos ya existentes relacionados: peso (`HKQuantityTypeIdentifier.bodyMass`), agua (`dietaryWater`), pasos, calorias activas, y glucosa si el usuario tiene sensor. Garmin es la excepcion, pero via su propio SDK Connect IQ, fuera de HealthKit.

**Implicacion para Recvel**: el ayuno tendria que vivir como un modelo custom local (`FastingSession` en SwiftData, coherente con `MealLog`/`HabitLog` ya existentes), sin tipo de HealthKit dedicado que aprovechar directamente, pero sincronizando peso/agua si Recvel ya toca esos tipos. Fuentes: [HKCategoryType docs](https://developer.apple.com/documentation/healthkit/hkcategorytype), [Data types docs](https://developer.apple.com/documentation/healthkit/data-types)

### 10.5 Modelo de negocio: que va detras del paywall (senal de que es "nice to have" vs esencial)

| App | Gratis | Detras del paywall |
| --- | --- | --- |
| Zero | Timer basico, zonas metabolicas core | Analiticas de correlacion, Fat-Burning Mode, contenido medico experto, retos comunitarios, presets custom |
| Fastic | Timer, Body Status basico | Chat con Fasty (IA), 4500+ recetas, Fastic Academy, retos, Fasting Buddies |
| BodyFast | Timer, hasta 10 planes, tracking peso/agua | Plan semanal del coach, 100+ recetas, retos, SOS de expertos, trofeos, Joker Day |
| Simple | Avo limitado (2 respuestas/dia) | Avo/Avo Vision ilimitado, coaching profundo |
| LIFE | — (la mas barata de la categoria) | Suscripcion de bajo costo para funciones extendidas |

### 10.6 Tabla comparativa de features

| Feature | Zero | Fastic | BodyFast | Simple | LIFE |
| --- | --- | --- | --- | --- | --- |
| Protocolos (16:8, 18:6, 20:4, OMAD, 5:2, custom) | Si, amplio (11+) | Si | Si (10+) | Si, personalizado | Si |
| Etapas metabolicas visualizadas | Si, detallado | Si ("Body Status") | Si | Parcial | No destacado |
| Integracion HealthKit | Si (peso, pasos, calorias, agua) | Si | Si (peso, cetonas) | Parcial | No confirmado |
| Gamificacion (rachas, badges) | Retos premium | Estrellas, badges, retos | Trofeos, Joker Day | No es el foco | No es el foco |
| Coach IA / chatbot | AI Fasting Coach | Fasty (premium) | Coach algoritmico | Avo (foco central) | No |
| Comunidad/social | Retos premium + app aparte | Fasting Buddies (premium) | No destacado | No es el foco | LIFE Circles (foco central) |
| Premium vs gratis | Freemium fuerte (~$70/ano) | Freemium fuerte | Freemium (~$70/ano) | Freemium (mensajes limitados) | Freemium barata |

### 10.7 Recomendacion concreta para Recvel

Dado que Recvel es **local-first, sin cuentas, sin premium**, y ya tiene scores de Recovery/Strain/Sleep/Energy mas un Journal (`HabitLog`) para correlaciones:

**Priorizar para v1 (alto valor, bajo costo, coherente con la filosofia del producto):**

1. Timer de ayuno con protocolos estandar (16:8, 18:6, 20:4, OMAD, custom) — nucleo no negociable de la categoria.
2. Visualizacion circular de progreso con fases metabolicas, con **lenguaje matizado por incertidumbre cientifica** (rangos, no horas exactas; nota de "estimacion poblacional, no medicion personal", igual al patron que ya usan los otros scores de Recvel).
3. **Correlacionar con Recovery/Sleep/HRV existente** — este es el diferenciador real frente a Zero/Fastic/BodyFast: ninguna de las apps lideres cruza el ayuno con HRV/recovery de forma tan integrada como podria hacerlo Recvel, que ya tiene esos scores y el patron de correlaciones del Journal. Mostrar como las noches con ayunos mas largos se correlacionan con sueno/HRV del usuario seria un feature genuinamente diferenciado, no una copia de nadie.
4. Historial simple de ayunos (duracion, racha) sin red social ni cuentas.

**Dejar para despues / nice-to-have (son las cosas que estas apps ponen detras de paywall, senal de que no son esenciales para v1):**

- Coach IA conversacional tipo Avo/Fasty — alto costo de desarrollo, bajo ROI sin backend/cuentas, y redundante con el feature de nutricion con IA que Recvel ya esta construyendo.
- Comunidad/social (LIFE Circles, Fasting Buddies) — no encaja con la filosofia local-first sin cuentas de Recvel.
- Recetario y planes de nutricion curados — Recvel ya tiene su propio feature de nutricion con IA, no hace falta duplicar.
- Gamificacion con badges/trofeos — baja prioridad, se puede anadir despues sin gran esfuerzo.
- Tipo de HealthKit dedicado a ayuno — no existe nativo en Apple; no perder tiempo buscandolo. Si vale la pena sincronizar peso/agua si Recvel ya toca esos tipos de HealthKit.

### 10.8 Arquitectura tecnica sugerida (borrador, no implementado todavia)

Consistente con los patrones ya establecidos en el resto de Recvel (`ScoreEngine`, `BaselineEngine`, `HabitLog`/Journal):

```text
FastingSession (SwiftData, nuevo modelo — patron similar a MealLog/HabitLog)
  - startDate, endDate (o endDate nil si esta en curso)
  - protocolo elegido (16:8, 18:6, 20:4, OMAD, custom)
  - duracion objetivo vs duracion real

FastingEngine (nuevo servicio — patron similar a ScoreEngine)
  - calcula fase metabolica actual segun tiempo transcurrido (con rangos, no horas exactas)
  - genera texto matizado por fase, citando incertidumbre cientifica

FastingDetailView / FastingRingComponent (nueva vista — reusa LiquidGlassCard, HeroScoreRing del sistema visual ya existente)
  - anillo circular con fases coloreadas (reusar ArcGauge/HeroScoreRing como base, no crear un sistema nuevo)
  - tarjeta de fase actual con lenguaje matizado

Correlacion con Journal existente
  - agregar "ayuno prolongado (>16h)" como un habito mas dentro del patron de correlacion de HabitLog vs Recovery/HRV que ya existe en JournalView
```

Esto es una **propuesta de diseno para discutir, no una decision cerrada ni codigo implementado** — queda pendiente de aprobacion antes de tocar el proyecto Xcode.

## 11. Estado implementado: Nutricion adaptativa v1 (julio 2026)

La primera experiencia comercial de nutricion ya esta implementada en la app iOS:

- Setup post-onboarding en cuatro pasos con objetivo, datos corporales, actividad, estilo de alimentacion, alergias, alimentos no deseados, comidas por dia y unidades. No se modifico el onboarding principal.
- `NutritionProfile` y `MealLog` persistidos con SwiftData. Cada comida conserva fuente, tipo, confianza, rango kcal, correcciones y macros.
- `NutritionPlanEngine` local y determinista. Calcula un rango inicial con Mifflin-St Jeor, factor de actividad y ajuste moderado por objetivo; distribuye proteina/grasa y usa el resto como carbohidratos. Es una referencia de wellness, no una prescripcion.
- Dashboard con energia y macros contra rango personal, "Siguiente mejor comida", estado de hoy y plan de tres comidas para mañana. Si existen scores locales del dia, sleep/recovery/strain pueden cambiar la razon y la sugerencia.
- Registro por texto, dictado real con Speech, foto local con Vision y codigo desde una imagen. El codigo consulta Open Food Facts y solo envia el numero del producto, no la foto.
- Capa de correccion comun: porcion con slider, aceite, salsa, bebida, postre, doble porcion, quitar item y tipo de comida. Todo resultado se confirma antes de persistirse.
- Timeline con edicion, borrado y "Usar de nuevo".
- Gemini queda detras de `nutritionExperimentalFreeAPIEnabled`, apagado por defecto. La API key se guarda en Keychain, cada envio muestra consentimiento y texto/foto solo salen del dispositivo despues de confirmar.

### Limites que siguen vigentes

- Vision usa clasificacion general del sistema; no segmenta platos ni estima volumen. Su confianza se fuerza a baja y pide descripcion/correccion.
- Open Food Facts puede devolver datos por porcion o por 100 g; cuando no hay porcion, la UI lo marca explicitamente.
- No hay fine-tuning, modelo propietario ni dependencia de SDK pagado.
- La camara de barcode en vivo requiere una fase posterior y validacion fisica. En simulador se selecciona una foto con codigo.
- La exactitud nutricional no se valida todavia contra pesaje o calorimetria; los rangos no deben convertirse en cifras exactas ni claims medicos.

---

## 12. Evidencia clinica real (julio 2026) para ayuno intermitente y nutricion con IA — reglas de producto derivadas

> Investigacion dirigida especificamente a literatura medica/cientifica seria (PubMed/PMC, revisiones sistematicas, guias de sociedades medicas y de la FDA) para fundamentar decisiones de producto en los dos features de este documento (nutricion con IA y la propuesta de ayuno intermitente de la seccion 10). Se excluyeron explicitamente sitios que se hacen pasar por journals o "clinical reports" (ej. dominios tipo "nutrition-research-journal.com", "clinicalnutritionreport.com") por ser granjas de contenido SEO, no publicaciones reales.

### 12.1 Ayuno intermitente — eficacia real vs. restriccion calorica continua

- **Alfahl S., *Journal of Taibah University Medical Sciences*, 2025** — meta-analisis de 16 RCTs/1,258 participantes: peso ligeramente mejor con ayuno intermitente (IF) pero **no significativo**; IMC con diferencia significativa a favor de IF; HbA1c y lipidos **sin diferencia** entre grupos. Nivel: meta-analisis de RCTs. [PMC11930668](https://pmc.ncbi.nlm.nih.gov/articles/PMC11930668/)
- **Ezzati A, Rosenkranz SK, Phelan J, Logan C., *Journal of the Academy of Nutrition and Dietetics*, 2023** — revision sistematica con energia equiparada: efectos de IF "comparables" a restriccion calorica diaria, sin superioridad clara. Nivel: revision sistematica, sociedad medica. [jandonline.org](https://www.jandonline.org/article/S2212-2672(22)00992-3/abstract)
- **Liu H et al., *Journal of Health, Population, and Nutrition*, 2026** — sintesis de 25 fuentes (5 guias, 3 consensos de expertos, 8 revisiones sistematicas, 9 RCTs): ventana optima de alimentacion ~8h (recomendacion fuerte); <6h aumenta eventos adversos; >10h reduce eficacia; perdida de peso "clinicamente significativa" del 3-5%. **Contraindicado explicitamente: embarazo, lactancia, trastornos alimentarios, enfermedad metabolica severa/no controlada.** Sin datos RCT mas alla de 12 meses. Nivel: sintesis de guias + consensos + RCTs — la fuente unica de mayor peso metodologico encontrada. [PMC12888743](https://pmc.ncbi.nlm.nih.gov/articles/PMC12888743/)

**Regla de copy obligatoria:** nunca afirmar que el ayuno "adelgaza mas" o es superior a comer con deficit continuo. Frase permitida: *"un metodo alternativo, no necesariamente mas efectivo que otras formas de manejar tu alimentacion."*

### 12.2 Contraindicaciones medicas — quien no deberia ayunar sin supervision

- **Menores de 18 anos**: estudio en *JAMA Pediatrics* (via STAT News, 2024) sobre ayuno supervisado en adolescentes con obesidad — explicitamente "no pensado para uso generalizado sin supervision"; huesos de crecimiento abiertos en ~95% de adolescentes <17 anos, riesgo de afectar crecimiento lineal. [statnews.com](https://www.statnews.com/2024/09/20/intermittent-fasting-obesity-teens-supervision/)
- **Embarazo y lactancia**: contraindicado (Liu et al. 2026, consenso Mayo Clinic citado en multiples fuentes secundarias).
- **Diabetes tipo 1 o uso de insulina/sulfonilureas**: no recomendado sin supervision medica estrecha por riesgo de hipoglucemia severa y cetoacidosis. [PMC6906269](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6906269/)
- **Adultos mayores/fragiles**: **Harvard Health** (Harvard Medical School) — evidencia humana "carece de solidez" (grupos pequenos, jovenes/mediana edad, periodos cortos); riesgo de perdida de peso excesiva en quienes ya estan en margen bajo, y de desequilibrios de potasio/sodio en quienes toman antihipertensivos. Recomienda explicitamente hablar con el medico antes de empezar. [health.harvard.edu](https://www.health.harvard.edu/healthy-aging-and-longevity/is-intermittent-fasting-safe-for-older-adults)
- **Historial de trastornos alimentarios**: ver 12.3, contraindicacion directa.

**Regla de producto obligatoria:** el feature de ayuno de la seccion 10 debe incluir un **screening previo a activarse** que excluya/advierta explicitamente: menores de 18, embarazo/lactancia, historial de TCA, diabetes tipo 1 o insulina/sulfonilureas, y bajo peso; y muestre aviso de "consulta a tu medico" para adultos mayores o personas con enfermedad cardiaca/antihipertensivos.

### 12.3 Riesgo de trastornos alimentarios (TCA) por apps de ayuno/conteo de calorias — el hallazgo mas critico

- **Levinson CA, Fewell L, Brosof LC., *Eating Behaviors*, 2017** — n=105 pacientes con diagnostico de TCA: 74.3% usaba MyFitnessPal; de esos, **73.1% reporto que la app "al menos algo" contribuyo a su TCA**, 30.3% dijo "mucho". Correlacion entre percepcion de dano y severidad de sintomas (EDE-Q) r=.25-.36. Nivel: estudio observacional en poblacion clinica. [PMC5700836](https://pmc.ncbi.nlm.nih.gov/articles/PMC5700836/)
- **Eikey EV., *BJPsych Open*, 2021** — estudio cualitativo, 24 mujeres universitarias: las apps generan fijacion numerica, dieta rigida, dependencia con ansiedad al dejar de trackear, y las alertas/notificaciones **refuerzan paradojicamente la restriccion**. De 19 con datos de cuestionario, 17 mostraron sintomas de TCA y 15 superaron el corte del EAT-26. [PMC8485346](https://pmc.ncbi.nlm.nih.gov/articles/PMC8485346/)
- **Domaszewski P, Rogowska AM, Zylak K., *Nutrients*, dic. 2024** — n=214: quienes ayunan puntuan significativamente mas alto en ortorexia (ABOST) y sintomas de TCA (EAT-26) que quienes no ayunan (p<0.01). Hallazgo clave: **la ortorexia media completamente la relacion entre ayuno y TCA** — el efecto directo del ayuno desaparece al meter ortorexia en el modelo (explica 44% de la varianza). [PMC11676192](https://pmc.ncbi.nlm.nih.gov/articles/PMC11676192/)

**Reglas de producto obligatorias, derivadas directamente de esta evidencia:**
- Screening corto tipo SCOFF/EAT-26 antes de habilitar ayuno estricto o conteo calorico intensivo.
- **Prohibido en UI**: streaks punitivos, colores rojo/verde de "exito/fracaso" en deficit calorico, notificaciones de "alerta" que refuercen restriccion (patron que Eikey 2021 mostro que empeora el comportamiento).
- Incluir limite/pausa sugerida de uso continuo del feature de conteo/ayuno.

### 12.4 Autofagia en humanos — evidencia mas reciente (complementa la seccion 10.3)

- **Bensalem et al., *Journal of Physiology*, 2025** — "Intermittent time-restricted eating may increase autophagic flux in humans: an exploratory analysis": aumento de flujo autofagico en celulas mononucleares de sangre periferica tras 6 meses de TRE vs cuidado estandar. Nivel: **RCT exploratorio, n pequeno**. [PubMed 40345145](https://pubmed.ncbi.nlm.nih.gov/40345145/)
- Estudios piloto adicionales (GeroScience 2025, Clinical Nutrition ESPEN 2025) muestran cambios en marcadores/expresion genica de autofagia (LAMP2, LC3B, ATG5) con ayuno, pero todos descritos como exploratorios/piloto, biomarcadores indirectos, sin medicion directa de autofagia tisular.
- **Consenso de la literatura: la evidencia sugiere que el ayuno puede inducir autofagia en humanos, pero no es definitiva.** No existe consenso clinico de sociedad medica sobre beneficios de longevidad confirmados en humanos.

**Regla de copy:** reforzando lo ya dicho en la seccion 10.3 — prohibido decir "activa la autofagia" o "beneficios de longevidad" como hecho. Maximo permitido: *"estudios preliminares en humanos sugieren posibles cambios en marcadores de autofagia; la evidencia aun no es concluyente."*

### 12.5 Ayuno y ciclo menstrual/salud hormonal (relevante porque Recvel ya trackea ciclo)

**Cienfuegos et al., *Nutrients*, junio 2022** — revision de ensayos en humanos: en mujeres premenopausicas con obesidad, el ayuno intermitente reduce testosterona total e indice de androgeno libre, aumenta SHBG (mas pronunciado si toda la comida es antes de las 4pm); **sin cambios significativos en LH, FSH, estrogeno o prolactina**. En hombres, la alimentacion con restriccion horaria reduce testosterona libre/total 1-27% sin afectar masa/fuerza muscular. **Limitacion explicita de los autores: muy pocos estudios, ninguno en mujeres posmenopausicas.** [PMC9182756](https://pmc.ncbi.nlm.nih.gov/articles/PMC9182756/)

**Regla de producto:** mensaje contextual no alarmista aprovechando que Recvel ya trackea ciclo — *"hay evidencia preliminar de que el ayuno prolongado puede alterar hormonas reproductivas en mujeres; si notas cambios en tu ciclo, consulta a tu medico"* — sin prometer beneficio ni certeza de dano.

### 12.6 Ayuno e interaccion con medicamentos

Guias de manejo de diabetes durante Ramadan (**American Diabetes Association / International Diabetes Federation, consenso ADA/EASD, actualizacion 2020**): metformina sola generalmente segura para ayunar (bajo riesgo de hipoglucemia) pero requiere ajuste de horario; insulina y sulfonilureas requieren estratificacion de riesgo y supervision medica antes de ayunar. [PMC7223028](https://pmc.ncbi.nlm.nih.gov/articles/PMC7223028/)

**Regla de producto:** aviso generico ("consulta a tu medico o farmaceutico el horario de tus medicamentos antes de ayunar") **sin dar instrucciones especificas de ajuste de dosis/horario** — cruzar esa linea convierte a Recvel en soporte de decision clinica, fuera del alcance de "general wellness product" (ver 12.9).

### 12.7 Nutricion con IA — eficacia real y adherencia

- Meta-analisis 2025 (apps moviles en manejo de obesidad, PubMed 40327853): efecto modesto pero significativo en perdida de peso/IMC a 4-6 meses en personas con sobrepeso/obesidad; usuarios de trackers pierden en promedio ~2.87 kg mas que no-usuarios. Nivel: meta-analisis de RCTs.
- **Adherencia documentada**: auto-monitoreo cae de 5.4 a 1.4 dias/semana entre la semana 4 y 12 (MyFitnessPal); Lose It! cae a 4 dias/semana a las 12 semanas. La frecuencia de auto-monitoreo es "el predictor individual mas fuerte" del resultado de perdida de peso; combinar app + feedback humano da 62% mas perdida de peso que la app sola.

**Regla de producto:** fijar expectativas realistas — comunicar que el conteo funciona mientras se use consistentemente y que el abandono a las 4-12 semanas es la norma documentada, en vez de prometer transformacion sostenida solo con logging pasivo.

### 12.8 Seguridad del "escaneo de comida con IA" — el hallazgo mas critico para el feature de nutricion

**Li et al., *Nutrients*, agosto 2024** — evaluacion de 18 apps de food logging (16 manuales + 7 con reconocimiento de imagen IA) contra datos de referencia Foodworks: apps IA con 87-97% de precision en *identificacion* de componentes pero estimacion energetica "no confiable" — en platos mixtos, desviaciones de -55% a -76%. **Hallazgo de seguridad critico explicito de los autores:** para pacientes diabeticos que cuentan carbohidratos, la sobreestimacion de hasta 20% en carbohidratos plantea "riesgos considerables (mal control glucemico, episodios de hipoglucemia)"; una app reporto sodio 34 veces mas alto que el valor real. [PMC11314244](https://pmc.ncbi.nlm.nih.gov/articles/PMC11314244/)

**Regla de producto obligatoria:** disclaimer explicito de que la estimacion nutricional por IA es aproximada y **no debe usarse para decisiones clinicas** (conteo de carbohidratos en diabetes, sodio en hipertension) — directamente respaldado por esta fuente.

**Contexto util para no sobre-exigir precision a la IA:** el recordatorio de 24h hecho por humanos (el estandar real en la practica clinica de dietistas) subestima 20-25% en energia incluso contra el gold standard de agua doblemente marcada ([PMC9523208](https://pmc.ncbi.nlm.nih.gov/articles/PMC9523208/)); el logging manual estructurado tipo MyFitnessPal ronda 1-10% de error segun el nutriente ([PMC6543803](https://pmc.ncbi.nlm.nih.gov/articles/PMC6543803/)). Mensaje honesto para Recvel: *"tan preciso como un diario de alimentos bien llevado, no un reemplazo de evaluacion por un dietista"* — nunca "mas preciso que un nutriologo".

### 12.9 Marco de diseno responsable (aplica a ambos features)

- **FDA — "General Wellness: Policy for Low Risk Devices"** (guia revisada enero 2026): un producto califica como "general wellness product" (no dispositivo medico regulado) si su uso previsto es mantener/fomentar un estilo de vida saludable, **sin** relacionarse con diagnostico, cura, mitigacion, prevencion o tratamiento de una enfermedad especifica. Se permite alentar a consultar profesionales y dar rangos/benchmarks generales; **no** se permite dar alertas diagnosticas ni recomendar tratamiento. [fda.gov](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/general-wellness-policy-low-risk-devices)
  - **Regla:** evitar lenguaje de "diagnostico"/"tratamiento" (nunca "detecta tu deficit calorico para tratar tu obesidad"; si "te ayuda a llevar un registro para tus metas de bienestar"); no dar "alertas" que parezcan clinicas; mantener todo enmarcado como bienestar general, no gestion de enfermedad especifica.
- **American Psychiatric Association — App Evaluation Model** (marco jerarquico de 5 niveles: acceso, privacidad/seguridad de datos, fundamento clinico/evidencia, facilidad de uso, integracion hacia metas terapeuticas — se descarta la app si falla un nivel antes de evaluar el siguiente). [psychiatryonline.org](https://psychiatryonline.org/doi/10.1176/appi.ps.202000663)
  - **Uso recomendado:** adoptarlo como checklist interno antes de cada lanzamiento de feature, priorizando nivel 3 (evidencia clinica de cada claim) y nivel 2 (privacidad de datos sensibles combinados: ciclo menstrual + patrones alimentarios son datos de alto riesgo de re-identificacion si se cruzan).
- **ORCHA** (evaluacion de apps de salud fundada por clinicos NHS, +270 criterios en privacidad/seguridad, aseguramiento clinico, usabilidad) — util como checklist de referencia, no autoridad regulatoria. [orchahealth.com](https://www.orchahealth.com/resources/assessment-frameworks)

### 12.10 Lista priorizada de reglas de producto (resumen accionable)

1. Screening obligatorio antes de activar ayuno: excluir/advertir menores de 18, embarazo/lactancia, historial de TCA, diabetes tipo 1/insulina/sulfonilureas, bajo peso; aviso de "consulta a tu medico" para adultos mayores/enfermedad cardiaca.
2. Nunca afirmar que el ayuno es superior a la restriccion calorica continua.
3. Prohibir claims de autofagia/longevidad como hechos establecidos; usar siempre lenguaje de evidencia preliminar.
4. Screening de riesgo de TCA (SCOFF/EAT-26 corto) antes de conteo calorico intensivo o ayuno estricto; prohibir streaks punitivos, colores exito/fracaso, notificaciones de alerta que refuercen restriccion.
5. Disclaimer explicito: la estimacion nutricional por IA no debe usarse para decisiones clinicas (carbohidratos en diabetes, sodio en hipertension).
6. Contextualizar el error de la IA (20-30%) frente al estandar humano real (recordatorio 24h subestima 20-25% contra gold standard) — mensaje honesto, ni sobre-vender ni sub-vender la precision.
7. Aviso generico sobre medicamentos y ayuno, sin instrucciones especificas de dosis/horario.
8. Mensaje contextual no alarmista sobre ayuno prolongado y ciclo menstrual.
9. Enmarcar todo el producto como "general wellness" segun guia FDA: nunca lenguaje de diagnostico/tratamiento de enfermedad especifica.
10. Adoptar el APA App Evaluation Model como checklist interno antes de cada lanzamiento de feature.
11. Fijar expectativas realistas de adherencia (el abandono a 4-12 semanas es la norma documentada), priorizando feedback/soporte sobre logging pasivo.

Estas reglas complementan, sin reemplazar, las ya establecidas en las secciones 1-11 de este documento y en AI_CONTEXT.md/README.md sobre lenguaje no clinico y confirmacion humana.
