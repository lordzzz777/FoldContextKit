import SwiftUI
import UIKit
import FoldContextKit

@main
struct RuntimeProbeApp: App {
    var body: some Scene {
        WindowGroup { ProbeView() }
    }
}

/// Local simulator harness. No synthetic samples or production dimension profiles.
private struct ProbeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var mounted = true
    @State private var enabled = true
    @State private var events = 0
    @State private var latest = "Waiting for observer"
    @State private var audit = "Not audited"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FoldContextKit runtime probe").font(.headline)
            Text("Simulator observations are not physical hardware evidence.")
            Toggle("Mount observer", isOn: $mounted)
            Toggle("Enable observation", isOn: $enabled)
            if mounted {
                Text("Observed root")
                    .onFoldContextChange(isEnabled: enabled) { event in
                        events += 1
                        latest = describe(event)
                        log("event=\(events) \(latest)")
                    }
            }
            Text("Events: \(events)")
            Text(latest).font(.caption).textSelection(.enabled)
            Button("Audit active scene") { auditScene() }
            Text(audit).font(.caption)
            Spacer()
        }
        .padding()
        .onChange(of: scenePhase, initial: true) { _, phase in log("phase=\(phase)") }
        .onChange(of: mounted) { _, value in log("mounted=\(value)") }
        .onChange(of: enabled) { _, value in log("enabled=\(value)") }
    }

    private func describe(_ event: FoldObservationEvent) -> String {
        switch event {
        case let .overflow(count): return "overflow=\(count)"
        case let .snapshot(evidence, change):
            var fields = ["change=\(change)", "generation=\(evidence.context.generation)"]
            switch evidence.hinge {
            case let .missing(reason): fields.append("hinge=\(reason)")
            case let .observed(sample, metadata):
                fields.append("hinge=\(sample.status) radians=\(sample.angleRadians.map(String.init(describing:)) ?? "nil") source=\(sample.source) origin=\(metadata.origin)")
            }
            if case let .observed(size, _) = evidence.presentationSize {
                fields.append("windowPoints=\(size.points.width)x\(size.points.height) source=\(size.source)")
            }
            if case let .observed(size, _) = evidence.nativeScreenSize {
                fields.append("nativePixels=\(size.pixels.width)x\(size.pixels.height) source=UIScreen.nativeBounds attribution=\(size.attribution)")
            }
            return fields.joined(separator: " ")
        }
    }

    @MainActor
    private func auditScene() {
        // Diagnostic only: enumerate connected scenes, never use this as observer input.
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let counts = scenes.map { scene in
            let count = scene.windows.reduce(0) { $0 + hingeCount(in: $1) }
            return "state=\(scene.activationState.rawValue) windows=\(scene.windows.count) hingeInteractions=\(count)"
        }
        audit = "connectedScenes=\(scenes.count) " + counts.joined(separator: "; ")
        log("audit \(audit) events=\(events)")
    }

    @MainActor
    private func hingeCount(in view: UIView) -> Int {
        let own: Int
        if #available(iOS 27.1, *) {
            own = view.interactions.filter { $0 is UIHingeInteraction }.count
        } else { own = 0 }
        return own + view.subviews.reduce(0) { $0 + hingeCount(in: $1) }
    }

    private func log(_ message: String) {
        print("FOLD_PROBE \(ProcessInfo.processInfo.systemUptime) \(message)")
    }
}
