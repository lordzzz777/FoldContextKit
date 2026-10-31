import SwiftUI
import UIKit
import FoldContextKit

@main
struct RuntimeProbeApp: App {
    var body: some Scene {
        WindowGroup(id: "diagnostic") { DiagnosticView() }
    }
}

private struct DiagnosticEvent: Identifiable {
    let id: Int
    let text: String
}

private struct DiagnosticView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var synthetic = false
    @State private var mounted = true
    @State private var enabled = true
    @State private var snapshot: FoldEvidence?
    @State private var history: [DiagnosticEvent] = []
    @State private var serial = 0
    @State private var omitted = 0
    @State private var lost = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("FoldContextKit").font(.largeTitle)
                Text("Diagnóstico local").font(.title2)
                Text("Validación en hardware físico: pendiente.").font(.caption)
                ModeSection(synthetic: $synthetic)
                WindowInspectionSection(canOpenSecondWindow: canOpenSecondWindow)
                Toggle("Montar observador", isOn: $mounted).disabled(synthetic)
                Toggle("Habilitar observación", isOn: $enabled).disabled(synthetic)
                Text("Fase de esta escena: \(String(describing: scenePhase))")
                AvailabilitySection(synthetic: synthetic, mounted: mounted, enabled: enabled)
                if let snapshot {
                    EvidenceSection(evidence: snapshot)
                    AssessmentSection(assessment: FoldClassifier.evaluate(evidence: snapshot, policy: .duo))
                } else {
                    Text("Sin snapshot vigente. Esperando la observación de esta ventana.")
                }
                Text("Duo se infiere combinando píxeles nativos compatibles y bisagra vigente. nil no demuestra ausencia física. Las transiciones dimensionales son complementarias.")
                    .font(.callout)
                HistorySection(events: history, omitted: omitted, lost: lost)
            }
            .padding()
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background {
            // Stable root outside scrolling content. Each WindowGroup owns its state.
            if mounted && !synthetic {
                Color.clear.onFoldContextChange(isEnabled: enabled) { event in
                    guard !synthetic, mounted else { return }
                    receive(event)
                }
            }
        }
        .onChange(of: synthetic) { _, value in
            snapshot = nil
            history.removeAll()
            omitted = 0
            lost = 0
            record(value ? "Modo sintético: datos inventados; historial anterior descartado." : "Observación del entorno: esperando nuevos datos.")
            if value { snapshot = fixture() }
        }
        .onChange(of: mounted) { _, value in
            if !value { snapshot = nil }
            record(value ? "Montaje solicitado" : "Desmontaje solicitado; snapshot retirado")
        }
        .onChange(of: enabled) { _, value in
            if !value { snapshot = nil }
            record(value ? "Reactivación solicitada" : "Suspensión solicitada")
        }
        .onChange(of: scenePhase, initial: true) { _, value in
            record("Fase de escena: \(value)")
        }
    }

    private var canOpenSecondWindow: Bool {
        guard !synthetic, mounted, enabled, scenePhase == .active,
              let snapshot,
              case let .observed(hinge, metadata) = snapshot.hinge,
              metadata.context == snapshot.context,
              metadata.validity == .current,
              metadata.origin == .system || metadata.origin == .simulator else {
            return false
        }
        return hinge.status == .fullyOpen || hinge.status == .partiallyOpen
    }

    private func receive(_ event: FoldObservationEvent) {
        // Opt-in local diagnostics let simulator validation inspect both displays
        // without relying on which display the screenshot tool captures.
        if ProcessInfo.processInfo.environment["FOLD_CONTEXT_DIAGNOSTICS"] == "1" {
            var line = "FOLD_CONTEXT_EVENT \(Date().ISO8601Format()) \(String(reflecting: event))"
            if case let .snapshot(value, _) = event {
                line += " assessment=\(String(reflecting: FoldClassifier.evaluate(evidence: value, policy: .duo)))"
            }
            FileHandle.standardOutput.write(Data((line + "\n").utf8))
        }
        switch event {
        case let .overflow(count):
            lost += count
            snapshot = nil
            record("Desbordamiento: \(count) eventos perdidos; no asumir continuidad")
        case let .snapshot(value, change):
            snapshot = value
            record("\(change) · escena \(value.context.sceneID) · ventana \(value.context.windowID) · generación \(value.context.generation)\nBisagra: \(hingeDescription(value.hinge))")
        }
    }

    private func record(_ message: String) {
        serial += 1
        if history.count == 32 {
            history.removeFirst()
            omitted += 1
        }
        history.append(DiagnosticEvent(id: serial, text: message))
    }

    private func fixture() -> FoldEvidence {
        let context = ObservationContext(sceneID: "synthetic-scene", windowID: "synthetic-window", generation: 1)
        let metadata = EvidenceMetadata(context: context, sequence: 1, origin: .synthetic, validity: .current)
        // Arbitrary values for presentation only; never a device dimension profile.
        let points = PointSize(width: 300, height: 500)
        let pixels = PixelSize(width: 600, height: 1000)
        let hinge = HingeSample(status: .partiallyOpen, angleRadians: 1, source: .uiHingeInteraction)
        return FoldEvidence(context: context,
            presentationSize: points.map { .observed(PresentationSize(points: $0, source: .uiWindowBounds), metadata: metadata) } ?? .missing(.unavailableInContext),
            nativeScreenSize: pixels.map { .observed(NativeScreenSize(pixels: $0, attribution: .unknown), metadata: metadata) } ?? .missing(.unavailableInContext),
            hinge: hinge.map { .observed($0, metadata: metadata) } ?? .missing(.unavailableInContext))
    }
}

private struct ModeSection: View {
    @Binding var synthetic: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Ejemplo sintético", isOn: $synthetic)
            if synthetic {
                Text("SINTÉTICO — valores inventados. Fuentes simuladas; ninguna lectura de hardware.").bold()
            } else {
                #if targetEnvironment(simulator)
                Text("SIMULADOR — datos del runtime, no evidencia física.").bold()
                #else
                Text("SISTEMA — ejecución fuera del simulador. No certifica hardware físico ni modelo; comprobar el entorno de ejecución.").bold()
                #endif
            }
        }
    }
}

private struct AvailabilitySection: View {
    let synthetic: Bool
    let mounted: Bool
    let enabled: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Disponibilidad y recepción").font(.headline)
            if #available(iOS 27.1, *) {
                Text("API UIHingeInteraction: disponible en este sistema.")
            } else {
                Text("API UIHingeInteraction: no disponible; requiere iOS 27.1.")
            }
            Text(synthetic ? "Observador real retirado. Muestra sintética." : !mounted ? "Observador desmontado." : enabled ? "Observación habilitada. La recepción se muestra en Bisagra." : "Observación deshabilitada.")
            Text("La disponibilidad de la API no demuestra capacidad física.").font(.caption)
        }
    }
}

private struct EvidenceSection: View {
    let evidence: FoldEvidence
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Snapshot de esta ventana").font(.headline)
            Text("Escena: \(evidence.context.sceneID)\nVentana: \(evidence.context.windowID)\nGeneración: \(evidence.context.generation)")
                .font(.caption).textSelection(.enabled)
            Text("Identidades efímeras del observador, no identificadores de dispositivo.").font(.caption)
            ObservationCard(title: "Presentación", observation: evidence.presentationSize) { value in
                "\(value.points.width.formatted()) × \(value.points.height.formatted()) puntos\nFuente: \(value.source) · ámbito: ventana"
            }
            ObservationCard(title: "Pantalla", observation: evidence.nativeScreenSize) { value in
                "\(value.pixels.width) × \(value.pixels.height) píxeles nativos\nFuente: UIScreen.nativeBounds · ámbito: pantalla asociada a esta escena\nAtribución: \(value.attribution). Ejes nativos, no ejes de ventana."
            }
            ObservationCard(title: "Geometría del sistema", observation: evidence.layoutGeometry) { value in
                "Fuente: safeAreaLayoutGuide y UIView.reservedRegions · coordenadas de ventana en puntos\nSafe area: x=\(value.safeArea.x), y=\(value.safeArea.y), \(value.safeArea.width) × \(value.safeArea.height)\nAPI de regiones disponible: \(value.reservedRegionAPIAvailable) · divisiones: \(value.divisions.count) · oclusiones: \(value.occlusions.count)"
            }
            ObservationCard(title: "Captura de escena", observation: evidence.nativeScreenSize) { value in
                "Fuente: UITraitCollection.sceneCaptureState · estado: \(value.captureState). Activa puede significar grabación o reflejo; no identifica iPhone Mirroring."
            }
            ObservationCard(title: "Bisagra", observation: evidence.hinge) { value in
                "Estado: \(value.status)\nÁngulo: \(value.angleRadians.map { $0.formatted() } ?? "no disponible") rad (radianes)\nFuente: \(value.source) · ámbito: jerarquía de esta ventana"
            }
        }
    }
}

private struct ObservationCard<Value: Equatable & Sendable>: View {
    let title: String
    let observation: Observation<Value>
    let describe: (Value) -> String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            switch observation {
            case let .missing(reason):
                Text(missingDescription(reason))
                Text("Sin muestra: fuente efectiva, unidad y vigencia no disponibles.").font(.caption)
            case let .observed(value, metadata):
                Text(describe(value)).textSelection(.enabled)
                Text("Origen: \(String(describing: metadata.origin)) · vigencia: \(String(describing: metadata.validity)) · secuencia: \(metadata.sequence)").font(.caption)
                Text("Ámbito de muestra: escena \(metadata.context.sceneID), ventana \(metadata.context.windowID), generación \(metadata.context.generation)").font(.caption)
                Text("Vigencia contextual; no es una garantía de antigüedad temporal.").font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct AssessmentSection: View {
    let assessment: FoldAssessment
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Clasificación explicada").font(.headline)
            switch assessment.capability {
            case .unknown: Text("Capacidad: desconocida.")
            case let .hingeObserved(origin): Text("Capacidad: bisagra observada · origen \(String(describing: origin)).")
            }
            Text("Modelo: \(String(describing: assessment.model))")
            Text("Política: duo. Dimensiones compatibles más bisagra del mismo contexto.")
            Text("Contexto de pantalla: \(String(describing: assessment.displayContext))")
            Text("Pantalla: \(String(describing: assessment.presentation.display))")
            Text("Presentación: \(String(describing: assessment.presentation.mode))")
            Text("Origen de regiones: \(String(describing: assessment.presentation.regionSource))")
            Text("Regiones sin oclusiones observadas: \(assessment.presentation.unobscuredRegions.count) · recorte por límite: \(assessment.presentation.unobscuredRegionsTruncated ? "sí" : "no")")
            Text("Regiones lógicas: \(assessment.presentation.regions.count). La distribución interior la elige la app.")
            Text("La postura y el ángulo se muestran en Bisagra; no determinan por sí solos la distribución.").font(.caption)
            Text(assessment.reasons.map(reasonDescription).joined(separator: "\n"))
            Text("Inferencia por evidencias, no identificación oficial. El origen simulador permanece indicado; la identidad física de una pantalla de aplicación no está certificada.").font(.caption)
        }
    }
}

private struct HistorySection: View {
    let events: [DiagnosticEvent]
    let omitted: Int
    let lost: Int
    var body: some View {
        DisclosureGroup("Historial local: \(events.count) entradas") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Histórico, no evidencia vigente. Máximo 32 entradas. Retiradas del historial: \(omitted). Perdidas en entrega: \(lost).")
                ForEach(events.reversed()) { event in
                    Text("#\(event.id) · \(event.text)")
                        .font(.caption).textSelection(.enabled)
                }
            }
        }
    }
}

private func missingDescription(_ reason: MissingDataReason) -> String {
    switch reason {
    case .apiUnavailable: "API no disponible en este sistema."
    case .awaitingSample: "Esperando primera muestra; no implica ausencia física."
    case .observationSuspended: "Observación suspendida; datos no vigentes."
    case .unavailableInContext: "Dato no disponible en este contexto (nil); no implica ausencia física."
    }
}

private func hingeDescription(_ observation: Observation<HingeSample>) -> String {
    switch observation {
    case let .missing(reason): missingDescription(reason)
    case let .observed(value, metadata): "\(value.status), origen \(metadata.origin), secuencia \(metadata.sequence)"
    }
}

private func reasonDescription(_ reason: AssessmentReason) -> String {
    switch reason {
    case .hingeObserved: "• Evidencia aceptada: muestra de bisagra del contexto actual."
    case .sceneCaptureActive: "• Captura o reflejo activo: inferencia de modelo bloqueada."
    case .sceneCaptureUnknown: "• Estado de captura desconocido: inferencia bloqueada."
    case .displayIdentityUnverified: "• Pantalla de una escena de aplicación; identidad física y Mirroring no certificados."
    case .dimensionsMatch: "• Píxeles nativos compatibles con una pantalla de Duo."
    case .dimensionsDoNotMatch: "• Píxeles nativos no coincidentes con Duo."
    case .hingeStatusUnknown: "• La muestra no especifica un estado conocido."
    case .modelInferenceDisabled: "• No se evalúa la identidad del modelo."
    case let .missing(field, cause): "• \(field): \(missingDescription(cause))"
    case let .historical(field): "• \(field): muestra histórica descartada."
    case let .contextMismatch(field): "• \(field): contexto incompatible."
    case let .unknownOrigin(field): "• \(field): origen desconocido."
    default: "• \(String(describing: reason))"
    }
}


/// Manual diagnostic reading tied to this window, never a global screen selector.
private struct WindowInspectionSection: View {
    let canOpenSecondWindow: Bool
    @Environment(\.openWindow) private var openWindow
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @State private var anchor = UIView()
    @State private var reading = "Sin lectura manual."

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Control de entorno real").font(.headline)
            Text("Esta lectura usa el runtime incluso si el ejemplo sintético está seleccionado.").font(.caption)
            Button("Leer escalas de esta ventana") {
                guard let window = anchor.window, let scene = window.windowScene else {
                    reading = "Sin ventana o escena conectada."
                    return
                }
                let screen = scene.screen
                reading = "UIScreen.scale: \(screen.scale) · nativeScale: \(screen.nativeScale) (factores sin unidad)\nUIScreen.bounds: \(screen.bounds.width) × \(screen.bounds.height) puntos\nUIScreen.nativeBounds: \(screen.nativeBounds.width) × \(screen.nativeBounds.height) píxeles\nUIWindow.bounds: \(window.bounds.width) × \(window.bounds.height) puntos\nRol UISceneSession: \(scene.session.role.rawValue)\nLectura manual histórica; pulsar de nuevo para actualizar."
            }
            Text(reading).font(.caption).textSelection(.enabled)
            Button("Abrir segunda ventana") {
                guard canOpenSecondWindow, supportsMultipleWindows else { return }
                openWindow(id: "diagnostic")
            }
            .disabled(!canOpenSecondWindow || !supportsMultipleWindows)
            Text(!supportsMultipleWindows
                 ? "El sistema no permite varias ventanas en este contexto."
                 : canOpenSecondWindow
                 ? "Cada ventana observa su propia escena. iOS decide su colocación."
                 : "Abre o entreabre el dispositivo con la observación activa para abrir otra ventana.")
                .font(.caption)
        }
        .background(WindowInspectionAnchor(view: anchor))
    }
}

private struct WindowInspectionAnchor: UIViewRepresentable {
    let view: UIView
    func makeUIView(context: Context) -> UIView {
        view.isUserInteractionEnabled = false
        view.accessibilityElementsHidden = true
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
