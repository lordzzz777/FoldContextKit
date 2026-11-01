# Etapas verificables

## Validación sin dispositivo físico — 1 de noviembre

**Entrega solicitada completada en simulador.** La matriz inferior conserva escenarios generales de investigación fuera de esta entrega.

- [x] Corregir perfil interior 2007 × 2853 limitado al origen simulator; mantener perfil previo.
- [x] Pruebas de regresión para postura, rotación y separación de perfiles de sistema/simulador.
- [x] 28 funciones de tests Mac y 37 funciones / 53 casos iOS, sin fallos ni omisiones; app compilada.
- [x] Observar arranque abierto e inferencia interior con fullyOpen π en Duo Simulator 27.1.
- [x] Observar dos escenas independientes lado a lado creadas mediante FoldNewWindowButton.
- [x] Observar transición a partiallyOpen, inferencia interior y división activa en ambas escenas.
- [x] Arranque directo entreabierto sin gesto previo, rotación interior y regreso al exterior al cerrar.
- [x] Transición a 90°, arranque directo y salida: partiallyOpen a π/2 y fullyOpen a π observados en runtime, sin entradas sintéticas. Option + clic físico en el control Partially Open permite obtener 90° en este entorno. [Evidencia](../Validation/RuntimeProbe/Results/2026-11-01-completion-90-validation.txt).
- [x] Inspeccionar controles nativos: Split View lado a lado, sin tres círculos observados; se documenta la limitación de plataforma.
- [x] Observar rechazo contextual de nueva escena en vertical y éxito tras rotar a horizontal, sin añadir restricciones propias por orientación.

No se requiere dispositivo físico para esta entrega. Los ensayos físicos quedan fuera del alcance disponible. Detalles y logs en el estado vigente de la ficha técnica.

## Activación de ventanas en FoldContextKit — 1 de noviembre

- [x] API UIKit de solicitud explícita con escena de origen y errores del sistema.
- [x] Acción nativa y botón SwiftUI reutilizable, sin puerta basada en ángulo o modelo.
- [x] Integrar RuntimeProbe y documentar configuración/enrutamiento del consumidor.
- [x] Compilar paquete/app y superar 47 casos en simulador, incluidos 2 nuevos de activación.
- [x] Observar creación de dos escenas independientes con el adaptador nativo: lado a lado en Duo Simulator 27.1, validación del 1 de noviembre.

Las condiciones de apertura basadas en bisagra de la sección del 31 de octubre quedan sustituidas por la acción nativa anterior.

## Segunda ventana — 31 de octubre

- [x] Habilitar «Abrir segunda ventana» con bisagra abierta/entreabierta vigente y soporte multiwindow del sistema, conservando estado por escena.
- [x] Compilar e instalar RuntimeProbe; observar botón deshabilitado con bisagra cerrada.
- [ ] Observar dos escenas independientes abiertas mediante el botón; la colocación depende de iOS.

## Validación actual — 30 de octubre

- [x] Compilar paquete y targets de pruebas para iOS Simulator con BuildProject.
- [x] Compilar RuntimeProbe para simulador.
- [x] Ejecutar 25 tests Swift Testing del núcleo en Mac, incluidos siete nuevos de inferencia y presentación.
- [x] Compilar y ejecutar consumidor SwiftPM independiente.
- [x] Ejecutar tests iOS en Duo Simulator 27.1: 45 casos superados, sin fallos ni omisiones (32 funciones, incluidas parametrizadas).
- [x] Observar app con escena activa, entrega inicial de bisagra, deshabilitación/reactivación y desmontaje/remontaje automático SwiftUI en Duo Simulator.
- [x] Observar background/foreground de esta revisión: salida a SpringBoard y retorno en el mismo proceso; suspensión, espera y nueva muestra de bisagra registradas.

Las marcas anteriores de «sin tests» corresponden a instrucciones históricas, sustituidas por la autorización actual. No confundir tests de reglas en Mac con observación de hardware o de escenas iOS. Evidencias y alcance en [ficha técnica](FichaTecnica.md#validacion-30-octubre).

## Contexto explícito de pantalla

- [x] Exponer estados diferenciados de pantalla externa, receptor reflejado, captura genérica y aplicación no atribuida.
- [x] Bloquear inferencia con captura desconocida además de activa.
- [x] Conservar modelo inferido y contexto físico no certificado como ejes separados.
- [ ] Identificación específica universal de iPhone Mirroring y pantallas externas interactivas: no resuelta por las señales públicas consultadas.

## Regiones del sistema y distribución libre

- [x] Leer safe area y regiones activas UIKit division/occlusion con fuente, unidades y vigencia.
- [x] Priorizar división del sistema y distinguir el fallback lógico.
- [x] Exponer áreas de contenido sin oclusiones observadas, con límite y truncamiento explícitos.
- [x] Observar captura de escena y bloquear inferencia mientras esté activa.
- [x] Mantener límite explícito: captura no identifica iPhone Mirroring; windowApplication no certifica pantalla integrada.
- [x] Incorporar licencia libre MIT autorizada.
- [ ] Distinguir de forma universal Mirroring y pantallas externas interactivas: sin contrato público suficiente en la integración actual.
- [x] Compilación y reglas de regiones/captura validadas; observación runtime se registra en la validación actual.

## Presentación exterior e interior

- [x] Diferenciar panel exterior e interior del Duo inferido.
- [x] Exponer interior extendido, dividido horizontal/vertical y elección sin especificar.
- [x] Mantener postura de bisagra y distribución de la app separadas.
- [x] Proporcionar regiones lógicas en puntos con contexto, origen y vigencia de ventana.
- [x] Documentar integración UIKit/SwiftUI en README, sin crear documentación adicional.
- [x] Compilación y reglas de presentación validadas con entradas controladas; no acredita panel interior real.

## Implementación de inferencia solicitada

- [x] Incorporar política duo predeterminada con dimensiones nativas y bisagra vigente.
- [x] Separar candidato dimensional, Duo inferido e información insuficiente, conservando origen.
- [x] Conectar observador, app y ejemplos UIKit/SwiftUI del README.
- [x] Mantener transición opcional, contexto por ventana y rechazo de fuentes incompatibles.
- [x] Inferencia validada con entradas controladas en la suite actual; no acredita exclusividad del modelo.

Las etapas inferiores son el registro histórico. La decisión anterior de no habilitar inferencia queda sustituida por esta implementación, sin convertir sus resultados previos en validación del código nuevo.

Consolidado: 2026-10-29. Una casilla completada acredita solo el resultado descrito. Las pruebas sintéticas no acreditan hardware.

Alcance acordado: no hay dispositivo físico disponible. La versión actual se valida con documentación, SDK, pruebas controladas y simulador. Los ensayos físicos quedan fuera del alcance disponible y no bloquean esta entrega; no se consideran superados. Los ensayos del simulador aún no ejecutados siguen pendientes.

Estado de mantenimiento del 29 de octubre: compilación correcta con targets de pruebas y cero advertencias en Xcode. La primera ejecución obtuvo 37/38; se corrigió el caso restante, pero la segunda ejecución no devolvió resultado. Los 38 casos históricos no acreditan la revisión actual. Por petición del usuario, esta consolidación no añade ni ejecuta tests o comprobaciones; los pendientes permanecen registrados, sin programar nuevas ejecuciones.

Documentación del proyecto: [README](../README.md) y [ficha técnica](FichaTecnica.md). Los enlaces de las etapas llevan a sus apartados correspondientes.

## Etapa 1 — Investigación y propuesta

- [x] Inspeccionar únicamente el paquete actual e instrucciones locales; registrar plantilla existente.
- [x] Consultar DocumentationSearch y registrar su limitación de cobertura.
- [x] Contrastar todas las referencias solicitadas con fuentes oficiales.
- [x] Localizar firmas, disponibilidad y semántica pública en SDK iOS 27.1.
- [x] Documentar nil, entrega inicial UIKit y pendientes de entrega SwiftUI.
- [x] Separar capacidad, modelo inferido y presentación por ventana.
- [x] Documentar objetivo, arquitectura, API conceptual y etapas (reunidos ahora en README, ficha técnica y checklist).
- [x] Declarar falta de perfiles validados y de garantías de identificación.

Criterio de cierre documental: fuentes trazables y límites explícitos. No implica que haya un detector, tests ni integración compilada. El modelo sigue incierto; la observación de capacidades tiene una base pública verificable.

## Etapa 2 — Contratos y paquete mínimo

- [x] Acordar plataformas mínimas y compatibilidad con sistemas anteriores a 27.1.
- [x] Renombrar paquete/producto/target a FoldContextKit y retirar la plantilla.
- [x] Comprobar firmas y disponibilidad con compilación mínima SwiftUI/UIKit usando BuildProject de Xcode.
- [x] Definir unidades, procedencia, vigencia y estados de datos ausentes.
- [x] Crear núcleo sin UI y target Swift Testing; validar importación local por SwiftPM.

Criterio: consumidor mínimo compila, API pequeña y sin dependencia de otra app.

Validado: BuildProject para SDK iOS Simulator 27.1 con mínimo 26.0, tres tests Swift Testing en Mac y consumidor SwiftPM local compilado/ejecutado. No se ha ejecutado en iOS 26 ni observado bisagra. Detalles: [Contracts](FichaTecnica.md#contratos).

## Etapa 3 — Reglas puras

- [x] Implementar clasificación con política explícita, sin perfiles de producción.
- [x] Probar API disponible sin muestra, nil, suspensión y estados desconocidos.
- [x] Probar bisagra sin dimensiones: capacidad observada con modelo desconocido.
- [x] Probar perfiles exclusivamente sintéticos: dimensión sola, combinación y contradicciones.
- [x] Probar rotación, unidades incompatibles y transición dependiente de dimensiones.
- [x] Probar evidencia caducada, cambio de ventana/escena y ausencia de transición inicial.
- [x] Verificar que fuentes incompatibles o atribución desconocida bloquean inferencia.

Criterio: Swift Testing pasa con motivos deterministas; resultados etiquetados como validación de reglas, no de hardware.

Validación de etapa 3: 29 casos Swift Testing superados (incluidos 3 de contratos), sin observación de hardware. Véase [Classification](FichaTecnica.md#clasificacion).

## Etapa 4 — Observación e integración

- [x] Implementar observación UIKit por ventana con propiedad y cancelación claras.
- [x] Implementar integración SwiftUI; probar primera entrega del coordinador y desmontaje explícito.
- [x] Comprobar deshabilitación, reactivación, jerarquía y señales foreground/background con entradas controladas.
- [x] Verificar unidades y fuentes en código y pruebas controladas.
- [x] Comprobar que dos ventanas no sobrescriben sus snapshots.
- [x] Acotar historial y buffering; conservar cambios discretos dentro de capacidad y notificar desbordamiento.
- [x] Observar primera entrega de bisagra y ciclo de vida del runtime en una app con UIWindowScene activa, incluido montaje SwiftUI automático — iPhone Duo Simulator 27.1; hardware físico pendiente.

Criterio de implementación cumplido: integración compilada y comportamiento documentado sin exigir abrir/cerrar. En la revisión histórica de esta etapa pasaron 38 casos Swift Testing con entradas controladas. Además, RuntimeProbe recibió muestras del runtime en una escena activa y verificó montaje/desmontaje SwiftUI, deshabilitación/reactivación y background/foreground en iPhone Duo Simulator 27.1. El ejecutor SwiftPM por sí solo no proporciona esa escena. Registro y límites en [Observation](FichaTecnica.md#observacion): no acredita condiciones físicas, exclusividad del modelo ni todas las combinaciones de presentación.

## Etapa 5 — App mínima de diagnóstico

- [x] Mostrar datos observados con fuente, unidad, ámbito y vigencia.
- [x] Mostrar disponibilidad de API separada de recepción de datos de bisagra.
- [x] Mostrar capacidad, clasificación, evidencias y limitaciones.
- [x] Mostrar eventos y cambios de contexto de la escena/ventana.
- [x] Etiquetar modo sintético y simulador; fuera del simulador indicar sistema sin certificar hardware físico.

Criterio: ejemplo local y neutral, sin navegación automática, analítica ni funciones ajenas al paquete.

Implementación compilada. Pantalla de observación comprobada en simulador: medidas, metadatos, clasificación e historial legibles. Comprobados también modo sintético, retorno a datos simulator y controles de suspensión/desmontaje. Hardware físico y otros entornos siguen pendientes. Detalles en [DiagnosticApp](FichaTecnica.md#diagnostico).

## Etapa 6 — Matriz de observación

Ejecutar por separado en simulador y dispositivos físicos; registrar versiones de SO/SDK y procedencia. RuntimeProbe cubre parte del ciclo de vida en simulador; las demás condiciones siguen pendientes.

| Escenario | Reglas unitarias | Simulador | Físico |
| --- | --- | --- | --- |
| Arranque abierto y cerrado sin transición | Pendiente | Pendiente | Pendiente |
| Apertura/cierre y cambios parciales de ángulo | Pendiente | Pendiente | Pendiente |
| Arranque en modo libro, sin transición previa | Pendiente | Pendiente | Pendiente |
| Transición a modo libro y salida de esa postura | Pendiente | Pendiente | Pendiente |
| Arranque abierto a 90°, sin transición previa | Entradas controladas a π/2 | Observado 1/11: partiallyOpen, π/2, interior | Fuera del alcance |
| Transición a 90° y salida de esa postura | Entradas controladas | Observado 1/11: cerrado → π/2; π/2 → fullyOpen π | Fuera del alcance |
| Rotación y resize sin plegado | Reglas sintéticas | Intento de rotación: app permaneció vertical; resize pendiente | Pendiente |
| Multitarea y varias ventanas/escenas | Pendiente | Pendiente | Pendiente |
| iPad mini y otros dispositivos sin bisagra | Pendiente | Pendiente | Pendiente |
| Pantalla externa y cambio de pantalla | Pendiente | Pendiente | Pendiente |
| iPhone Mirroring y cambio de tamaño | Pendiente | Pendiente | Pendiente |
| Deshabilitar/reactivar observador; retirar vista | Entradas controladas | Observado en RuntimeProbe 27.1 | Pendiente |
| Background y reconexión de escena | Señales controladas | Background/foreground observado; reconexión pendiente | Pendiente |

Si un escenario no está disponible en una plataforma de prueba, registrar «no aplicable/no disponible» con motivo, sin marcarlo probado.

### Protocolo de observación: modo libro y apertura a 90°

- **Modo libro:** colocar el dispositivo parcialmente abierto en postura de lectura. Registrar la postura conocida por el operador y el ángulo comunicado, sin fijar un ángulo universal para «libro». Dos páginas o regiones visuales no implican dos pantallas, ventanas o escenas independientes: registrar lo que realmente expongan las APIs públicas.
- **Apertura a 90°:** registrar por separado el ángulo objetivo del ensayo (90°, π/2 radianes) y el valor recibido. No exigir igualdad exacta ni establecer tolerancias sin evidencia. Un dato ausente o un estado unknown se conserva como tal.
- En cada postura, arrancar directamente sin una transición previa y comprobar la primera entrega, incluidos estados awaitingSample y unavailableInContext. No exigir abrir/cerrar para obtener información.
- Después, entrar y salir de cada postura durante la misma sesión. Registrar estado y ángulo de bisagra, fuente, origen, secuencia, vigencia, puntos de ventana, píxeles nativos y contexto de escena/ventana. Anotar si las dimensiones cambian o permanecen iguales; la ausencia de resize no demuestra ausencia de plegado.
- Comprobar ambas orientaciones cuando el entorno lo permita. No deducir postura, cantidad de pantallas ni identidad del modelo solo a partir del ángulo o las dimensiones.
- Separar resultados de entradas sintéticas, runtime del simulador y dispositivo físico. El fixture actual de 1 radián no valida modo libro ni 90°. Si el simulador no permite configurar una postura, registrar esa limitación y mantener pendiente la observación física.

Este protocolo procede de la investigación inicial. El estado vigente de esta entrega y la política duo implementada se describen al principio de este documento y de la ficha técnica; no se deducen de las casillas históricas.


Registro futuro por caso: identificador local del ensayo, entorno, versión, escenario, condición conocida por el operador, eventos recibidos, origen/unidades, resultado esperado, resultado obtenido, motivos, falso positivo/falso negativo/información insuficiente y pasos de reproducción. No recoger identificadores personales. El ensayo RuntimeProbe registra observaciones de integración, no tasas de identificación. No hay tasas calculadas; no afirmar cero errores.

## Etapa 7 — Decisión sobre inferencia

- [x] Inventariar la evidencia dimensional disponible y verificar su API: especificaciones y contrato de nativeBounds contrastados, lectura exterior en simulador. Alcance y límites en [DimensionEvidence](FichaTecnica.md#dimensiones).
- [x] Registrar lectura interior real: Duo Simulator 27.1, fullyOpen π rad, UIWindow 951 × 669 puntos, nativeBounds 2007 × 2853 píxeles. Discrepa del perfil interior; no modifica tolerancias ni acredita hardware.
- [x] Definir tolerancias y contexto de la versión sin perfiles: ninguna tolerancia de identificación habilitada; comparación exacta solo para fixtures, vigencia/contexto/origen explícitos. Véase [SimulatorControls](FichaTecnica.md#controles).
- [x] Contrastar control negativo iPhone 17 iOS 27.0 y rotación de su ventana; registrar que Duo no rotó su interfaz.
- [ ] Observar scale/nativeScale y cambios efectivos de escala. Lectura manual implementada y compilada; ensayo runtime bloqueado por conexión al simulador.
- [ ] Observar múltiples escenas y multitarea. Solicitud de otra ventana implementada y compilada; instalación/ensayo iPad no completados.
- [ ] Observar una ventana de la app en pantalla externa. El inventario de superficies no acredita presentación efectiva.
- [x] Evaluar disponibilidad de iPhone Mirroring: no disponible en el alcance sin hardware físico; no ejecutado ni declarado superado.

Resultados, intentos fallidos y límites: [SimulatorControls](FichaTecnica.md#controles).
- [x] Registrar abstenciones observadas y declarar falsos positivos/negativos de identificación no evaluables sin perfil; sin porcentajes inventados. Véanse [SimulatorControls](FichaTecnica.md#controles) e [InferenceDecision](FichaTecnica.md#inferencia).
- [x] Decidir explícitamente si procede habilitar algún perfil experimental o mantener modelo desconocido: mantener desconocido; no habilitar perfiles de hardware.

Criterio: informe reproducible y límites publicados; nunca garantía de exclusividad. Si no hay evidencia suficiente, mantener bloqueada la inferencia y explicar qué capacidades sí aporta el paquete.

Decisión registrada el 2026-10-27 en [InferenceDecision](FichaTecnica.md#inferencia). La evaluación de habilitación está resuelta con resultado negativo; la etapa experimental no está completa. Se registran abstenciones observadas, pero siguen pendientes controles y medición de falsos positivos/negativos físicos. No se fijan tolerancias sin evidencia.

## Etapa 8 — Distribución futura

- [ ] Revisar API pública, documentación y ejemplo; comprobar instalación SwiftPM.
- [x] Elegir licencia: MIT, tras autorización del usuario para licencia libre.
- [ ] Crear repositorio remoto, publicar versiones o hacer push únicamente tras instrucción posterior.

No ejecutar estas acciones durante la fase documental.
