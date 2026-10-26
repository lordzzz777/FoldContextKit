# RuntimeProbe

App local de validación de la etapa 4. Consume el producto SwiftPM `FoldContextKit` desde `../..`; no forma parte del producto distribuido ni sustituye la app de diagnóstico de la etapa 5.

Abrir `RuntimeProbe.xcodeproj`, seleccionar el esquema `RuntimeProbe` y un simulador iOS 27.1. Ejecutar sin abrir/cerrar el dispositivo simulado. El mínimo es iOS 26, pero esta versión anterior todavía necesita un ensayo independiente.

1. Observar el primer evento y su fuente. `awaitingSample` no demuestra ausencia de hardware; un callback con `nil` se representa como `unavailableInContext`.
2. Pulsar **Audit active scene**: registrar escenas conectadas, estado de activación y número de `UIHingeInteraction` en sus ventanas.
3. Desactivar **Enable observation**: comprobar suspensión y cero interacciones. Reactivar y registrar si llega una nueva muestra.
4. Desactivar **Mount observer**: auditar la retirada de la interacción y comprobar que no crece el contador. Volver a montar y registrar una nueva entrega. El árbol SwiftUI ejecuta el desmontaje; el ensayo no llama manualmente a `dismantleUIView`.
5. Enviar la app al fondo y volver a abrirla. Registrar suspensión, reactivación y las muestras posteriores.

La consola usa el prefijo `FOLD_PROBE` y tiempo monotónico. La auditoría enumera escenas únicamente para el diagnóstico; no suministra datos al observador. No inyecta muestras ni dimensiones. Puntos, píxeles nativos y radianes conservan fuentes distintas. El origen de las muestras sigue siendo `simulator` en el simulador.

La pantalla muestra el último evento y un contador; la consola contiene la secuencia. La auditoría es una instantánea solicitada por el operador, no una medición continua. El mensaje de advertencia de esta app está destinado al ensayo en simulador; para probar hardware físico debe adaptarse esa etiqueta y registrar el entorno por separado.

Resultados y límites: [Observation](../../Documentation/Observation.md). Un build satisfactorio no acredita ejecución ni entrega de bisagra.
