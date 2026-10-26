# FoldContextKit

Proyecto de paquete Swift independiente para observar capacidades de plegado y contexto de presentación, y evaluar evidencias de forma explicable. Cada aplicación conserva el control de su diseño, navegación y datos.

## Estado real — 26 de octubre de 2026

Etapa 3: paquete/producto/módulo `FoldContextKit`, Swift tools 6.4, sin dependencias externas. Núcleo de evidencias inmutables Sendable sin imports de UI, contratos de unidades/procedencia/vigencia y target Swift Testing. Retirada la plantilla `hello()`.

Mínimo iOS/iPadOS 26; bisagra solo desde 27.1 con disponibilidad explícita. macOS 26 sirve para el núcleo y pruebas locales. Clasificador puro con política explícita de observación o evaluación sintética. No hay observadores funcionales, perfiles de producción ni interfaz de diagnóstico todavía. No hay publicación remota ni licencia seleccionada.

Las firmas SwiftUI/UIKit compilan con BuildProject de Xcode, SDK iOS Simulator 27.1 y deployment target 26.0. Pasan los 29 casos de contratos y clasificación en Xcode. Esto no valida hardware ni ejecución sobre iOS 26. Véase [Contracts](Documentation/Contracts.md).

## Objetivo y alcance

- Un paquete instalable mediante Swift Package Manager, con integración SwiftUI y UIKit, sin dependencias externas previstas.
- Evidencias tipadas, clasificación pura y contexto propio de cada ventana/escena.
- Concurrencia de Swift; sin Combine, APIs privadas, permisos ajenos al objetivo, telemetría, servicios remotos ni identificadores personales.
- Pruebas con Swift Testing y, posteriormente, una app mínima de diagnóstico.

Es independiente de SongBook/Lyrio: no usa su repositorio, modelos, recursos ni lógica. No contempla Android, Flutter, React Native, Unity ni un sistema completo de layouts.

## Hipótesis y límites

La combinación de dimensiones compatibles y una bisagra observada podría apoyar una inferencia de modelo. Una transición de dimensiones dentro de la misma escena podría aportar contexto complementario; no es evidencia independiente de esas dimensiones. La hipótesis no está validada y no hay perfiles dimensionales autorizados para producción.

La disponibilidad de una API no acredita hardware. Un callback con bisagra acredita una capacidad en el contexto observado, sin certificar un modelo. Un valor ausente, la falta de callbacks o un observador deshabilitado no acreditan ausencia física. La documentación de UIKit contempla valores nulos al salir de la jerarquía que entrega datos. [UIHingeInteraction](https://developer.apple.com/documentation/uikit/uihingeinteraction).

Tamaño físico, píxeles, puntos de pantalla y puntos de ventana son magnitudes distintas. Rotación, multitarea, pantallas externas y Mirroring impiden identificar un modelo por tamaño de ventana. No se exigirán gestos de abrir/cerrar para usar la app ni se prometerán porcentajes de confianza, exclusividad futura o ausencia de regresiones. Apple recomienda adaptar la interfaz al espacio disponible. [Preparación para Duo](https://developer.apple.com/iphone-duo/prepare/).

## Validación

| Nivel | Estado |
| --- | --- |
| Documentación y declaraciones del SDK | Inspeccionadas; detalles y límites en Architecture |
| Compilación de firmas SwiftUI/UIKit | Correcta; adaptadores funcionales pendientes |
| Contratos mediante Swift Testing | 29 casos pasan; perfiles exclusivamente sintéticos |
| Importación local por SwiftPM | Consumidor independiente compilado y ejecutado |
| Observación en simulador | No realizada; solo compilación para ese destino |
| Observación en dispositivo físico | No realizada |
| Identificación de modelo y perfiles | Pendiente de evidencia; sin garantías |

Las pruebas con entradas controladas validarán reglas, nunca hardware. La utilidad de observar capacidades puede desarrollarse aunque la identificación siga siendo incierta; no se sustituye silenciosamente un objetivo por el otro.

Consulta la [lista de etapas verificables](Documentation/Checklist.md) y la [estructura y API conceptual](Documentation/Architecture.md). La publicación, creación del repositorio remoto, push y elección de licencia quedan fuera de esta fase.

## Integración local

En Xcode, añade este directorio como paquete local y selecciona el producto `FoldContextKit`. En el consumidor: `import FoldContextKit`. El directorio físico conserva el nombre AdapteDuoKit; el módulo público ya se llama FoldContextKit.

`Validation/LocalConsumer` contiene un paquete SwiftPM independiente que depende de la raíz mediante ruta relativa. Se verifica con `swift run --package-path Validation/LocalConsumer LocalConsumer`. Usa entradas sintéticas; no observa hardware.

Las reglas implementadas y sus límites se describen en [Classification](Documentation/Classification.md).
