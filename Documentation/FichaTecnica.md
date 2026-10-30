# Ficha técnica de FoldContextKit

Documentación consolidada el 29 de octubre de 2026. Reúne los contratos, decisiones, fuentes y registros narrativos del proyecto. Los resultados conservan su fecha y alcance; las propuestas iniciales no sustituyen la API implementada descrita después.

## Estado vigente

<a id="validacion-30-octubre"></a>

### Validación autorizada el 30 de octubre

El usuario autorizó ahora ejecutar pruebas antes de preparar la distribución. Esta sección sustituye el estado anterior «sin tests ni compilaciones»; las notas inferiores conservan la historia de implementación.

| Comprobación | Resultado actual |
| --- | --- |
| Paquete y targets de pruebas, BuildProject, SDK iOS Simulator 27.1 | Compilación correcta |
| RuntimeProbe, xcodebuild para simulador | Compilación correcta; aviso de metadatos AppIntents omitidos sin dependencia |
| Reglas puras, contratos y buffering independiente de UIKit | 25 tests Swift Testing superados en Mac, sin fallos |
| Consumidor SwiftPM independiente | Compila y ejecuta: local import OK, entrada sintética |
| RunAllTests en destino iOS | Bloqueado; cancelado por el asistente sin resultados completos |
| App en Duo Simulator | No se pudo instalar/abrir; captura del logo Apple, conexión rechazada y timeout |
| Control iPhone 17 y recuperación del Duo sin borrar datos | Acceso bloqueado; no observación runtime nueva |
| Dispositivo físico | No disponible; no observado |

Se añadieron siete funciones de test en PresentationTests.swift: inferencia y panel con rotación; captura/externas; elección de layout independiente de ángulo; división medida; resta de oclusiones; geometría histórica/ajena y archivo; fragmentación acotada. Los orígenes simulator declarados por estos fixtures son entradas controladas para las reglas, no lecturas reales. Los casos UIKit bajo os(iOS) no se ejecutaron en Mac.

El motor predeterminado de SwiftPM quedó bloqueado. El motor alternativo `--build-system native`, con cachés en /tmp, completó los tests y la importación local. Esa opción emite un aviso de obsolescencia; se conserva como solución local de validación, no se exige al consumidor ni se modifica el manifiesto.

La validación en simulador requerida aún no está cerrada. CoreSimulator rechazó la conexión y el intento dirigido de shutdown; no se borraron dispositivos ni se reiniciaron servicios globales. Será necesario recuperar el servicio de simulación (reiniciar Xcode/Simulator o el Mac si persiste) antes de repetir los tests iOS y el ciclo de vida real. No se presentan los 38 casos históricos como resultado de esta revisión.

Evidencias: [registro de intentos y resultados](../Validation/RuntimeProbe/Results/2026-10-30-runtime-attempt.txt), [build de app](../Validation/RuntimeProbe/Results/2026-10-30-app-build.log), [captura de arranque](../Validation/RuntimeProbe/Results/2026-10-30-duo-boot.png). No se ha publicado nada en GitHub.


### Contextos ambiguos — resolución de tratamiento

Se incorpora `FoldDisplayContext` en evidencia y evaluación, con procedencia y vigencia: pantalla externa, receptor de reflejo, grabación/reflejo no distinguible, escena de aplicación sin atribución física, integrada declarada y desconocida. Captura desconocida pasa a bloquear la inferencia, igual que captura activa. La heurística Duo para applicationDisplay con captura inactiva permanece disponible y conserva su limitación explícita; no se afirma haber identificado un panel local frente a una pantalla externa interactiva.

La [documentación de captura de Apple](https://developer.apple.com/documentation/swiftui/protecting-sensitive-content-when-screen-sharing) dice expresamente que la señal no distingue tipos de captura. [TN3210](https://developer.apple.com/documentation/technotes/tn3210-optimizing-your-app-for-iphone-mirroring) describe integración con Mirroring, pero no aporta en el contenido consultado una señal específica de identificación. El SDK local define UISceneCaptureState inactive/active/unspecified; se conserva esa correspondencia. No se interpreta una búsqueda negativa como prueba de inexistencia universal de API.

El tratamiento determinista queda implementado; la identificación universal específica sigue sin resolverse. No hay nuevos tests ni compilaciones.


### Regiones del sistema, captura y licencia — 30 de octubre

Esta ampliación sustituye las limitaciones de cálculo exclusivamente en mitades de las revisiones inferiores. UIKit consulta `reservedRegions(kind: .division)` y `.occlusion` desde iOS 27.1, filtra regiones activas y convierte sus frames desde la raíz a la ventana; frame ya incluye margins. Se conserva safeAreaLayoutGuide en el mismo espacio, metadatos, disponibilidad, divisiones y oclusiones. `regionSource` diferencia la división real proporcionada por UIKit del fallback lógico `appEqualSplit`. El sistema no garantiza que cada región corresponda a una bisagra: se conserva la semántica division/occlusion.

El núcleo prioriza una división única que atraviese el área segura en el eje solicitado. `unobscuredRegions` resta oclusiones observadas sin crear vistas; hasta 32 rectángulos con truncamiento explícito y conservador. Sin API de regiones disponible, no se declara un conjunto libre de oclusiones. Las lecturas se renuevan en layout, safeAreaInsetsDidChange, muestras de bisagra y refresh; si el host cambia presentación sin un layout debe llamar refresh. Se invalidan y archivan junto al resto del snapshot por ventana.

Se observa `UITraitSceneCaptureState` por vista. Captura activa invalida la evidencia de contexto anterior y bloquea inferencia. No se confunde captura/grabación/reflejo con iPhone Mirroring específico. UIScreen.mirrored indica el receptor de reflejo, no todos los emisores. Los roles externos se excluyen; windowApplication no certifica pantalla integrada porque también admite presentación externa interactiva. Se mantiene el motivo displayIdentityUnverified. El contrato público consultado no proporciona aquí una distinción universal de iPhone Mirroring y pantalla integrada; esa parte no se declara resuelta.

Firmas y disponibilidad leídas en UIViewReservedRegion.h, UIView.h y la interfaz Swift de UIKit del SDK 27.1. DocumentationSearch devuelve referencias de safe area y captura, con cobertura limitada de reservedRegions. Fuentes: [regiones reservadas](https://developer.apple.com/documentation/uikit/uiview/reservedregions(kind:options:)), [captura de escena](https://developer.apple.com/documentation/uikit/uitraitcollection/scenecapturestate), [presentación externa](https://developer.apple.com/documentation/uikit/presenting-content-on-a-connected-display). Sin ejecución de tests, compilaciones ni ensayos runtime de estos cambios.

Licencia seleccionada por autorización del usuario: MIT, en [LICENSE](../LICENSE). No se ha creado repositorio remoto ni publicado versión.


### Presentación por ventana — 30 de octubre

`FoldAssessment.presentation` añade `FoldDisplay`, `FoldPresentationMode`, `FoldInteriorLayout`, regiones lógicas y metadatos de geometría. La pantalla exterior/interior se deriva del mismo perfil dimensional del clasificador, únicamente con resultado Duo inferido. No se deriva del ángulo ni del ancho de ventana.

La app pasa `interiorLayout:` al clasificador; UIKit ofrece la misma elección mediante `FoldContextObserver.interiorLayout` para su propiedad assessment. El valor inicial unspecified no inventa que la app está dividida o extendida. Exterior produce una región; interior extendido una región; interior dividido dos mitades horizontales o verticales, siempre dentro de la ventana medida. La intención de la app no certifica que su UI haya aplicado esa distribución.

No se observaron regiones físicas ni límites de bisagra mediante una API nueva. La consulta local DocumentationSearch sobre regiones/arrangement devolvió referencias genéricas de contenedores y no permitió integrar un contrato de regiones del sistema. Las regiones suministradas son cálculos lógicos explícitos, sin safe areas automáticas, sin deducir cantidad de pantallas físicas ni tamaño doble. La bisagra conserva su observación separada y la geometría exige contexto, vigencia, origen y fuente UIWindow.bounds compatibles. La validación de esta implementación queda pendiente; no se han ejecutado tests ni compilaciones.

Ejemplos de uso en el [README](../README.md#3-elegir-interior-dividido-o-extendido).


La inferencia de Duo está implementada en `FoldClassifier.evaluate`, con política predeterminada `.duo`. Compara píxeles nativos exactos 1398 × 2034 o 1878 × 2670 en cualquiera de las orientaciones. Dimensión sola produce `duoDimensionCandidate(origin:)`; dimensión más bisagra vigente y del mismo origen/contexto produce `duoInferred(origin:)`. Sin evidencias admisibles devuelve `insufficientInformation`. No exige transición ni postura concreta.

El observador UIKit expone `assessment`; el puente SwiftUI y la app consumen el mismo clasificador. Una pantalla de escena con rol windowApplication se registra como `applicationDisplay`; si UIScreen.mirrored no es nil se registra mirrored, y otros roles se excluyen como externos. Esa atribución describe presentación, no certifica hardware ni permite descartar iPhone Mirroring. La política acepta applicationDisplay con motivo `displayIdentityUnverified`, además de deviceDisplay. Unknown, externalDisplay y mirrored bloquean inferencia. Datos sintéticos no producen inferencia Duo real; system y simulator se conservan separados y nunca se mezclan.

Las transiciones son complementarias, con misma escena, ventana, origen, atribución, secuencia creciente y generación no posterior a la actual; una rotación de los mismos píxeles no cuenta como transición. Las muestras actuales históricas o de otro contexto se rechazan. La disponibilidad de API, nil y suspensión no prueban ausencia física.

Esta decisión sustituye la política anterior de mantener el modelo desconocido. Los apartados siguientes conservan la investigación y los resultados históricos; sus referencias a inferencia deshabilitada describen la revisión anterior. Los perfiles sintéticos y observationOnly siguen disponibles, pero ya no son la única funcionalidad del clasificador.

Validación de esta implementación pendiente. No se han ejecutado tests, compilaciones ni comprobaciones nuevas. No hay hardware físico disponible; no se atribuyen a estos cambios los resultados anteriores.

[README y ejemplos](../README.md) · [Checklist](Checklist.md)

## Contenido

- [Arquitectura, viabilidad y propuesta inicial](#arquitectura)
- [Contratos implementados](#contratos)
- [Clasificación y reglas puras](#clasificacion)
- [Observación e integración](#observacion)
- [App de diagnóstico y resultados](#diagnostico)
- [Uso del ejemplo local](#uso-del-ejemplo)
- [Evidencia dimensional](#dimensiones)
- [Controles del simulador y límites](#controles)
- [Decisión sobre inferencia](#inferencia)


<a id="arquitectura"></a>

## Arquitectura, viabilidad y propuesta inicial

> Registro de investigación y propuesta inicial del 25–26 de octubre. Las expresiones «propuesto» y «pendiente» de esta sección reflejan esa fase; los contratos implementados y el estado vigente se detallan en las secciones posteriores.

Investigación: 2026-10-25. Actualización de etapa 4: 2026-10-26. Los contratos descritos en Contracts.md están implementados; el clasificador puro está implementado según Classification.md; los adaptadores UIKit/SwiftUI están implementados según Observation.md. Ninguno es un símbolo de Apple.

### 1. Evidencia verificada y método

Se inspeccionó exclusivamente este proyecto y las instrucciones locales aplicables. No se encontraron archivos AGENTS.md en el proyecto ni en los directorios ascendentes consultados. En la inspección inicial el manifiesto definía AdapteDuoKit y la función `hello()`. La etapa 2 los sustituye por FoldContextKit, con Swift tools 6.4, núcleo sin UI y Swift Testing. No hay dependencias externas. Se retira el ajuste experimental ApproachableConcurrency: el núcleo usa valores Sendable y no necesita aislamiento global ni esa opción.

Entorno leído: Xcode 27.1 (27A9275), Apple Swift 6.4 (swiftlang-6.4.0.34.1), SDK iPhoneOS27.1.sdk. Esto describe el entorno local, no una prueba de ejecución en iPhone.

DocumentationSearch se consultó con `onHingeChange UIHingeInteraction hinge iPhone Duo`, `onHingeChange` y `UIHingeInteraction`. Devolvió coincidencias ajenas a los símbolos buscados. Se contrastaron después las páginas oficiales y los archivos públicos bajo:

`/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/`

- `UIKit.framework/Headers/UIHingeInteraction.h`
- `UIKit.framework/Headers/UIHinge.h`
- `SwiftUICore.framework/Modules/SwiftUICore.swiftmodule/arm64e-apple-ios.swiftinterface`

La presencia en cabeceras e interfaces verifica declaraciones. No se ejecutó un adaptador ni se comprobó su enlace o comportamiento físico.

#### Referencias obligatorias

| Referencia | Resultado y alcance |
| --- | --- |
| [Foro 847775](https://developer.apple.com/forums/thread/847775) | Respuesta de Apple: no hay API de identificación de Duo; los tamaños de apps iPhone pueden variar en otros contextos. No valida una heurística dimensional. |
| [Foro 847644](https://developer.apple.com/forums/thread/847644) | Resumen de Apple que enlaza las APIs de bisagra y las sitúa en iOS 27.1; describe transiciones como cambios de geometría/traits y soporte de varias escenas. No sustituye el contrato de cada símbolo. |
| [Tech Talk 111464](https://developer.apple.com/videos/play/tech-talks/111464/) | Describe onHingeChange y UIHingeInteraction para estado/ángulo en vivo. Recomienda APIs de regiones y arrangement para layout. Su explicación de nil es más simplificada que la cabecera actual de UIKit. |
| [UIHingeInteraction](https://developer.apple.com/documentation/uikit/uihingeinteraction) | Existencia y semántica corroboradas con SDK y versión Markdown oficial. La página HTML exige JavaScript. |
| [Preparación para Duo](https://developer.apple.com/iphone-duo/prepare/) | Confirma el contexto del dispositivo y recomienda medir vista/ventana, no asumir modelo por dimensiones. No establece aquí un perfil dimensional validado para identificación. |
| [onHingeChange](https://developer.apple.com/documentation/swiftui/view/onhingechange(isenabled:_:)) | Declaración corroborada en SwiftUICore y versión Markdown oficial. |

Las versiones Markdown se obtuvieron añadiendo `.md` a las URLs de los símbolos. Se evita depender de que el índice local esté actualizado.

#### SwiftUI: firma y disponibilidad

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

#### UIKit: firma y condiciones de entrega

`UIHingeInteraction` es una clase MainActor que conforma a UIInteraction. Su inicializador Swift documentado es `init(updateHandler:)`, con closure `(UIHingeInteraction, UIHingeInteraction.Update) -> Void`; se añade a una UIView mediante `addInteraction(_:)`. Expone `isEnabled: Bool`; la actualización expone `hinge: UIHinge?`.

Cabeceras: iOS, tvOS y visionOS 27.1, no watchOS. La web añade iPadOS y Mac Catalyst 27.1. No se propone soporte UIKit para macOS nativo.

La cabecera documenta entrega del estado inicial y posteriores cambios de bisagra o de jerarquía. No fija el instante respecto al lanzamiento ni exige una maniobra física. Si la interacción sale de una jerarquía que entrega datos, `hinge` pasa a nil. Deshabilitada no entrega ni encola actualizaciones; al reactivarse entrega el estado actual si está disponible. El handler escapa y exige evitar ciclos de retención.

`UIHinge.angle` es `CGFloat` en radianes. `UIHinge.Status` incluye `unknown`, `closed`, `partiallyOpen`, `fullyOpen`. Fully open significa apertura máxima permitida por el dispositivo, no un ángulo universal. Frecuencia y granularidad dependen del sistema; no fijar precisión ni frecuencia prometidas.

La explicación de nil del vídeo no basta para concluir ausencia física: la cabecera y la página específica describen otra causa. La biblioteca representará indisponibilidad de datos y conservará el origen del evento, sin inventar su causa cuando no pueda observarse.

### 2. Conclusión de viabilidad

**Verificado:** hay APIs públicas para observar bisagra y contexto de presentación; las declaraciones de bisagra están en el SDK instalado.

**Hipótesis:** dimensiones de pantalla compatibles más bisagra observada podrían sostener una inferencia de Duo. Una transición compatible en la misma escena podría contextualizarla. No prueba exclusividad ni aporta una segunda evidencia independiente de tamaño.

**Verificación dimensional posterior:** Apple publica 1398 × 2034 píxeles para la pantalla exterior y 1878 × 2670 para la interior ([especificaciones](https://www.apple.com/iphone-duo/specs/)). Ninguna coincide, intercambiando ejes, con las resoluciones de los iPhone compatibles con iOS 26 comparados en la investigación. Son rasgos candidatos, no perfiles de producción. **Pendiente:** lecturas reales de nativeBounds en Duo, invariantes frente a modos de presentación, atribución bajo Mirroring/pantalla externa y tasas de error.

**Decisión propuesta:** avanzar con observación y clasificación explicable, dejando la inferencia de modelo desactivada por defecto. Sin perfil validado no emitir candidato dimensional ni Duo inferido. No hay base para prometer identificación fiable del modelo; incluso un futuro perfil será una heurística revisable. Esto conserva explícitamente ambos objetivos y sus diferentes límites.

### 3. Separación de responsabilidades

1. **Observación:** adaptadores MainActor ligados a la vista, ventana y escena del consumidor. Capturan eventos públicos, disponibilidad, geometría y ciclo de vida; no clasifican modelos.
2. **Evidencias:** valores inmutables Sendable con origen, unidad, ámbito, secuencia temporal local y vigencia. Diferencian no recibido, API no disponible, observación suspendida y dato recibido sin bisagra.
3. **Clasificación:** función pura de evidencias y política explícita; devuelve capacidades, inferencia, motivos y limitaciones. No consulta UIKit, reloj, estado global ni servicios.
4. **Integración:** SwiftUI entrega contexto por instancia de vista raíz/ventana; UIKit vincula un observador a una vista de la ventana concreta. Ambas rutas alimentan el mismo núcleo. La app decide layout y navegación.

Cada ventana tiene su propio observador y snapshot, incluso si comparte escena con otra ventana. La identidad de escena y ventana será local y efímera, sin identificadores de hardware o persistencia personal. No usar singleton, UIScreen.main, UserDefaults ni AppStorage para el tamaño compartido. Reasociar al cambiar de jerarquía; limpiar observaciones al desmontar; marcar como históricas las muestras anteriores. Nunca mezclar una bisagra antigua de un contexto con dimensiones nuevas de otro.

Se propone un snapshot actual y un historial acotado por sesión para transiciones. No persistir ni enviar datos. La continuidad de escena no demuestra continuidad de pantalla: una transición conservará ambas procedencias, sin asumir que cada resize es plegado.

#### Magnitudes y procedencia

| Dato conceptual | Unidad y ámbito | Uso permitido |
| --- | --- | --- |
| Tamaño de vista raíz | Puntos del espacio local de esa vista | Contexto de presentación, no tamaño de pantalla |
| Tamaño de ventana | Puntos de la ventana identificada | Resize/multitarea; nunca identidad de modelo |
| Métrica de pantalla | Puntos o píxeles, campos distintos y API exacta registrada | Solo comparación con perfil de igual procedencia y unidad |
| Escala | Factor de escala del contexto | No convertir pulgadas ni asumir densidad física |
| Tamaño físico comercial | Pulgadas u otra longitud | Fuera de las reglas iniciales |
| Ángulo | Radianes en el núcleo; conversión explícita desde Angle | Capacidad observada, no tamaño de layout |

Para geometría se propone seguir las fuentes de vista/ventana de la guía de preparación. Si se necesitan métricas de pantalla, resolver la pantalla desde la ventana/escena actual, sin almacenarla globalmente. Antes de implementar cualquier perfil se verificará el contrato preciso de bounds, nativeBounds, escala y orientación elegido. Datos de view/GeometryProxy no se etiquetarán como window sin garantizar que miden esa ventana.

### 4. Estructura propuesta del paquete

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
    FichaTecnica.md
    Checklist.md
README.md
```

Un producto y un target público mantienen pequeña la integración; carpetas separan responsabilidades. Alternativa: targets Core/SwiftUI/UIKit si la compilación o portabilidad lo exige, a costa de más módulos. Decisión de etapa 2: Swift tools 6.4, iOS/iPadOS 26 como mínimo y APIs de bisagra protegidas por iOS 27.1. macOS 26 permite ejecutar el núcleo y sus tests localmente; no promete un adaptador de bisagra para Mac. Ver [contratos y validación](#contratos).

### 5. API pública conceptual

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

#### Reglas iniciales propuestas

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

### 6. Alternativas y cuestiones pendientes

- Observación de capacidades sin inferencia de modelo: útil y viable, pero no resuelve la identificación solicitada.
- Heurística dimensional: investigable, susceptible a falsos positivos y negativos; sin garantía futura.
- Adaptación directa mediante geometría, regiones reservadas y contenedores de Apple: opción del consumidor; fuera del motor de layouts de esta biblioteca.
- No usar tablas de hardware, APIs privadas ni inspección de identificadores como sustituto de la hipótesis.
- Verificar comportamiento inicial SwiftUI, reactivación UIKit, suspensión, escenas desconectadas, varias ventanas y cambio de pantalla.
- Definir cuándo vence una muestra sin usar un timeout arbitrario como prueba de ausencia; pasar tiempo/vigencia explícitos a la lógica pura si fueran necesarios.
- Investigar cómo representar Mirroring/pantalla externa cuando no existe evidencia pública suficiente para atribuir el dispositivo. Desconocido es un resultado válido.
- Las firmas mínimas ya compilan con BuildProject para iOS Simulator, SDK 27.1 y deployment target 26.0. Sigue pendiente observar las entregas en simulador y hardware por separado.

### Implementación de etapa 3

[Classification.md](#clasificacion) define la API efectiva de reglas puras. Sustituye los nombres conceptuales de inferencia por resultados explícitamente sintéticos. No hay inferencia de producción.

### Implementación de etapa 4

[Observation.md](#observacion) describe el observador MainActor por ventana y el puente SwiftUI basado en UIKit. Se elige callback síncrona para UIKit y cola diferida acotada para SwiftUI, con señal de desbordamiento; no se expone AsyncSequence en esta versión. Las pruebas runtime con escena activa siguen pendientes.


<a id="contratos"></a>

## Contratos implementados

Fecha: 2026-10-26. API inicial sujeta a revisión antes de publicar.

### Compatibilidad

- Swift tools 6.4; producto, paquete y módulo `FoldContextKit`.
- iOS/iPadOS 26 como mínimo, siguiendo la comparación y alcance acordados en la conversación.
- En versiones anteriores a 27.1, la futura observación de bisagra devolverá `missing(.apiUnavailable)`, nunca «sin bisagra». El observador de etapa 4 calcula ese estado cuando está activo; al estar suspendido informa suspensión y permite consultar isHingeAPIAvailable.
- En 27.1 o posterior, antes de recibir datos corresponde `awaitingSample`; la mera disponibilidad de símbolos no acredita hardware.
- macOS 26 permite consumir el núcleo y ejecutar Swift Testing sin simulador. No se añade observación de bisagra en macOS, Android ni otras plataformas. SwiftPM puede permitir compilar el núcleo en otros destinos; eso no significa soporte de integración validado.
- Las comprobaciones de UIKit/SwiftUI necesitan SDK 27.1. El mínimo de ejecución iOS 26 no implica compatibilidad del código de validación con SDK antiguos.

### Valores y unidades

Los archivos del núcleo no importan Foundation, SwiftUI, UIKit ni Combine; los adaptadores iOS sí importan Foundation/UIKit/SwiftUI en archivos condicionados por plataforma. Expone estructuras inmutables Equatable y Sendable.

| Tipo | Contrato |
| --- | --- |
| `PixelSize` | Enteros positivos en píxeles; inicializador falla si algún lado no es positivo |
| `PointSize` | Double finitos no negativos en puntos; cero permitido durante layout |
| `PresentationSize` | Puntos y origen exacto: bounds de ventana, bounds de vista o geometría SwiftUI |
| `NativeScreenSize` | Píxeles procedentes de UIScreen.nativeBounds de la pantalla de la escena observada; ejes nativos, sin intercambiar automáticamente por rotación |
| `HingeSample` | Estado y ángulo opcional en radianes; rechaza NaN/infinito, sin imponer ángulo máximo universal |
| `FoldEvidence` | Contexto actual y observaciones independientes de presentación, pantalla y bisagra |

No convertir automáticamente píxeles a puntos, ni usar las dimensiones comerciales en pulgadas. La atribución de pantalla (`deviceDisplay`, `externalDisplay`, `mirrored`, `unknown`) es un dato suministrado, no una detección ya implementada. Usar `unknown` cuando la fuente no permita establecerla.

### Procedencia y vigencia

Cada muestra observada lleva `EvidenceMetadata`: origen system/simulator/synthetic/unknown, escena, ventana, generación, secuencia y vigencia current/historical. Las identidades deben ser locales y efímeras; no se generan ni persisten identificadores personales. El origen lo proporciona el observador o el ensayo; el núcleo no autentica hardware.

La generación debe cambiar al reasociar la ventana a otra pantalla o jerarquía. La secuencia aumenta dentro de una sesión y no es una fecha ni una garantía de simultaneidad. Dos muestras con distinta procedencia temporal no se presumen atómicas.

`current` solo tiene significado dentro del contexto/generación registrado. Una muestra puede conservarse como `historical`; el núcleo permite representar contextos distintos para que el futuro clasificador rechace combinaciones incompatibles sin perder trazabilidad. No hay expiración por tiempo ni normalización automática. El observador futuro será responsable de marcar historial al suspenderse/desmontarse; el clasificador deberá comprobar ámbito y vigencia, no confiar solo en el último valor.

### Ausencia de datos

`Observation<Value>` separa `observed(value, metadata:)` de `missing(reason)`:

- `apiUnavailable`: no se puede usar la API en este sistema.
- `awaitingSample`: todavía no se ha recibido una muestra.
- `observationSuspended`: observación detenida/deshabilitada.
- `unavailableInContext`: actualización sin valor; no presupone causa física.

Los estados missing corresponden al contexto actual del snapshot; no son eventos históricos con metadatos. Si más adelante se necesita un registro de callbacks, se modelará aparte. Los estados de bisagra desconocidos o futuros se representarán como `HingeStatus.unknown`. La falta de ángulo no equivale a cero.

La etapa 2 no añadió clasificación. La etapa 3 añade el clasificador puro descrito en [Classification](#clasificacion), sin `isDuo`, perfiles de producción ni selección de vistas.

### Verificación reproducible

1. Abrir el paquete en Xcode y seleccionar el esquema FoldContextKit.
2. BuildProject con buildForTesting para iOS Simulator: compila también `PlatformAPIValidation` porque es dependencia del target de tests. Deployment target 26.0, SDK 27.1. Los probes comprueban ambas firmas y ramas protegidas con `#available`; nunca se ejecutan en los tests.
3. RunAllTests en My Mac: tres tests pasan (medidas inválidas, distinción de estados ausentes y conservación del contexto histórico).
4. `Validation/LocalConsumer` es un consumidor SwiftPM independiente con dependencia local por ruta y `import FoldContextKit` normal, sin `@testable`.

El target PlatformAPIValidation queda fuera del producto de biblioteca. No se han observado callbacks en simulador ni en hardware físico. No había destino iOS 26 en la lista de Xcode: se ha comprobado el deployment target mediante compilación, no ejecución en iOS 26.

El consumidor local compiló y ejecutó correctamente el 2026-10-26, mostrando `FoldContextKit local import OK`. En este entorno restringido fue necesario redirigir las cachés y deshabilitar únicamente el sandbox interno anidado de SwiftPM:

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/FoldContextKit-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/FoldContextKit-module-cache \
swift run --disable-sandbox \
    --package-path Validation/LocalConsumer \
    --scratch-path /private/tmp/FoldContextKit-LocalConsumer-build \
    --cache-path /private/tmp/FoldContextKit-cache \
    --config-path /private/tmp/FoldContextKit-config \
    --security-path /private/tmp/FoldContextKit-security LocalConsumer
```

No se requirió acceso a otros repositorios ni servicios remotos.

La etapa 4 implementa observación y vigencia según [Observation](#observacion).


<a id="clasificacion"></a>

## Clasificación y reglas puras

Implementadas el 2026-10-26. No constituyen validación de hardware.

### API

`FoldClassifier.evaluate(evidence:policy:previousScreen:)` devuelve un `FoldAssessment` con contexto de presentación, capacidad, inferencia y motivos tipados en orden determinista. No lee reloj, UI, almacenamiento ni estado global. No modifica evidencias ni navegación.

La política es obligatoria:

- `observationOnly`: informa de bisagra observada y conserva su origen; no infiere modelo.
- `synthetic(profile)`: evalúa un `SyntheticDimensionProfile` explícito con dos tamaños distintos en píxeles. Solo acepta origen synthetic para la inferencia. No incluye resoluciones de Duo ni permite promover muestras system/simulator a una inferencia sintética.

Resultados de modelo: `insufficientInformation`, `syntheticDimensionCandidate`, `syntheticDuoInference`. Los dos últimos son resultados de ensayo, no identificación de un dispositivo real. Los metadatos son entradas declaradas por el consumidor, no una autenticación del origen.

### Reglas

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

### Unidades, fuentes y vigencia

Solo `NativeScreenSize` participa en la comparación. `PresentationSize` está tipado en puntos y no se convierte ni se usa como resolución. La equivalencia dimensional permite intercambiar ancho/alto: girar una misma resolución no crea una transición entre pantallas. No hay tolerancias implícitas.

Para una muestra actual, escena, ventana y generación deben coincidir exactamente con el snapshot; validity debe ser current y origin conocido. Historical se interpreta como no vigente para la evaluación actual. No hay caducidad temporal automática: corresponde al observador marcar la vigencia. Las pruebas de caducidad cubren esta invalidación explícita, no tiempos de entrega reales.

Las identidades locales deben renovarse entre sesiones; la secuencia debe aumentar durante toda la sesión, incluso al cambiar de generación. Estas obligaciones pertenecen al contrato del productor.

UIKit y SwiftUI son fuentes de bisagra válidas; su diferencia por sí sola no implica incompatibilidad. Los orígenes system/simulator/synthetic mezclados no sirven para inferir en la política sintética. Un origen unknown se rechaza con motivo explícito.

### Transición complementaria

`previousScreen` es opcional. Para anotar `compatibleDimensionTransition` debe pertenecer a la misma escena y ventana, tener generación no posterior y secuencia estrictamente anterior, origen synthetic, atribución deviceDisplay y coincidir con el otro tamaño del perfil. La muestra anterior puede ser historical porque se utiliza como historia, nunca como estado actual.

La transición no cambia el resultado de modelo. Si la historia es incompatible, se explica y se ignora; una combinación actual válida sigue siendo válida. Sin dimensión actual válida, la historia tampoco permite inferir. No se exige plegar el dispositivo ni se interpreta la rapidez del resize como causa física.

### Validación

RunAllTests de Xcode: 29 casos superados, 0 fallos, 0 omitidos (26 de clasificación y 3 de contratos). Se comprobó la inclusión de los archivos nuevos tras refrescar el manifiesto SwiftPM.

Cobertura: datos ausentes (API no disponible, espera, nil y suspensión), cuatro estados de bisagra, dos fuentes de bisagra, ambas dimensiones iniciales, política de observación, contradicciones, rotación, tres fuentes de geometría en puntos, historia opcional, secuencias fuera de orden, contexto y generación, datos históricos, origen desconocido/mezclado y atribuciones externas/reflectadas/desconocidas. Las medidas 100 × 200 y 300 × 400 son artificiales.

En la etapa 3 no se habían observado callbacks. Los ensayos posteriores del simulador están registrados en [Observation](#observacion); hardware físico sigue pendiente. No se han medido tasas de falsos positivos/negativos: los tests comprueban resultados esperados con entradas controladas.

Decisión de etapa 7: [mantener modelo desconocido](#inferencia), sin perfiles experimentales de hardware ni de producción.


<a id="observacion"></a>

## Observación e integración

Actualizado: 2026-10-26. Integración compilada para iOS Simulator 27.1, mínimo iOS/iPadOS 26. Las pruebas de integración utilizan entradas controladas. Un ensayo adicional con RuntimeProbe observa el runtime del simulador; ninguno acredita plegado físico.

### UIKit

Retener un `FoldContextObserver` por vista raíz/ventana. No compartirlo entre ventanas. `start(in:)` añade una subvista transparente, sin interacción táctil ni accesibilidad, que observa cambios de jerarquía y layout. No elige vistas ni cambia navegación.

```swift
private let foldObserver = FoldContextObserver()

// Al activar la observación de la vista raíz:
foldObserver.onChange = { [weak self] event in
    // Consumir el evento sin retener cíclicamente al propietario.
    self?.consume(event)
}
foldObserver.start(in: view)

// Al suspender temporalmente:
foldObserver.isEnabled = false
// Al reactivar:
foldObserver.isEnabled = true

// Al retirar definitivamente la integración:
foldObserver.stop()
```

`consume` representa un método del consumidor, no API del paquete. Todas las operaciones y callbacks están aislados en MainActor. El callback UIKit es síncrono y no usa una cola de eventos. Debe ser breve. `snapshot` permite consultar el último estado y `refresh()` releer geometría si el host cambia la presentación sin generar layout.

`stop()` es idempotente, retira interacción/subvista/notificaciones e invalida los datos actuales. La liberación del observador también limpia los recursos. Las referencias a ventana, escena y pantalla son débiles. Una generación de interacción impide aceptar callbacks anteriores al desmontaje o reactivación.

### SwiftUI

```swift
content.onFoldContextChange(isEnabled: enabled) { event in
    switch event {
    case let .snapshot(evidence, _):
        // Guardar el snapshot o evaluar solo capacidades.
        let assessment = FoldClassifier.evaluate(evidence: evidence, policy: .observationOnly)
        // El consumidor decide cómo utilizar assessment.
    case let .overflow(droppedEvents):
        // No asumir continuidad: faltan droppedEvents eventos anteriores.
        // El siguiente snapshot contiene el estado disponible más reciente de su secuencia.
        break
    }
}
```

El ejemplo es conceptual; `content` y `enabled` pertenecen a la app. Aplicar una vez a una raíz estable de cada ventana. El modificador usa UIViewRepresentable y un coordinador propio; no necesita Combine. El coordinador configura y entrega mediante tareas MainActor diferidas para no modificar estado SwiftUI durante updateUIView. `dismantleUIView` cancela configuración y entrega pendientes, vacía la cola y detiene el observador. El consumidor no recibe callbacks posteriores a la cancelación.

Se utiliza el mismo observador UIKit en ambos adaptadores. La fuente sigue siendo `uiHingeInteraction`, nunca `swiftUIHingeChange`. No se promete entrega inicial del modificador nativo de Apple onHingeChange, que aquí no se utiliza.

### Primera entrega, disponibilidad y ciclo de vida

- `start` proporciona un primer snapshot sin exigir movimiento. Sin ventana/escena activa se informa `observationSuspended`.
- Con escena activa: geometría inmediatamente disponible y bisagra `awaitingSample`, o `apiUnavailable` en sistemas anteriores a 27.1. `isHingeAPIAvailable` expresa disponibilidad del símbolo, no hardware.
- La interacción pública de UIKit documenta entrega inicial y posteriores actualizaciones. La biblioteca no impone un plazo ni inventa una muestra si no llega.
- Deshabilitar, desactivar/background o desconectar la escena retira la interacción y publica datos suspendidos. Reactivar vuelve a leer geometría y crea una nueva interacción, esperando una nueva muestra.
- Se filtran notificaciones por la escena asociada, no por un estado global de aplicación. Las notificaciones de ciclo de vida usan selector síncrono en MainActor para no retrasar invalidaciones; no se usa Combine.
- Cambiar ventana, escena, pantalla o jerarquía invalida muestras y aumenta la generación. También se invalida si cambian los píxeles nativos aunque el objeto UIScreen sea el mismo.
- `nil` recibido equivale a `unavailableInContext`; no demuestra ausencia de bisagra. Los estados de bisagra no reconocidos se conservan como unknown.

### Fuentes y unidades

| Campo | Fuente efectiva | Unidad |
| --- | --- | --- |
| presentationSize | UIWindow.bounds de la ventana que contiene la subvista de seguimiento | Puntos de ventana |
| nativeScreenSize | window.windowScene.screen.nativeBounds, resuelto de nuevo al refrescar | Píxeles nativos, sin rotar los ejes |
| hinge.angleRadians | UIHinge.angle | Radianes |
| metadata.origin | Compilación para simulador o sistema; inyección interna synthetic en tests | Procedencia, no prueba de modelo |

No se mide la vista SwiftUI como si fuera una pantalla. No se usa UIScreen.main, escala implícita, pulgadas ni perfiles de dimensiones. La atribución de pantalla se deja `unknown`: aún no existe una regla verificada que cubra pantalla externa y Mirroring. Esto bloquea la inferencia de modelo y mantiene la utilidad del contexto y la capacidad observada.

### Historial y entrega acotados

Historial: máximo 32 eventos por observador. Al consultarlo, las muestras se marcan historical sin modificar el snapshot actual. `discardedHistoryEvents` cuenta expulsiones del historial. Las identidades son UUID locales y efímeros propios de la sesión del observador; no se persisten ni correlacionan con identificadores personales.

SwiftUI: cola máxima de 32 eventos. Solo dos cambios consecutivos etiquetados hingeAngle pueden agruparse conservando el último; nunca se agrupan estados, disponibilidad, geometría o contexto. Dentro de la capacidad se conserva su orden. Si el consumidor no alcanza el ritmo y la cola se llena, se expulsan eventos antiguos y se entrega primero `overflow(droppedEvents:)`. No se garantiza retención ilimitada ni ausencia de pérdidas bajo desbordamiento. La señal permite al consumidor descartar cualquier inferencia de continuidad. UIKit no tiene esta cola diferida y entrega síncronamente cada cambio aceptado.

### Validación y límites materiales

En la revisión histórica de la etapa 4, 38 casos Swift Testing pasaron con el destino iPhone Duo Simulator 27.1 (29 anteriores y 9 nuevos), sin fallos ni omisiones. BuildProject verifica los adaptadores para iOS. Las pruebas comprueban:

- Inicio sin jerarquía y limpieza al parar/liberar.
- Primera entrega del coordinador y ausencia de entrega después de dismantleUIView.
- Cola SwiftUI desbordada, señal de pérdida y orden de cambios discretos.
- Dos UIWindow con estado independiente, puntos de ventana y píxeles de pantalla inyectados.
- Deshabilitación/reactivación, muestras iniciales síncronas y tardías, nil y API no disponible mediante driver controlado.
- Entrada/salida de foreground mediante señales de ciclo de vida inyectadas; ignorar señales de otra escena.
- Cambio de ventana, retirada/reinserción de jerarquía y cambio de dimensiones nativas.
- Invalidación histórica y deshabilitación desde dentro de un callback.

El ejecutor SwiftPM no tenía ninguna UIWindowScene conectada. Una prueba inicial que la exigía falló por esa condición; se separó la lectura de entorno y el driver de bisagra para probarlos con entradas explícitamente synthetic. No se presenta ese cambio como evidencia de hardware.

### Ensayo runtime con escena activa — etapa 4, 2026-10-26

Ensayo realizado con el harness del commit `4c5130f`, anterior a la pantalla de diagnóstico de etapa 5. App independiente [RuntimeProbe](#uso-del-ejemplo), consumidor local del paquete. Compilada mediante `xcodebuild` (SDK Simulator 27.1, mínimo iOS 26); el workspace del asistente solo ofrece el esquema del paquete, verificado además con BuildProject. Ejecutada en iPhone Duo Simulator 27.1. No se inyectaron muestras ni se accionó el plegado.

| Acción | Resultado observado |
| --- | --- |
| Arranque y montaje automático SwiftUI | Contador 4; última muestra `closed`, 0 radianes, fuente `uiHingeInteraction`, origen `simulator` |
| Auditar la escena | Una UIWindowScene activa (rawValue 0), una ventana, una UIHingeInteraction |
| Medidas iniciales | UIWindow.bounds: 466 × 678 puntos; UIScreen.nativeBounds: 1398 × 2034 píxeles; atribución unknown |
| Deshabilitar | Contador 5, observationSuspended, cero interacciones al auditar |
| Reactivar | Contador 7, nueva muestra closed; una interacción al auditar |
| Retirar raíz observada del árbol SwiftUI | Contador 7 estable tras auditoría y espera de 2 segundos; cero interacciones |
| Volver a montar | Eventos 11–13: closed → unavailableInContext → closed; contador 13 y una interacción al auditar |
| Enviar a Home y volver | Mismo proceso: inactive → evento 14 observationSuspended → background → inactive → active → evento 15 awaitingSample → evento 16 closed |

El ensayo de montaje no llama manualmente a `dismantleUIView`. El número de eventos es el de esta ejecución, no un contrato de cantidad, orden respecto al arranque ni latencia. La observación de cero interacciones y contador estable acredita la retirada durante el intervalo inspeccionado; no prueba todas las carreras posibles. Las medidas se registran como resultado del simulador, **no** como perfil de producción ni identidad oficial.

Secuencia conservada en [registro del ensayo](../Validation/RuntimeProbe/Results/2026-10-26-simulator.log). Contiene las líneas completas disponibles de stdout; se omitió la última línea parcial de auditoría por buffering. Se realizaron auditorías adicionales para vaciar el buffer de consola. El botón Home de la herramienta no produjo un cambio visible tras un reintento; se activó SpringBoard y después la app para obtener la transición efectiva, confirmada por las fases registradas.

El dato ausente transitorio del remontaje se recibió realmente en este runtime; no se ha determinado su causa interna ni acredita ausencia física. La integración conservó el estado separado y la muestra posterior.

**Pendiente:** cambio de pantalla y frecuencia de callbacks. También quedan pendientes iOS 26 en ejecución, Mirroring, pantalla externa y hardware físico. La primera entrega del modificador nativo `onHingeChange` sigue sin validarse: el adaptador usa UIKit. No se han medido tasas de falsos positivos o negativos; la atribución unknown mantiene bloqueada la inferencia de modelo.

Fuentes públicas contrastadas: cabeceras UIHingeInteraction.h/UIHinge.h del SDK 27.1; DocumentationSearch para [dismantleUIView](https://developer.apple.com/documentation/swiftui/uiviewrepresentable/dismantleuiview(_:coordinator:)) y [ciclo de vida de UIScene](https://developer.apple.com/documentation/uikit/uiscene). La inspección documental no sustituye la observación runtime.

### Mantenimiento de pruebas — 2026-10-29

Para evitar UIWindow.init(frame:) obsoleto, los tests sin escena conectada usan contenedores UIView sintéticos y un resolvedor de ventana inyectado internamente. El inicializador público conserva la resolución mediante view.window y exige UIWindowScene para obtener el entorno real. La geometría mutable de pruebas está aislada en MainActor; las entregas opcionales no requieren desempaquetar muestras innecesariamente. Esto no añade evidencia de hardware ni de jerarquías con escenas reales.

Los cambios de jerarquía entre contenedores sintéticos se acompañan de refresh explícito: no generan notificaciones de cambio de UIWindow. Este test comprueba la evaluación del nuevo contexto; el montaje automático real sigue respaldado por el ensayo runtime documentado de etapa 4.

Verificación del mantenimiento: BuildProject con targets de pruebas compila y el navegador de incidencias muestra cero advertencias. La primera ejecución dio 37/38: falló la expectativa de notificación automática en un contenedor sintético. Se corrigió el ensayo con refresh explícito; la segunda ejecución no devolvió resultado y Xcode indicó que no había app en ejecución. El estado final compila, pero la repetición runtime del ensayo corregido sigue pendiente. No se atribuyen los 38 casos históricos a esta revisión.


<a id="diagnostico"></a>

## App de diagnóstico y resultados

La app local [RuntimeProbe](#uso-del-ejemplo) consume el producto SwiftPM. No modifica el núcleo, no selecciona layouts de otras apps ni incorpora navegación automática, analítica o servicios remotos.

### Datos y evaluación

Cada ventana posee su snapshot e historial. Las tarjetas muestran valor, fuente, unidad, origen, secuencia, contexto de escena/ventana y vigencia. Los datos ausentes conservan el motivo; no se sustituyen por cero. La disponibilidad del símbolo UIHingeInteraction se presenta separada de su habilitación y de la recepción de muestras.

El clasificador usa exclusivamente `observationOnly`. Muestra capacidad observada y motivos, pero conserva el modelo como información insuficiente. No evalúa dimensiones para identificar modelos. `current` representa vigencia contextual, no una garantía temporal de frescura.

El historial visible tiene un máximo de 32 entradas, identidades estables y contadores separados para expulsiones locales y pérdidas de entrega. Sus entradas se etiquetan como históricas y no alimentan al clasificador. Cambiar de modo descarta snapshot e historial; desmontar retira el snapshot.

### Procedencia

| Modo | Etiqueta y tratamiento |
| --- | --- |
| Simulador | SIMULADOR; muestras con origen simulator, sin evidencia física |
| Ejemplo sintético | SINTÉTICO; observador real retirado, valores arbitrarios con origen synthetic y fuentes simuladas |
| Fuera del simulador | SISTEMA; no se certifica hardware ni modelo, se exige comprobar el entorno |
| Validación física | Pendiente; ninguna ejecución física se declara realizada |

La muestra sintética es una ilustración de contratos: 300 × 500 puntos, 600 × 1000 píxeles, ángulo de 1 radián. No es un perfil de dimensiones ni una simulación acreditada del hardware. Se mantiene la política observationOnly.

### Compilación

App compilada con Xcode/SDK Simulator 27.1 para iPhone Duo Simulator, mínimo iOS 26. Debug utiliza la arquitectura activa para alinear app y dependencia SwiftPM. El esquema del workspace del asistente sigue siendo el paquete: BuildProject comprueba este, y xcodebuild comprueba la app independiente.

Los 38 casos del paquete corresponden a la validación previa de contratos/reglas/integración; no se presentan como pruebas nuevas de la pantalla. El registro de consola de etapa 4 corresponde al commit 4c5130f, no a la nueva interfaz.

### Límites

Pendientes hardware físico, ejecución en iOS 26, Mirroring, pantallas externas y múltiples escenas simultáneas de la app de diagnóstico. No hay perfiles de producción, tasas de falsos positivos/negativos ni garantía de identificación. Las comprobaciones visuales no equivalen a una auditoría completa de accesibilidad.

### Observación de la interfaz

En el ensayo previo a la interrupción, iPhone Duo Simulator 27.1 mostró datos del runtime con origen simulator: píxeles de UIScreen.nativeBounds, bisagra con ángulo 0 radianes, metadatos de contexto/vigencia, clasificación observationOnly y seis entradas del historial desplegable. No se apreciaron textos solapados ni recortados en las capturas revisadas.

El 27 de octubre se recuperó la conexión de la herramienta al simulador y se comprobó deshabilitación (tarjetas suspendidas, capacidad desconocida), desmontaje (sin snapshot vigente) y modo sintético (aviso explícito, controles de observación deshabilitados, medidas artificiales y origen synthetic). Los hitPoints iniciales del interruptor sintético no lo activaron; la pulsación en el thumb visible sí funcionó. Esta limitación de automatización no se presenta como un fallo funcional reproducido de la app. Al volver a observación, la pantalla mantuvo ausencia de snapshot mientras los controles seguían apagados. Después de montar/habilitar recibió un contexto nuevo y muestras simulator: 1398 × 2034 píxeles, closed y 0 radianes. En modo sintético se verificaron también partiallyOpen, 1 radián y modelo insufficientInformation con política observationOnly. No se auditó directamente el número de interacciones internas en esta versión; la comprobación cubre interfaz y reemplazo de muestras.

Artefactos de la comprobación del 27 de octubre: sesión `FoldContext Diagnostic Recovery`, marcas `17_52_24_543` (suspensión), `17_54_29_549` (desmontaje), `17_54_41_235` (banner sintético), `17_54_48_161` (medidas), `17_55_59_633` (bisagra/clasificación) y `17_56_32_346` (retorno al runtime). Capturas y jerarquías temporales en ActionArtifacts/AE8382CA-2E55-45EE-92CE-D23952E345AE/DeviceInteractionSynthesize. No se observaron solapamientos ni truncamientos inesperados.

### Posturas pendientes de ensayo

La matriz de [Checklist](Checklist.md) incluye arranque y transición en modo libro, y arranque y transición con apertura a 90°. La app permite inspeccionar las muestras recibidas en esas posturas; no las detecta como modos de interfaz ni crea dos pantallas. Registrar ángulo objetivo y recibido por separado (90° equivale matemáticamente a π/2 radianes, sin garantizar el valor entregado por la API).

El ejemplo sintético de 1 radián permanece como ilustración de contratos y no acredita estas posturas. Ninguno de los cuatro ensayos se ha dado por observado en simulador o hardware físico.

### Controles añadidos después del ensayo visual

La app incluye lectura manual de scale/nativeScale desde su ventana y solicitud de otra ventana cuando el sistema admite múltiples ventanas. Su compilación está comprobada; su observación runtime quedó pendiente por fallos de conexión/instalación del simulador. Las capturas anteriores de la etapa 5 no prueban estos controles nuevos. Estado detallado en [SimulatorControls](#controles).


<a id="uso-del-ejemplo"></a>

## Uso del ejemplo local

Consumidor local de `FoldContextKit` mediante SwiftPM (`../..`), separado del producto distribuido. Abrir `Validation/RuntimeProbe/RuntimeProbe.xcodeproj` desde la raíz del repositorio, seleccionar el esquema RuntimeProbe y un destino iOS. Mínimo iOS 26; bisagra desde 27.1. No necesita cuenta, red ni permisos adicionales.

La pantalla desplazable muestra:

- Entorno de ejecución y modo sintético explícito. Fuera del simulador se indica «sistema», sin certificar el hardware ni el modelo. La validación física sigue pendiente.
- Disponibilidad de UIHingeInteraction separada de habilitación y recepción de muestras.
- Puntos de ventana, píxeles nativos y radianes con fuente, origen, secuencia, vigencia y ámbito por muestra. La vigencia es contextual, no una medida de antigüedad temporal.
- Capacidad, modelo y motivos calculados con la política observationOnly. No usa perfiles ni identifica Duo por dimensiones.
- Historial desplegable de hasta 32 entradas, con fases, cambios y contexto de escena/ventana. Distingue expulsiones del historial y pérdidas en la entrega; las entradas son históricas y no se reutilizan para clasificar.

Cada raíz WindowGroup tiene su propio estado. El observador está fuera del contenido desplazable para conservar su montaje al hacer scroll. Desmontar retira el snapshot; cambiar de modo limpia snapshot e historial. Los identificadores son efímeros del observador, no identificadores personales ni del dispositivo. No se persiste historial ni se envían datos.

### Ejemplo sintético

El interruptor retira el observador real. Genera únicamente una muestra artificial: 300 × 500 puntos, 600 × 1000 píxeles y un ángulo de 1 radián. Estas cifras no son un perfil de dispositivo. Las fuentes del contrato se representan como simuladas, y todas las muestras llevan origen synthetic. La política sigue siendo observationOnly; no se mezcla la muestra con datos del runtime.

Al volver al entorno se espera un snapshot nuevo. La disponibilidad de API sigue refiriéndose al sistema que ejecuta la app, no al fixture. Los controles de montaje/habilitación quedan deshabilitados mientras se muestra el fixture.

### Comprobación manual

1. Arrancar sin plegar. Comprobar etiqueta de entorno, API disponible/no disponible, recepción y metadatos.
2. Desplazarse hasta clasificación e historial. Verificar que «modelo desconocido» no se presenta como fallo de observación.
3. Deshabilitar/reactivar y desmontar/remontar. No deben quedar muestras antiguas presentadas como vigentes.
4. Activar el ejemplo sintético, revisar su origen y volver a observación del entorno.
5. Enviar al fondo y volver; revisar fases e invalidaciones en historial.

El registro `Validation/RuntimeProbe/Results/2026-10-26-simulator.log` pertenece al harness anterior de la etapa 4, commit 4c5130f. Sus controles de auditoría y consola no forman parte de esta pantalla. No se presenta ese registro como validación de la nueva interfaz. Detalles en [Observation](#observacion).

#### Modo libro y 90°

Realizar por separado arranque directo y transición a cada postura, siguiendo el [protocolo de validación](Checklist.md). Consultar bisagra, medidas y contexto sin exigir un cambio de tamaño. «Modo libro» no implica que UIKit exponga dos pantallas independientes. Los ensayos siguen pendientes; el fixture sintético de 1 radián no los sustituye.

#### Escalas y múltiples ventanas

«Leer escalas de esta ventana» obtiene scale, nativeScale, bounds y nativeBounds de la pantalla resuelta desde la UIWindowScene de una vista anclada en esa ventana. Los factores son adimensionales. La lectura manual se conserva como histórica hasta pulsar de nuevo; es diagnóstico del runtime incluso en modo sintético y no alimenta al clasificador.

«Abrir otra ventana de diagnóstico» solicita una nueva instancia del WindowGroup si supportsMultipleWindows lo permite. Cada raíz conserva su propio estado; el sistema decide la presentación. Esto no crea una pantalla externa ni acredita una configuración concreta de multitarea.


<a id="dimensiones"></a>

## Evidencia dimensional

Revisión: 2026-10-27. Objetivo: vincular cada dimensión candidata a una fuente documental, una API y una observación, sin convertir especificaciones en medidas de interfaz.

### Fuentes comprobadas

Apple publica 1398 × 2034 píxeles para la pantalla exterior y 1878 × 2670 para la interior en [las especificaciones de Duo](https://www.apple.com/iphone-duo/specs/), sección Displays. Página consultada de nuevo en esta revisión. Son resoluciones publicadas; no son tamaños de UIWindow.

DocumentationSearch de Xcode devuelve para [UIScreen.nativeBounds](https://developer.apple.com/documentation/uikit/uiscreen/nativebounds) la firma `var nativeBounds: CGRect { get }`: mide píxeles y utiliza una referencia vertical que no cambia al rotar el dispositivo. La documentación de UIScreen indica resolver la pantalla desde la UIWindowScene de la ventana. La lectura implementada es `window.windowScene.screen.nativeBounds`, con comprobación de contexto en el observador.

Esto verifica la semántica general de la API, no certifica que una lectura pertenezca al panel interior/exterior ni identifica un modelo. No se debe esperar que nativeBounds intercambie ejes al girar; la geometría de ventana en puntos es otra medida.

### Matriz por dimensión

| Dato | Evidencia documental | Lectura registrada mediante API | Estado para inferencia |
| --- | --- | --- | --- |
| Exterior: 1398 × 2034 píxeles | Especificaciones Apple verificadas | nativeBounds = 1398 × 2034 en Duo Simulator 27.1; atribución unknown | Parcial: no validado físicamente ni en todos los contextos |
| Interior: 1878 × 2670 píxeles | Especificaciones Apple verificadas | No hay lectura registrada en nuestros ensayos | Insuficiente: correspondencia API/panel pendiente |
| Ventana: 466 × 678 puntos | No es una especificación del dispositivo | UIWindow.bounds, mismo ensayo cerrado del simulador | Contexto de presentación; excluido de perfiles de resolución |
| Ventana en interior, libro o 90° | No se deduce desde pulgadas ni resolución | No hay lecturas registradas | Pendiente; no asignar valores calculados |

Registro primario del simulador: [2026-10-26-simulator.log](../Validation/RuntimeProbe/Results/2026-10-26-simulator.log), evento 3 y posteriores. La postura closed procede de la muestra de bisagra del runtime. La coincidencia con la resolución exterior publicada no cambia automáticamente la atribución unknown a deviceDisplay.

### Qué falta para cerrar el punto

1. Registrar nativeBounds en la pantalla interior al arrancar directamente abierto y al pasar entre pantallas; conservar medidas de ventana por separado.
2. Repetir la lectura de ambos paneles en hardware físico con referencia independiente de la postura/pantalla usada. No hacen falta identificadores personales.
3. Registrar SO/SDK, origen, fuente, unidades, contexto/generación, secuencia y vigencia. Para analizar escalas, obtener scale/nativeScale mediante sus APIs y documentar el contexto, sin calcularlas como cociente de una ventana arbitraria.
4. Contrastar orientación, modos de presentación y atribución, incluyendo los controles de la etapa 7. Establecer tolerancias solo si las variaciones observadas lo justifican.

Una lectura interior de simulador añadiría evidencia parcial, pero no cerraría por sí sola el criterio de suficiencia para identificación de hardware. No sustituirla por cambiar manualmente la geometría del simulador o por introducir una muestra sintética con esas cifras.

**Resultado:** resoluciones publicadas y contrato de nativeBounds verificados; observación exterior parcial disponible; correspondencia interior y suficiencia experimental pendientes. No se habilita ningún perfil.

### Alcance acordado sin hardware físico — 2026-10-27

El usuario confirma que no hay dispositivo físico disponible. Se acepta documentación oficial, SDK, pruebas controladas y simulador como alcance de validación de esta versión. La comprobación física deja de ser un requisito de cierre de esta entrega; queda como validación futura no realizada.

Este acuerdo no convierte las especificaciones en lecturas de API ni completa los ensayos pendientes del simulador, incluida la pantalla interior. El inventario de evidencia disponible queda cerrado para la decisión actual: observación de capacidades y contexto disponible, modelo desconocido y sin perfiles de hardware habilitados. No se exige obtener hardware para continuar el proyecto.

Control adicional: iPhone 17 Simulator 27.0 entregó nativeBounds 1206 × 2622 píxeles al girar, con ventana 402 × 874 → 874 × 402 puntos. El [inventario de superficies y controles](#controles) no debe confundirse con una lectura interior de UIKit.


<a id="controles"></a>

## Controles del simulador y límites

Alcance: documentación, SDK, pruebas controladas y runtimes disponibles. No se certifica hardware físico. Se separan las muestras de UIKit, las descripciones de superficies de Simulator y los fixtures artificiales.

### Lectura interior y escalas

[Inventario de superficies](../Validation/RuntimeProbe/Results/2026-10-27-screen-inventory.txt): Simulator enumera dos superficies Integrated, primary de 1398 × 2034 y primary-1 de 2007 × 2853. No se ha observado aún una ventana de nuestra app asociada a la segunda ni su nativeBounds. Por tanto, no se declara obtenida la lectura interior solicitada.

La resolución de esa superficie difiere de los 1878 × 2670 píxeles publicados para el panel interior. No se trata como error de nativeBounds ni como motivo para ensanchar tolerancias: son fuentes diferentes y su correspondencia no está verificada. Preferred UI Scale = 3 es un descriptor del simulador, no una lectura de UIScreen.scale/nativeScale. No se calculan puntos a partir de esas cifras.

### Tolerancias y contexto admisible de esta versión

- No hay tolerancia de identificación de modelo: no existe un perfil de hardware habilitado ni una comparación dimensional aplicada al runtime.
- La política synthetic compara enteros exactamente (0 píxeles de tolerancia) porque los valores de entrada son controlados. No se extrapola esa regla a hardware ni se ajusta con el inventario de framebuffers.
- Para observación se admiten puntos finitos no negativos y píxeles nativos positivos e íntegros. Son validaciones de representación, no márgenes de coincidencia.
- Para capacidad actual: muestra de bisagra vigente, contexto coincidente y origen conocido. simulator y synthetic permanecen visibles y no certifican capacidad física.
- La atribución unknown permite mostrar contexto, pero no autoriza identificación. Mirroring y externalDisplay tampoco son contextos admitidos por la política sintética; observationOnly se abstiene de identificar en todos los contextos.
- No hay umbral temporal ni angular justificado para detectar un modelo. Un ángulo de 90° es una condición objetivo de ensayo, no una regla de identificación.

Esta es una decisión explícita de tolerancias aplicables y contexto, no una calibración pendiente disfrazada de valor numérico.

### Controles y límites

| Caso | Procedimiento / observación | Conclusión |
| --- | --- | --- |
| NEG-IP17-01 | iPhone 17 Simulator iOS 27.0: API no disponible, bisagra apiUnavailable, capacidad desconocida y modelo insufficientInformation | Control de compatibilidad anterior a 27.1; no prueba ausencia física |
| ROT-IP17-01 | Ventana 402 × 874 → 874 × 402 puntos; nativeBounds 1206 × 2622 píxeles sin cambios, mismo contexto/generación 3, secuencia 3 → 4 | Rotación real de la interfaz observada, sin inferencia de modelo |
| ROT-DUO-01 | Orientación del dispositivo Landscape Left, interfaz permanece Portrait; 466 × 678 puntos y 1398 × 2034 píxeles sin cambios; restaurado Portrait | No se validó resize. Info.plist compilado sí declara portrait y ambas orientaciones horizontales; causa restante no determinada |
| SCALE-01 | Inventario con Preferred UI Scale 3 y dos superficies integradas | Solo inventario; cambios efectivos de escala de UIKit pendientes |
| EXT-01 | Se enumeran TVOut y Resizable | No demuestra conexión efectiva de una ventana de nuestra app a pantalla externa |
| MIRROR-01 | No se ha ejecutado iPhone Mirroring | No evaluado; no sustituirlo por una superficie Wireless/CarPlay |
| MULTI-01 | Aislamiento por ventana probado con entorno controlado en etapa 4 | No equivale a multitarea con escenas reales simultáneas |

Los controles de atribución desconocida, externa y reflejada de ClassificationTests prueban rechazo bajo entradas controladas; no acreditan estos entornos runtime.

### Interpretación de errores

Registrar separado: afirmación de modelo correcta/incorrecta, decisión negativa según criterio previo y abstención. Con observationOnly, insufficientInformation es la salida esperada, incluso en el simulador denominado Duo. No es falso negativo. Sin un perfil de identificación no existe aquí una prueba de sensibilidad o especificidad de dicho perfil; las tasas de falsos positivos/negativos son no evaluables, no 0 %.

No se introducirán perfiles experimentales para conseguir una clasificación positiva en estos ensayos. No se sustituirá un control no disponible por muestras sintéticas sin etiquetarlo.

### Evidencia conservada del control negativo

Jerarquías capturadas en el runtime: [API](../Validation/RuntimeProbe/Results/2026-10-27-iphone17-api-hierarchy.txt), [portrait](../Validation/RuntimeProbe/Results/2026-10-27-iphone17-portrait-hierarchy.txt), [clasificación](../Validation/RuntimeProbe/Results/2026-10-27-iphone17-classification-hierarchy.txt), [landscape](../Validation/RuntimeProbe/Results/2026-10-27-iphone17-landscape-hierarchy.txt) y [portrait restaurado](../Validation/RuntimeProbe/Results/2026-10-27-iphone17-restored-hierarchy.txt). La secuencia fue 3 → 4 → 5, generación 3. Sesión cerrada y orientación restaurada.

Este control no cubre un dispositivo sin bisagra bajo una API disponible: su sistema 27.0 carece de UIHingeInteraction. No se registra como validación de nil bajo 27.1.

### Instrumentación adicional

La app incorpora lectura manual de UIScreen.scale/nativeScale y geometría desde su propia ventana, sin selección global de pantalla. También permite solicitar otra ventana mediante openWindow cuando supportsMultipleWindows es verdadero. Ambos controles compilan con el SDK disponible; la lectura manual es histórica y no participa en inferencia.

### Mirroring: no disponible en el alcance acordado

[Apple exige un iPhone y un Mac configurados para iPhone Mirroring](https://support.apple.com/en-gb/120421), con la misma cuenta y dispositivos próximos. El alcance de este proyecto no dispone de ese entorno físico. Se registra **no disponible / no ejecutado**, no prueba superada ni fallo del paquete. Una superficie de Simulator denominada Wireless (CarPlay) no sustituye esta función. No se accede a cuentas ni se configuran dispositivos personales.

### Revisión final — 2026-10-29

El intento anterior de instalar la app en iPad no se completó: simctl devolvió NSMachErrorDomain -308 (servidor IPC terminado); la consulta appinfo terminó con estado de dispositivo no válido. Se apagó únicamente el iPad arrancado para ese ensayo. No se obtuvieron capturas ni lecturas nuevas de escalas o múltiples ventanas en ese intento.

Los controles manuales permanecen disponibles en la app. BuildProject volvió a compilar el paquete el 29 de octubre y xcodebuild terminó con salida 0 para la app independiente (SDK iphonesimulator, arm64). El único intento de activación del iPhone en la revisión del 29 de octubre terminó con «The device simulator cannot be connected». La sesión se cerró; no hubo nuevas capturas ni lecturas. simctl list aún lo enumeraba arrancado, lo que no prueba que la herramienta de interacción pueda conectarse.

Pantalla externa: todavía no hay una UIWindowScene de la app registrada en una salida externa. El ejemplo no configura una escena externa no interactiva dedicada. Ni enumerar TVOut/Resizable ni abrir otra ventana de aplicación sustituye ese ensayo. Este límite es distinto de Mirroring, que queda fuera del entorno disponible.

La versión se puede entregar como observador de capacidades y contexto, con estos límites publicados. No se cierra la validación experimental de esos entornos ni se habilita identificación de modelo.


<a id="inferencia"></a>

## Decisión sobre inferencia

Fecha: 2026-10-27. Decisión: **mantener el modelo desconocido; no habilitar perfiles experimentales de hardware ni de producción**. Se conserva `observationOnly`, cuyo resultado de modelo es `insufficientInformation`. La política `synthetic(profile)` continúa siendo exclusivamente una herramienta de pruebas con entradas artificiales.

Esta decisión cierra la evaluación de habilitación con la evidencia disponible, no completa la matriz experimental de la etapa 6. No demuestra que la hipótesis sea imposible: no hay respaldo suficiente para promoverla a identificación utilizable.

### Evidencia disponible y alcance

| Evidencia | Fuente trazable | Qué permite concluir | Qué falta |
| --- | --- | --- | --- |
| 1398 × 2034 píxeles | UIScreen.nativeBounds de la pantalla de la escena; [registro de etapa 4](../Validation/RuntimeProbe/Results/2026-10-26-simulator.log), eventos 3–16 | Valor recibido en Duo Simulator 27.1, atribución unknown | Dispositivo físico, repetición en otros modos y atribución admisible |
| 466 × 678 puntos | UIWindow.bounds, mismo registro | Tamaño de esa ventana durante el ensayo | No es resolución ni tamaño exclusivo de modelo |
| Resoluciones exterior/interior publicadas | Investigación documental previa en [Architecture](#arquitectura) | Candidatos documentales, no lecturas experimentales | Vincular ambas dimensiones a la API, contexto y hardware mediante observación reproducible |
| Bisagra closed, 0 radianes | UIHingeInteraction; mismo registro, origen simulator | Muestra entregada por el runtime en una escena activa | Posturas abiertas, libro, 90° y comportamiento físico |
| Dato ausente transitorio | Evento 12, unavailableInContext entre muestras closed | El estado ausente se conserva separado | No se ha determinado su causa; no acredita ausencia física |
| Reglas y entradas sintéticas | [Classification](#clasificacion), [Observation](#observacion) | Coherencia de contratos, invalidación y reglas bajo entradas controladas | No acreditan exclusividad dimensional ni errores de identificación real |

Las entregas repetidas de la misma sesión no son dispositivos independientes ni controles negativos. La pantalla interior no tiene una lectura runtime registrada en estos ensayos. La comparación documental anterior con iPhones compatibles con iOS 26 no descarta colisiones de contexto, otros dispositivos o modelos futuros.

### Unidades, tolerancias y contexto admisible

No se fija ninguna tolerancia numérica de producción. Tampoco se considera validada una tolerancia cero para identificación real. Los tests sintéticos comparan píxeles enteros exactamente y permiten intercambiar ejes; esa regla sirve para probar la lógica, no para justificar un perfil de hardware.

Los puntos de ventana no se convierten en píxeles ni se deducen desde pulgadas. Las escalas y orientaciones deben registrarse y contrastarse mediante sus APIs antes de proponer una normalización. Un ángulo objetivo de ensayo (por ejemplo, 90°) se registra separado del recibido; no se usa como identificador del modelo.

Requisitos propuestos, todavía no suficientes por sí solos para autorizar inferencia:

- Medidas procedentes de la pantalla resuelta desde la ventana/escena observada, con unidades y origen explícitos.
- Evidencias vigentes del mismo contexto/generación y una muestra de bisagra, no solo disponibilidad de API.
- Regla pública y comprobada de atribución a la pantalla del dispositivo. El observador actual conserva unknown; no cambiarlo a deviceDisplay por intuición.
- Ausencia de mezclas entre origen synthetic, simulator y system. System no autentica por sí mismo hardware físico.
- Tratamiento explícito de suspensión, nil, cambio de jerarquía y pérdidas de entrega. No reutilizar datos históricos como capacidad actual.
- Transición dimensional opcional y complementaria; nunca exigirla al arrancar ni contarla como señal independiente.

No existe todavía un contexto real aprobado para inferencia de modelo. Una ventana activa y un tamaño coincidente no bastan.

### Controles que siguen pendientes

| Control | Evidencia requerida | Estado |
| --- | --- | --- |
| Arranque exterior/interior, modo libro y 90° | Lecturas iniciales y transiciones sin exigir un gesto previo | Solo arranque cerrado observado en simulador; resto pendiente |
| Otros iPhone e iPad mini | Mismas APIs y contextos, modelo de referencia conocido por el operador | Pendiente |
| Escalas y rotación | Medidas antes/después, ejes y escala; no confundir rotación con cambio de pantalla | Reglas sintéticas probadas; observación de controles pendiente |
| Multitarea y múltiples ventanas | Atribución y snapshots por escena, cambios de tamaño sin plegado | Aislamiento controlado probado; contraste real pendiente |
| Mirroring y pantallas externas | Fuente efectiva y atribución comprobada; cambios de conexión | Pendiente |
| Hardware físico | Referencia independiente del modelo y postura, SO/SDK y registros reproducibles | Pendiente |

### Registro de resultados, sin tasas inventadas

| Caso | Entrada/procedencia | Resultado de modelo | Interpretación |
| --- | --- | --- | --- |
| DIAG-LIVE-01 | Ensayo de interfaz con datos simulator, bisagra y dimensiones | insufficientInformation bajo observationOnly | Abstención esperada; no clasificar como falso negativo |
| DIAG-SYN-01 | Fixture artificial 300 × 500 puntos, 600 × 1000 píxeles, 1 radián | insufficientInformation bajo observationOnly | Verifica presentación del fixture, no identidad física |
| RUNTIME-NIL-01 | Evento 12 del registro de etapa 4, bisagra ausente | No se registró evaluación de modelo en ese harness | Evidencia incompleta; no inventar un resultado de clasificación |

Los dos primeros resultados se documentaron en [DiagnosticApp](#diagnostico). No hay falsos positivos ni falsos negativos **medidos de identificación física**; esto significa «no evaluados», no cero errores. La capacidad observada y la identidad del modelo se evalúan por separado.

Para futuros casos registrar: identificador de ensayo, procedencia, versión de app/SO/SDK, modelo de referencia conocido independientemente del clasificador, postura, ventana/escena local, fuentes/unidades, muestras y motivos, política/perfil/versionado, resultado esperado y obtenido. Un falso positivo requiere una afirmación de modelo incorrecta; un falso negativo requiere una decisión negativa bajo un criterio previamente definido. `insufficientInformation` es abstención y debe contabilizarse por separado. Evitar identificadores personales. No calcular porcentajes sin una población y denominador explícitos.

### Condiciones para reconsiderar

Completar los controles anteriores y conservar registros de ambas dimensiones en contextos admisibles. Justificar cualquier tolerancia a partir de variaciones observadas y mostrar qué colisiones admite. Revisar falsos positivos, negativos y abstenciones con referencia independiente. Solo entonces proponer por separado un perfil experimental, sus límites y versión; nunca prometer identificación oficial o exclusividad futura.

Mientras tanto, FoldContextKit sigue aportando geometría por ventana, recepción de bisagra, procedencia, vigencia y una clasificación explicable de capacidades. No sustituye silenciosamente la hipótesis de identificación: esta permanece abierta y sin habilitar.

### Comprobaciones adicionales del 27 de octubre

Se consultaron los destinos de Xcode: había simuladores Duo 27.1 y otros iPhone/iPad 27.0; no figuraba un Duo físico ni un runtime iOS 26. El destino físico iPhone disponible figuraba con iOS 27.0 y no se ejecutó la app en él.

La ayuda pública de simctl, incluidos io y ui, no ofreció un comando para ajustar el ángulo de bisagra. Esto limita la automatización disponible; no demuestra que Simulator carezca de cualquier control de postura. No se cambió artificialmente la geometría para presentarla como plegado.

Control ROT-SIM-01: se solicitó Landscape Left en Duo Simulator y se restauró Portrait. La jerarquía reportó cambio de orientación del dispositivo, pero la interfaz de la app permaneció Portrait. Se conservaron 466 × 678 puntos, 1398 × 2034 píxeles, bisagra closed a 0 radianes, origen simulator y modelo insufficientInformation. No se validó intercambio de ejes de ventana; queda pendiente determinar la causa en la configuración/comportamiento del host. Artefactos: sesión FoldContext Rotation Check, marcas 18_26_46_749, 18_26_55_992, 18_27_01_835 y 18_27_55_370, bajo ActionArtifacts/AE8382CA-2E55-45EE-92CE-D23952E345AE/DeviceInteractionSynthesize.

Se arrancó iPhone 17 Simulator 27.0 para preparar un control negativo. La instalación inicial falló porque el binario temporal anterior ya no existía. La reconstrucción terminó correctamente (xcodebuild, salida 0). No se llegó a ejecutar y observar el control negativo; la compilación no se registra como prueba runtime superada.

La documentación de Apple consultada mediante DocumentationSearch distingue UIScreen.bounds en puntos y nativeBounds en píxeles. Esa distinción de unidades no proporciona por sí misma una regla de atribución, tolerancia o identificación.

**Cierre de esta revisión:** decisión de no habilitar perfiles confirmada. La recopilación experimental permanece incompleta; no se han observado ni inventado resultados para cubrir esas ausencias.

Detalle actualizado de fuentes, API y observaciones por dimensión: [DimensionEvidence](#dimensiones).

### Alcance acordado sin hardware físico — 2026-10-27

El usuario confirma que no hay dispositivo físico disponible. Se acepta documentación oficial, SDK, pruebas controladas y simulador como alcance de validación de esta versión. La comprobación física deja de ser un requisito de cierre de esta entrega; queda como validación futura no realizada.

Este acuerdo no convierte las especificaciones en lecturas de API ni completa los ensayos pendientes del simulador, incluida la pantalla interior. El inventario de evidencia disponible queda cerrado para la decisión actual: observación de capacidades y contexto disponible, modelo desconocido y sin perfiles de hardware habilitados. No se exige obtener hardware para continuar el proyecto.

Continuación: el control iPhone 17 se ejecutó posteriormente en iOS Simulator 27.0; API no disponible, capacidad desconocida y modelo insufficientInformation. Rotación de ventana observada con nativeBounds constante. Registro y decisiones de tolerancia/contexto en [SimulatorControls](#controles); este resultado sustituye el estado anterior de «no ejecutado» para ese control.
