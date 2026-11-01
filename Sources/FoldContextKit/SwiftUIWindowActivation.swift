#if os(iOS)
import SwiftUI
import UIKit

/// A native scene-activation button. Supply a localized title and an activity that
/// your app routes to a window. The system decides placement and availability.
@MainActor
public struct FoldNewWindowButton: UIViewRepresentable {
    private let title: String
    private let userActivity: @MainActor () -> NSUserActivity
    private let onFailure: @MainActor (FoldWindowActivationError) -> Void

    public init(_ title: String,
                userActivity: @escaping @MainActor () -> NSUserActivity,
                onFailure: @escaping @MainActor (FoldWindowActivationError) -> Void) {
        self.title = title
        self.userActivity = userActivity
        self.onFailure = onFailure
    }

    public func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        return button
    }

    public func updateUIView(_ button: UIButton, context: Context) {
        button.isEnabled = context.environment.isEnabled
        if let previous = context.coordinator.action {
            button.removeAction(previous, for: .primaryActionTriggered)
        }
        let action = FoldWindowActivation.makeAction(title: title, from: button,
                                                     userActivity: userActivity, onFailure: onFailure)
        context.coordinator.action = action
        button.setTitle(title, for: .normal)
        button.addAction(action, for: .primaryActionTriggered)
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIButton, context: Context) -> CGSize? {
        uiView.intrinsicContentSize
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public static func dismantleUIView(_ button: UIButton, coordinator: Coordinator) {
        if let action = coordinator.action { button.removeAction(action, for: .primaryActionTriggered) }
        coordinator.action = nil
    }

    public final class Coordinator {
        fileprivate var action: UIAction?
    }
}
#endif
