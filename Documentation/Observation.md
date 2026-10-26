# Observación e integración — etapa 4

Actualizado: 2026-10-26. Integración compilada para iOS Simulator 27.1, mínimo iOS/iPadOS 26. Las pruebas de integración utilizan entradas controladas. Un ensayo adicional con RuntimeProbe observa el runtime del simulador; ninguno acredita plegado físico.

## UIKit

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

## SwiftUI

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

## Primera entrega, disponibilidad y ciclo de vida

- `start` proporciona un primer snapshot sin exigir movimiento. Sin ventana/escena activa se informa `observationSuspended`.
- Con escena activa: geometría inmediatamente disponible y bisagra `awaitingSample`, o `apiUnavailable` en sistemas anteriores a 27.1. `isHingeAPIAvailable` expresa disponibilidad del símbolo, no hardware.
- La interacción pública de UIKit documenta entrega inicial y posteriores actualizaciones. La biblioteca no impone un plazo ni inventa una muestra si no llega.
- Deshabilitar, desactivar/background o desconectar la escena retira la interacción y publica datos suspendidos. Reactivar vuelve a leer geometría y crea una nueva interacción, esperando una nueva muestra.
- Se filtran notificaciones por la escena asociada, no por un estado global de aplicación. Las notificaciones de ciclo de vida usan selector síncrono en MainActor para no retrasar invalidaciones; no se usa Combine.
- Cambiar ventana, escena, pantalla o jerarquía invalida muestras y aumenta la generación. También se invalida si cambian los píxeles nativos aunque el objeto UIScreen sea el mismo.
- `nil` recibido equivale a `unavailableInContext`; no demuestra ausencia de bisagra. Los estados de bisagra no reconocidos se conservan como unknown.

## Fuentes y unidades

| Campo | Fuente efectiva | Unidad |
| --- | --- | --- |
| presentationSize | UIWindow.bounds de la ventana que contiene la subvista de seguimiento | Puntos de ventana |
| nativeScreenSize | window.windowScene.screen.nativeBounds, resuelto de nuevo al refrescar | Píxeles nativos, sin rotar los ejes |
| hinge.angleRadians | UIHinge.angle | Radianes |
| metadata.origin | Compilación para simulador o sistema; inyección interna synthetic en tests | Procedencia, no prueba de modelo |

No se mide la vista SwiftUI como si fuera una pantalla. No se usa UIScreen.main, escala implícita, pulgadas ni perfiles de dimensiones. La atribución de pantalla se deja `unknown`: aún no existe una regla verificada que cubra pantalla externa y Mirroring. Esto bloquea la inferencia de modelo y mantiene la utilidad del contexto y la capacidad observada.

## Historial y entrega acotados

Historial: máximo 32 eventos por observador. Al consultarlo, las muestras se marcan historical sin modificar el snapshot actual. `discardedHistoryEvents` cuenta expulsiones del historial. Las identidades son UUID locales y efímeros propios de la sesión del observador; no se persisten ni correlacionan con identificadores personales.

SwiftUI: cola máxima de 32 eventos. Solo dos cambios consecutivos etiquetados hingeAngle pueden agruparse conservando el último; nunca se agrupan estados, disponibilidad, geometría o contexto. Dentro de la capacidad se conserva su orden. Si el consumidor no alcanza el ritmo y la cola se llena, se expulsan eventos antiguos y se entrega primero `overflow(droppedEvents:)`. No se garantiza retención ilimitada ni ausencia de pérdidas bajo desbordamiento. La señal permite al consumidor descartar cualquier inferencia de continuidad. UIKit no tiene esta cola diferida y entrega síncronamente cada cambio aceptado.

## Validación y límites materiales

38 casos Swift Testing pasan con el destino iPhone Duo Simulator 27.1 (29 anteriores y 9 nuevos), sin fallos ni omisiones. BuildProject verifica los adaptadores para iOS. Las pruebas comprueban:

- Inicio sin jerarquía y limpieza al parar/liberar.
- Primera entrega del coordinador y ausencia de entrega después de dismantleUIView.
- Cola SwiftUI desbordada, señal de pérdida y orden de cambios discretos.
- Dos UIWindow con estado independiente, puntos de ventana y píxeles de pantalla inyectados.
- Deshabilitación/reactivación, muestras iniciales síncronas y tardías, nil y API no disponible mediante driver controlado.
- Entrada/salida de foreground mediante señales de ciclo de vida inyectadas; ignorar señales de otra escena.
- Cambio de ventana, retirada/reinserción de jerarquía y cambio de dimensiones nativas.
- Invalidación histórica y deshabilitación desde dentro de un callback.

El ejecutor SwiftPM no tenía ninguna UIWindowScene conectada. Una prueba inicial que la exigía falló por esa condición; se separó la lectura de entorno y el driver de bisagra para probarlos con entradas explícitamente synthetic. No se presenta ese cambio como evidencia de hardware.

## Ensayo runtime con escena activa — 2026-10-26

App independiente [RuntimeProbe](../Validation/RuntimeProbe/README.md), consumidor local del paquete. Compilada mediante `xcodebuild` (SDK Simulator 27.1, mínimo iOS 26); el workspace del asistente solo ofrece el esquema del paquete, verificado además con BuildProject. Ejecutada en iPhone Duo Simulator 27.1. No se inyectaron muestras ni se accionó el plegado.

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
