# Etapas verificables

Actualizado: 2026-10-26. Una casilla completada acredita solo el resultado descrito. Las pruebas sintéticas no acreditan hardware.

## Etapa 1 — Investigación y propuesta

- [x] Inspeccionar únicamente el paquete actual e instrucciones locales; registrar plantilla existente.
- [x] Consultar DocumentationSearch y registrar su limitación de cobertura.
- [x] Contrastar todas las referencias solicitadas con fuentes oficiales.
- [x] Localizar firmas, disponibilidad y semántica pública en SDK iOS 27.1.
- [x] Documentar nil, entrega inicial UIKit y pendientes de entrega SwiftUI.
- [x] Separar capacidad, modelo inferido y presentación por ventana.
- [x] Crear README, arquitectura, API conceptual y estas etapas.
- [x] Declarar falta de perfiles validados y de garantías de identificación.

Criterio de cierre documental: fuentes trazables y límites explícitos. No implica que haya un detector, tests ni integración compilada. El modelo sigue incierto; la observación de capacidades tiene una base pública verificable.

## Etapa 2 — Contratos y paquete mínimo

- [x] Acordar plataformas mínimas y compatibilidad con sistemas anteriores a 27.1.
- [x] Renombrar paquete/producto/target a FoldContextKit y retirar la plantilla.
- [x] Comprobar firmas y disponibilidad con compilación mínima SwiftUI/UIKit usando BuildProject de Xcode.
- [x] Definir unidades, procedencia, vigencia y estados de datos ausentes.
- [x] Crear núcleo sin UI y target Swift Testing; validar importación local por SwiftPM.

Criterio: consumidor mínimo compila, API pequeña y sin dependencia de otra app.

Validado: BuildProject para SDK iOS Simulator 27.1 con mínimo 26.0, tres tests Swift Testing en Mac y consumidor SwiftPM local compilado/ejecutado. No se ha ejecutado en iOS 26 ni observado bisagra. Detalles: [Contracts](Contracts.md).

## Etapa 3 — Reglas puras

- [ ] Implementar clasificación con política explícita, sin perfiles de producción.
- [ ] Probar API disponible sin muestra, nil, suspensión y estados desconocidos.
- [ ] Probar bisagra sin dimensiones: capacidad observada con modelo desconocido.
- [ ] Probar perfiles exclusivamente sintéticos: dimensión sola, combinación y contradicciones.
- [ ] Probar rotación, unidades incompatibles y transición dependiente de dimensiones.
- [ ] Probar evidencia caducada, cambio de ventana/escena y ausencia de transición inicial.
- [ ] Verificar que fuentes incompatibles o atribución desconocida bloquean inferencia.

Criterio: Swift Testing pasa con motivos deterministas; resultados etiquetados como validación de reglas, no de hardware.

## Etapa 4 — Observación e integración

- [ ] Implementar observación UIKit por ventana con propiedad y cancelación claras.
- [ ] Implementar integración SwiftUI y verificar primera entrega y desmontaje.
- [ ] Comprobar deshabilitación, reactivación, cambios de jerarquía y foreground/background.
- [ ] Verificar unidades y fuentes de cada medida de presentación.
- [ ] Comprobar que varias ventanas no sobrescriben snapshots entre sí.
- [ ] Acotar historial y buffering; preservar cambios discretos importantes.

Criterio: integración compilada y comportamiento documentado sin exigir abrir/cerrar.

## Etapa 5 — App mínima de diagnóstico

- [ ] Mostrar datos observados con fuente, unidad, ámbito y vigencia.
- [ ] Mostrar disponibilidad de API separada de recepción de datos de bisagra.
- [ ] Mostrar capacidad, clasificación, evidencias y limitaciones.
- [ ] Mostrar eventos y cambios de contexto de la escena/ventana.
- [ ] Etiquetar inequívocamente modo sintético, simulador y hardware físico.

Criterio: ejemplo local y neutral, sin navegación automática, analítica ni funciones ajenas al paquete.

## Etapa 6 — Matriz de observación

Ejecutar por separado en simulador y dispositivos físicos; registrar versiones de SO/SDK y procedencia. No se ha ejecutado ninguna fila todavía.

| Escenario | Reglas unitarias | Simulador | Físico |
| --- | --- | --- | --- |
| Arranque abierto y cerrado sin transición | Pendiente | Pendiente | Pendiente |
| Apertura/cierre y cambios parciales de ángulo | Pendiente | Pendiente | Pendiente |
| Rotación y resize sin plegado | Pendiente | Pendiente | Pendiente |
| Multitarea y varias ventanas/escenas | Pendiente | Pendiente | Pendiente |
| iPad mini y otros dispositivos sin bisagra | Pendiente | Pendiente | Pendiente |
| Pantalla externa y cambio de pantalla | Pendiente | Pendiente | Pendiente |
| iPhone Mirroring y cambio de tamaño | Pendiente | Pendiente | Pendiente |
| Deshabilitar/reactivar observador; retirar vista | Pendiente | Pendiente | Pendiente |
| Background y reconexión de escena | Pendiente | Pendiente | Pendiente |

Si un escenario no está disponible en una plataforma de prueba, registrar «no aplicable/no disponible» con motivo, sin marcarlo probado.

Registro futuro por caso: identificador local del ensayo, entorno, versión, escenario, condición conocida por el operador, eventos recibidos, origen/unidades, resultado esperado, resultado obtenido, motivos, falso positivo/falso negativo/información insuficiente y pasos de reproducción. No recoger identificadores personales. Actualmente no hay casos medidos ni tasas calculadas; no afirmar cero errores.

## Etapa 7 — Decisión sobre inferencia

- [ ] Obtener evidencia suficiente para cada dimensión y su API de medición.
- [ ] Definir tolerancias justificadas y contexto admisible; no inferir puntos desde pulgadas.
- [ ] Contrastar controles negativos, escalas, rotación, multitarea, Mirroring y pantallas externas.
- [ ] Registrar falsos positivos, negativos y resultados insuficientes, sin porcentajes inventados.
- [ ] Decidir explícitamente si procede habilitar algún perfil experimental o mantener modelo desconocido.

Criterio: informe reproducible y límites publicados; nunca garantía de exclusividad. Si no hay evidencia suficiente, mantener bloqueada la inferencia y explicar qué capacidades sí aporta el paquete.

## Etapa 8 — Distribución futura

- [ ] Revisar API pública, documentación y ejemplo; comprobar instalación SwiftPM.
- [ ] Elegir licencia únicamente tras instrucción posterior.
- [ ] Crear repositorio remoto, publicar versiones o hacer push únicamente tras instrucción posterior.

No ejecutar estas acciones durante la fase documental.
