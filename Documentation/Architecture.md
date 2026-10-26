# Arquitectura y viabilidad de FoldContextKit

Investigación: 2026-10-25. Actualización de etapa 2: 2026-10-26. Los contratos descritos en Contracts.md están implementados; clasificador y adaptadores siguen siendo propuestas, no símbolos de Apple.

## 1. Evidencia verificada y método

Se inspeccionó exclusivamente este proyecto y las instrucciones locales aplicables. No se encontraron archivos AGENTS.md en el proyecto ni en los directorios ascendentes consultados. En la inspección inicial el manifiesto definía AdapteDuoKit y la función `hello()`. La etapa 2 los sustituye por FoldContextKit, con Swift tools 6.4, núcleo sin UI y Swift Testing. No hay dependencias externas. Se retira el ajuste experimental ApproachableConcurrency: el núcleo usa valores Sendable y no necesita aislamiento global ni esa opción.

Entorno leído: Xcode 27.1 (27A9275), Apple Swift 6.4 (swiftlang-6.4.0.34.1), SDK iPhoneOS27.1.sdk. Esto describe el entorno local, no una prueba de ejecución en iPhone.

DocumentationSearch se consultó con `onHingeChange UIHingeInteraction hinge iPhone Duo`, `onHingeChange` y `UIHingeInteraction`. Devolvió coincidencias ajenas a los símbolos buscados. Se contrastaron después las páginas oficiales y los archivos públicos bajo:

`/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/`

- `UIKit.framework/Headers/UIHingeInteraction.h`
- `UIKit.framework/Headers/UIHinge.h`
- `SwiftUICore.framework/Modules/SwiftUICore.swiftmodule/arm64e-apple-ios.swiftinterface`

La presencia en cabeceras e interfaces verifica declaraciones. No se ejecutó un adaptador ni se comprobó su enlace o comportamiento físico.

### Referencias obligatorias

| Referencia | Resultado y alcance |
| --- | --- |
| [Foro 847775](https://developer.apple.com/forums/thread/847775) | Respuesta de Apple: no hay API de identificación de Duo; los tamaños de apps iPhone pueden variar en otros contextos. No valida una heurística dimensional. |
| [Foro 847644](https://developer.apple.com/forums/thread/847644) | Resumen de Apple que enlaza las APIs de bisagra y las sitúa en iOS 27.1; describe transiciones como cambios de geometría/traits y soporte de varias escenas. No sustituye el contrato de cada símbolo. |
| [Tech Talk 111464](https://developer.apple.com/videos/play/tech-talks/111464/) | Describe onHingeChange y UIHingeInteraction para estado/ángulo en vivo. Recomienda APIs de regiones y arrangement para layout. Su explicación de nil es más simplificada que la cabecera actual de UIKit. |
| [UIHingeInteraction](https://developer.apple.com/documentation/uikit/uihingeinteraction) | Existencia y semántica corroboradas con SDK y versión Markdown oficial. La página HTML exige JavaScript. |
| [Preparación para Duo](https://developer.apple.com/iphone-duo/prepare/) | Confirma el contexto del dispositivo y recomienda medir vista/ventana, no asumir modelo por dimensiones. No establece aquí un perfil dimensional validado para identificación. |
| [onHingeChange](https://developer.apple.com/documentation/swiftui/view/onhingechange(isenabled:_:)) | Declaración corroborada en SwiftUICore y versión Markdown oficial. |

Las versiones Markdown se obtuvieron añadiendo `.md` a las URLs de los símbolos. Se evita depender de que el índice local esté actualizado.

### SwiftUI: firma y disponibilidad

Declaración pública, omitiendo cualificaciones de módulo de la interfaz:

```swift
nonisolated func onHingeChange(
    isEnabled: Bool = true,
    _ action: @escaping (DeviceHingeContext, DeviceHingeContext) -> Void
) -> some View
```

La interfaz identifica los argumentos como contexto anterior y nuevo. `DeviceHingeContext.hinge` es `DeviceHinge?`; `DeviceHinge.angle` es `Angle`, y su `Status` es una estructura con valores estáticos `closed`, `partiallyOpen` y `fullyOpen`, no un enum cerrado que debamos reproducir exhaustivamente.

El SDK declara `@available(anyAppleOS 27.1, *)`. La documentación web enumera iOS, iPadOS, Mac Catalyst, macOS, tvOS, visionOS y watchOS 27.1. Esta disponibilidad no garantiza bisagra en esas plataformas; el alcance inicial propuesto es iOS/iPadOS.

El contrato consultado describe cambios del contexto de la jerarquía. No especifica una garantía temporal de primer callback al arrancar ni un parámetro `initial`. No trasladar automáticamente a SwiftUI las garantías de UIKit. Quedan por comprobar entrega inicial, reactivación, desmontaje y significado completo de ausencia según contexto.

### UIKit: firma y condiciones de entrega

`UIHingeInteraction` es una clase MainActor que conforma a UIInteraction. Su inicializador Swift documentado es `init(updateHandler:)`, con closure `(UIHingeInteraction, UIHingeInteraction.Update) -> Void`; se añade a una UIView mediante `addInteraction(_:)`. Expone `isEnabled: Bool`; la actualización expone `hinge: UIHinge?`.

Cabeceras: iOS, tvOS y visionOS 27.1, no watchOS. La web añade iPadOS y Mac Catalyst 27.1. No se propone soporte UIKit para macOS nativo.

La cabecera documenta entrega del estado inicial y posteriores cambios de bisagra o de jerarquía. No fija el instante respecto al lanzamiento ni exige una maniobra física. Si la interacción sale de una jerarquía que entrega datos, `hinge` pasa a nil. Deshabilitada no entrega ni encola actualizaciones; al reactivarse entrega el estado actual si está disponible. El handler escapa y exige evitar ciclos de retención.

`UIHinge.angle` es `CGFloat` en radianes. `UIHinge.Status` incluye `unknown`, `closed`, `partiallyOpen`, `fullyOpen`. Fully open significa apertura máxima permitida por el dispositivo, no un ángulo universal. Frecuencia y granularidad dependen del sistema; no fijar precisión ni frecuencia prometidas.

La explicación de nil del vídeo no basta para concluir ausencia física: la cabecera y la página específica describen otra causa. La biblioteca representará indisponibilidad de datos y conservará el origen del evento, sin inventar su causa cuando no pueda observarse.

## 2. Conclusión de viabilidad

**Verificado:** hay APIs públicas para observar bisagra y contexto de presentación; las declaraciones de bisagra están en el SDK instalado.

**Hipótesis:** dimensiones de pantalla compatibles más bisagra observada podrían sostener una inferencia de Duo. Una transición compatible en la misma escena podría contextualizarla. No prueba exclusividad ni aporta una segunda evidencia independiente de tamaño.

**Verificación dimensional posterior:** Apple publica 1398 × 2034 píxeles para la pantalla exterior y 1878 × 2670 para la interior ([especificaciones](https://www.apple.com/iphone-duo/specs/)). Ninguna coincide, intercambiando ejes, con las resoluciones de los iPhone compatibles con iOS 26 comparados en la investigación. Son rasgos candidatos, no perfiles de producción. **Pendiente:** lecturas reales de nativeBounds en Duo, invariantes frente a modos de presentación, atribución bajo Mirroring/pantalla externa y tasas de error.

**Decisión propuesta:** avanzar con observación y clasificación explicable, dejando la inferencia de modelo desactivada por defecto. Sin perfil validado no emitir candidato dimensional ni Duo inferido. No hay base para prometer identificación fiable del modelo; incluso un futuro perfil será una heurística revisable. Esto conserva explícitamente ambos objetivos y sus diferentes límites.

## 3. Separación de responsabilidades

1. **Observación:** adaptadores MainActor ligados a la vista, ventana y escena del consumidor. Capturan eventos públicos, disponibilidad, geometría y ciclo de vida; no clasifican modelos.
2. **Evidencias:** valores inmutables Sendable con origen, unidad, ámbito, secuencia temporal local y vigencia. Diferencian no recibido, API no disponible, observación suspendida y dato recibido sin bisagra.
3. **Clasificación:** función pura de evidencias y política explícita; devuelve capacidades, inferencia, motivos y limitaciones. No consulta UIKit, reloj, estado global ni servicios.
4. **Integración:** SwiftUI entrega contexto por instancia de vista raíz/ventana; UIKit vincula un observador a una vista de la ventana concreta. Ambas rutas alimentan el mismo núcleo. La app decide layout y navegación.

Cada ventana tiene su propio observador y snapshot, incluso si comparte escena con otra ventana. La identidad de escena y ventana será local y efímera, sin identificadores de hardware o persistencia personal. No usar singleton, UIScreen.main, UserDefaults ni AppStorage para el tamaño compartido. Reasociar al cambiar de jerarquía; limpiar observaciones al desmontar; marcar como históricas las muestras anteriores. Nunca mezclar una bisagra antigua de un contexto con dimensiones nuevas de otro.

Se propone un snapshot actual y un historial acotado por sesión para transiciones. No persistir ni enviar datos. La continuidad de escena no demuestra continuidad de pantalla: una transición conservará ambas procedencias, sin asumir que cada resize es plegado.

### Magnitudes y procedencia

| Dato conceptual | Unidad y ámbito | Uso permitido |
| --- | --- | --- |
| Tamaño de vista raíz | Puntos del espacio local de esa vista | Contexto de presentación, no tamaño de pantalla |
| Tamaño de ventana | Puntos de la ventana identificada | Resize/multitarea; nunca identidad de modelo |
| Métrica de pantalla | Puntos o píxeles, campos distintos y API exacta registrada | Solo comparación con perfil de igual procedencia y unidad |
| Escala | Factor de escala del contexto | No convertir pulgadas ni asumir densidad física |
| Tamaño físico comercial | Pulgadas u otra longitud | Fuera de las reglas iniciales |
| Ángulo | Radianes en el núcleo; conversión explícita desde Angle | Capacidad observada, no tamaño de layout |

Para geometría se propone seguir las fuentes de vista/ventana de la guía de preparación. Si se necesitan métricas de pantalla, resolver la pantalla desde la ventana/escena actual, sin almacenarla globalmente. Antes de implementar cualquier perfil se verificará el contrato preciso de bounds, nativeBounds, escala y orientación elegido. Datos de view/GeometryProxy no se etiquetarán como window sin garantizar que miden esa ventana.

## 4. Estructura propuesta del paquete

```text
Package.swift                         # Futuro producto FoldContextKit
Sources/FoldContextKit/
    Evidence/                         # Valores y procedencia
    Classification/                   # Reglas puras y motivos
    Observation/                      # Ciclo de vida por ventana
    SwiftUI/                          # Adaptador, condicionado por plataforma
    UIKit/                            # Adaptador, condicionado por plataforma
Tests/FoldContextKitTests/             # Swift Testing, entradas controladas
Examples/FoldContextExample/           # App Xcode posterior, fuera del producto
Documentation/
    Architecture.md
    Checklist.md
README.md
```

Un producto y un target público mantienen pequeña la integración; carpetas separan responsabilidades. Alternativa: targets Core/SwiftUI/UIKit si la compilación o portabilidad lo exige, a costa de más módulos. Decisión de etapa 2: Swift tools 6.4, iOS/iPadOS 26 como mínimo y APIs de bisagra protegidas por iOS 27.1. macOS 26 permite ejecutar el núcleo y sus tests localmente; no promete un adaptador de bisagra para Mac. Ver [contratos y validación](Contracts.md).

## 5. API pública conceptual

Nombres y formas sujetos a revisión; esta tabla no es código compilable ni promesa de API estable.

| Elemento propuesto | Contrato |
| --- | --- |
| `FoldEvidence` | Snapshot con PresentationContext, observación de bisagra, procedencia y transición opcional |
| `HingeObservation` | API no disponible / esperando datos / suspendida / dato no disponible / muestra observada; nunca bool implícito de hardware |
| `FoldAssessment` | Capacidad actual, evidencia histórica separada, inferencia de modelo, motivos y limitaciones |
| `FoldClassifier.evaluate(evidence:policy:)` | Evaluación pura y determinista; sin perfiles de producción por defecto |
| `FoldContextObserver` | Propietario MainActor por ventana: snapshot, inicio/parada ligados a jerarquía y cancelación |
| `onFoldContextChange` | Adaptador SwiftUI propuesto, comunica snapshots al consumidor sin sustituir vistas |

La capacidad podrá ser desconocida u observada; la inferencia podrá ser insuficiente, candidata por dimensiones o Duo inferido. «Bisagra observada» es una capacidad independiente: puede coexistir con modelo desconocido. No condensar los tres ejes (capacidad/modelo/presentación) en un único enum ordinal de confianza.

El núcleo normalizará estados de bisagra desconocidos/futuros sin inventar ángulos. La política experimental de perfiles tendrá procedencia/versionado y exigirá compatibilidad de unidad, ámbito y contexto; su diseño final queda bloqueado por falta de perfiles validados. No exponer un `isDuo` que esconda incertidumbre.

Para eventos se propone AsyncSequence con cancelación y buffering acotado; hay que decidir cómo preservar cambios discretos frente a ángulos frecuentes. Una callback MainActor es alternativa más pequeña. SwiftUI podría usar Observation para el snapshot; no se requiere Combine. No crear un stream nuevo con efectos laterales en cada lectura del body.

### Reglas iniciales propuestas

| Entradas | Resultado permitido |
| --- | --- |
| Solo disponibilidad de API | Capacidad y modelo desconocidos |
| Sin callback, nil, deshabilitado o API no disponible | Motivo específico; no concluir ausencia física |
| Bisagra recibida en contexto vigente, sin perfil | Capacidad observada; modelo insuficiente |
| Perfil validado compatible, sin bisagra | Candidato dimensional; no Duo inferido |
| Perfil validado + bisagra vigente + contexto atribuible y compatible | Inferencia experimental explicada; nunca identificación oficial |
| Transición compatible, sin bisagra | Contexto complementario; no promoción automática |
| Fuentes incompatibles, contexto externo/reflectado o atribución desconocida | No inferir modelo; explicar limitación |

No comparar con perfiles de prueba como si fueran perfiles reales. Las reglas dimensionales permanecen inactivas en producción hasta validar perfiles. Una app debe funcionar desde arranque abierto o cerrado sin esperar transición.

## 6. Alternativas y cuestiones pendientes

- Observación de capacidades sin inferencia de modelo: útil y viable, pero no resuelve la identificación solicitada.
- Heurística dimensional: investigable, susceptible a falsos positivos y negativos; sin garantía futura.
- Adaptación directa mediante geometría, regiones reservadas y contenedores de Apple: opción del consumidor; fuera del motor de layouts de esta biblioteca.
- No usar tablas de hardware, APIs privadas ni inspección de identificadores como sustituto de la hipótesis.
- Verificar comportamiento inicial SwiftUI, reactivación UIKit, suspensión, escenas desconectadas, varias ventanas y cambio de pantalla.
- Definir cuándo vence una muestra sin usar un timeout arbitrario como prueba de ausencia; pasar tiempo/vigencia explícitos a la lógica pura si fueran necesarios.
- Investigar cómo representar Mirroring/pantalla externa cuando no existe evidencia pública suficiente para atribuir el dispositivo. Desconocido es un resultado válido.
- Las firmas mínimas ya compilan con BuildProject para iOS Simulator, SDK 27.1 y deployment target 26.0. Sigue pendiente observar las entregas en simulador y hardware por separado.
