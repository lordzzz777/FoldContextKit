# Reglas puras — etapa 3

Implementadas el 2026-10-26. No constituyen validación de hardware.

## API

`FoldClassifier.evaluate(evidence:policy:previousScreen:)` devuelve un `FoldAssessment` con contexto de presentación, capacidad, inferencia y motivos tipados en orden determinista. No lee reloj, UI, almacenamiento ni estado global. No modifica evidencias ni navegación.

La política es obligatoria:

- `observationOnly`: informa de bisagra observada y conserva su origen; no infiere modelo.
- `synthetic(profile)`: evalúa un `SyntheticDimensionProfile` explícito con dos tamaños distintos en píxeles. Solo acepta origen synthetic para la inferencia. No incluye resoluciones de Duo ni permite promover muestras system/simulator a una inferencia sintética.

Resultados de modelo: `insufficientInformation`, `syntheticDimensionCandidate`, `syntheticDuoInference`. Los dos últimos son resultados de ensayo, no identificación de un dispositivo real. Los metadatos son entradas declaradas por el consumidor, no una autenticación del origen.

## Reglas

| Evidencia | Resultado |
| --- | --- |
| Sin datos de bisagra | Capacidad desconocida, motivo específico de ausencia |
| Bisagra vigente, mismo contexto y origen conocido | Capacidad observada, conservando origen |
| Estado de bisagra unknown con muestra presente | Capacidad observada; estado desconocido explicado |
| Política de observación | Modelo insuficiente siempre |
| Dimensión sintética compatible, sin bisagra válida | Candidato dimensional sintético |
| Dimensión y bisagra sintéticas vigentes en el mismo contexto | Inferencia Duo sintética |
| Dimensiones no coincidentes o pantalla externa/reflectada/desconocida | Sin inferencia de modelo |
| Bisagra histórica o de otra ventana/escena/generación | No participa como capacidad actual ni promueve el modelo |

Una muestra de bisagra con estado unknown o sin ángulo sigue siendo una muestra positiva de bisagra. No se infiere postura, ni se supone que fullyOpen deba coincidir con una pantalla concreta: esa relación no está verificada. Una contradicción dimensional bloquea la inferencia, pero no borra una capacidad observada válida.

## Unidades, fuentes y vigencia

Solo `NativeScreenSize` participa en la comparación. `PresentationSize` está tipado en puntos y no se convierte ni se usa como resolución. La equivalencia dimensional permite intercambiar ancho/alto: girar una misma resolución no crea una transición entre pantallas. No hay tolerancias implícitas.

Para una muestra actual, escena, ventana y generación deben coincidir exactamente con el snapshot; validity debe ser current y origin conocido. Historical se interpreta como no vigente para la evaluación actual. No hay caducidad temporal automática: corresponde al observador marcar la vigencia. Las pruebas de caducidad cubren esta invalidación explícita, no tiempos de entrega reales.

Las identidades locales deben renovarse entre sesiones; la secuencia debe aumentar durante toda la sesión, incluso al cambiar de generación. Estas obligaciones pertenecen al contrato del productor.

UIKit y SwiftUI son fuentes de bisagra válidas; su diferencia por sí sola no implica incompatibilidad. Los orígenes system/simulator/synthetic mezclados no sirven para inferir en la política sintética. Un origen unknown se rechaza con motivo explícito.

## Transición complementaria

`previousScreen` es opcional. Para anotar `compatibleDimensionTransition` debe pertenecer a la misma escena y ventana, tener generación no posterior y secuencia estrictamente anterior, origen synthetic, atribución deviceDisplay y coincidir con el otro tamaño del perfil. La muestra anterior puede ser historical porque se utiliza como historia, nunca como estado actual.

La transición no cambia el resultado de modelo. Si la historia es incompatible, se explica y se ignora; una combinación actual válida sigue siendo válida. Sin dimensión actual válida, la historia tampoco permite inferir. No se exige plegar el dispositivo ni se interpreta la rapidez del resize como causa física.

## Validación

RunAllTests de Xcode: 29 casos superados, 0 fallos, 0 omitidos (26 de clasificación y 3 de contratos). Se comprobó la inclusión de los archivos nuevos tras refrescar el manifiesto SwiftPM.

Cobertura: datos ausentes (API no disponible, espera, nil y suspensión), cuatro estados de bisagra, dos fuentes de bisagra, ambas dimensiones iniciales, política de observación, contradicciones, rotación, tres fuentes de geometría en puntos, historia opcional, secuencias fuera de orden, contexto y generación, datos históricos, origen desconocido/mezclado y atribuciones externas/reflectadas/desconocidas. Las medidas 100 × 200 y 300 × 400 son artificiales.

No se han observado callbacks en simulador ni en dispositivo físico. No se han medido tasas de falsos positivos/negativos: los tests comprueban resultados esperados con entradas controladas.
