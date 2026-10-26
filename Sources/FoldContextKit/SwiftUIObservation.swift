#if os(iOS)
import SwiftUI
import UIKit

extension View {
    /// Attach once to a stable root in each window. Measures that UIWindow in points.
    /// The callback runs on MainActor outside representable update/layout callbacks.
    /// Hinge data comes from UIKit, including when used from SwiftUI.
    public func onFoldContextChange(
        isEnabled: Bool = true,
        _ action: @escaping @MainActor (FoldObservationEvent) -> Void
    ) -> some View {
        background(FoldObservationBridge(isEnabled: isEnabled, action: action))
    }
}

struct FoldObservationBridge: UIViewRepresentable {
    let isEnabled: Bool
    let action: @MainActor (FoldObservationEvent) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.accessibilityElementsHidden = true
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.configure(view: uiView, enabled: isEnabled, action: action)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.cancel()
    }

    @MainActor
    final class Coordinator {
        let observer = FoldContextObserver()
        private var buffer = FoldEventBuffer(capacity: 32)
        private var delivery: Task<Void, Never>?
        private var configuration: Task<Void, Never>?
        private var action: (@MainActor (FoldObservationEvent) -> Void)?
        private weak var attachedView: UIView?
        private var cancelled = false

        func configure(view: UIView, enabled: Bool, action: @escaping @MainActor (FoldObservationEvent) -> Void) {
            guard !cancelled else { return }
            self.action = action
            configuration?.cancel()
            configuration = Task { @MainActor [weak self, weak view] in
                await Task.yield()
                guard !Task.isCancelled, let self, !self.cancelled, let view else { return }
                self.observer.onChange = { [weak self] event in self?.enqueue(event) }
                self.observer.isEnabled = enabled
                if self.attachedView !== view {
                    self.attachedView = view
                    self.observer.start(in: view)
                }
            }
        }

        // Internal so bounded delivery can be tested without inventing hinge hardware.
        func enqueue(_ event: FoldObservationEvent) {
            guard !cancelled else { return }
            buffer.append(event)
            guard delivery == nil else { return }
            delivery = Task { @MainActor [weak self] in
                await Task.yield()
                guard !Task.isCancelled, let self, !self.cancelled else { return }
                self.delivery = nil
                let events = self.buffer.drain()
                for event in events {
                    guard !self.cancelled else { return }
                    self.action?(event)
                }
            }
        }

        func cancel() {
            cancelled = true
            configuration?.cancel()
            delivery?.cancel()
            configuration = nil
            delivery = nil
            action = nil
            observer.onChange = nil
            observer.stop()
            attachedView = nil
            _ = buffer.drain()
        }

        isolated deinit {
            configuration?.cancel()
            delivery?.cancel()
            observer.onChange = nil
            observer.stop()
        }
    }
}
#endif
