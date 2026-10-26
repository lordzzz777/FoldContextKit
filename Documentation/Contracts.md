# Contratos implementados — etapa 2

Fecha: 2026-10-26. API inicial sujeta a revisión antes de publicar.

## Compatibilidad

- Swift tools 6.4; producto, paquete y módulo `FoldContextKit`.
- iOS/iPadOS 26 como mínimo, siguiendo la comparación y alcance acordados en la conversación.
- En versiones anteriores a 27.1, la futura observación de bisagra devolverá `missing(.apiUnavailable)`, nunca «sin bisagra». No hay todavía observador que calcule automáticamente ese estado.
- En 27.1 o posterior, antes de recibir datos corresponde `awaitingSample`; la mera disponibilidad de símbolos no acredita hardware.
- macOS 26 permite consumir el núcleo y ejecutar Swift Testing sin simulador. No se añade observación de bisagra en macOS, Android ni otras plataformas. SwiftPM puede permitir compilar el núcleo en otros destinos; eso no significa soporte de integración validado.
- Las comprobaciones de UIKit/SwiftUI necesitan SDK 27.1. El mínimo de ejecución iOS 26 no implica compatibilidad del código de validación con SDK antiguos.

## Valores y unidades

El núcleo no importa Foundation, SwiftUI, UIKit ni Combine. Expone estructuras inmutables Equatable y Sendable.

| Tipo | Contrato |
| --- | --- |
| `PixelSize` | Enteros positivos en píxeles; inicializador falla si algún lado no es positivo |
| `PointSize` | Double finitos no negativos en puntos; cero permitido durante layout |
| `PresentationSize` | Puntos y origen exacto: bounds de ventana, bounds de vista o geometría SwiftUI |
| `NativeScreenSize` | Píxeles procedentes de UIScreen.nativeBounds de la pantalla de la escena observada; ejes nativos, sin intercambiar automáticamente por rotación |
| `HingeSample` | Estado y ángulo opcional en radianes; rechaza NaN/infinito, sin imponer ángulo máximo universal |
| `FoldEvidence` | Contexto actual y observaciones independientes de presentación, pantalla y bisagra |

No convertir automáticamente píxeles a puntos, ni usar las dimensiones comerciales en pulgadas. La atribución de pantalla (`deviceDisplay`, `externalDisplay`, `mirrored`, `unknown`) es un dato suministrado, no una detección ya implementada. Usar `unknown` cuando la fuente no permita establecerla.

## Procedencia y vigencia

Cada muestra observada lleva `EvidenceMetadata`: origen system/simulator/synthetic/unknown, escena, ventana, generación, secuencia y vigencia current/historical. Las identidades deben ser locales y efímeras; no se generan ni persisten identificadores personales. El origen lo proporciona el observador o el ensayo; el núcleo no autentica hardware.

La generación debe cambiar al reasociar la ventana a otra pantalla o jerarquía. La secuencia aumenta dentro de una sesión y no es una fecha ni una garantía de simultaneidad. Dos muestras con distinta procedencia temporal no se presumen atómicas.

`current` solo tiene significado dentro del contexto/generación registrado. Una muestra puede conservarse como `historical`; el núcleo permite representar contextos distintos para que el futuro clasificador rechace combinaciones incompatibles sin perder trazabilidad. No hay expiración por tiempo ni normalización automática. El observador futuro será responsable de marcar historial al suspenderse/desmontarse; el clasificador deberá comprobar ámbito y vigencia, no confiar solo en el último valor.

## Ausencia de datos

`Observation<Value>` separa `observed(value, metadata:)` de `missing(reason)`:

- `apiUnavailable`: no se puede usar la API en este sistema.
- `awaitingSample`: todavía no se ha recibido una muestra.
- `observationSuspended`: observación detenida/deshabilitada.
- `unavailableInContext`: actualización sin valor; no presupone causa física.

Los estados missing corresponden al contexto actual del snapshot; no son eventos históricos con metadatos. Si más adelante se necesita un registro de callbacks, se modelará aparte. Los estados de bisagra desconocidos o futuros se representarán como `HingeStatus.unknown`. La falta de ángulo no equivale a cero.

No se añade `isDuo`, clasificador, transición automática, perfil dimensional ni selección de vistas en esta etapa.

## Verificación reproducible

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
