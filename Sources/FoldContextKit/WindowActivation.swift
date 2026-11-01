#if os(iOS)
import UIKit

/// Local request failures. Submission is not confirmation that a new scene appeared.
public enum FoldWindowActivationError: Error, Equatable, Sendable {
    case sourceUnavailable
    case sourceInactive
    case multipleScenesUnsupported
    /// The native action's alternate path does not expose an underlying NSError.
    case unavailableOrRejected
}

/// Explicit, consumer-initiated window activation. Never changes navigation on a hinge event.
@MainActor
public enum FoldWindowActivation {
    /// Requests a scene for the supplied activity, attributed to this source scene.
    /// The app owns routing/activation conditions; iOS may reuse a matching scene.
    /// `onError` receives preflight errors or the original system error. No success callback
    /// is synthesized: observe the destination's scene lifecycle to confirm activation.
    public static func request(
        from scene: UIWindowScene,
        userActivity: NSUserActivity,
        onError: @escaping @MainActor (any Error) -> Void
    ) {
        if let failure = preflight(isConnected: scene.activationState != .unattached,
                                   isActive: scene.activationState == .foregroundActive,
                                   supportsMultipleScenes: UIApplication.shared.supportsMultipleScenes) {
            onError(failure)
            return
        }
        UIApplication.shared.activateSceneSession(
            for: UISceneSessionActivationRequest(userActivity: userActivity, options: options(for: scene)),
            errorHandler: onError
        )
    }

    /// Native UIKit action: the system controls contextual availability (including Duo's
    /// inner display). The source is resolved at invocation, not from a global key window.
    /// Retains neither the source view nor its window. The factory runs only on invocation.
    public static func makeAction(
        title: String,
        from source: UIView,
        userActivity: @escaping @MainActor () -> NSUserActivity,
        onFailure: @escaping @MainActor (FoldWindowActivationError) -> Void
    ) -> UIWindowScene.ActivationAction {
        let alternate = UIAction(title: title) { _ in onFailure(.unavailableOrRejected) }
        return UIWindowScene.ActivationAction(title: title, alternate: alternate) { [weak source] _ in
            guard let scene = source?.window?.windowScene else {
                onFailure(.sourceUnavailable)
                return nil
            }
            if let failure = preflight(isConnected: scene.activationState != .unattached,
                                       isActive: scene.activationState == .foregroundActive,
                                       supportsMultipleScenes: UIApplication.shared.supportsMultipleScenes) {
                onFailure(failure)
                return nil
            }
            return UIWindowScene.ActivationConfiguration(userActivity: userActivity(), options: options(for: scene))
        }
    }

    static func preflight(isConnected: Bool, isActive: Bool,
                          supportsMultipleScenes: Bool) -> FoldWindowActivationError? {
        if !isConnected { return .sourceUnavailable }
        if !isActive { return .sourceInactive }
        if !supportsMultipleScenes { return .multipleScenesUnsupported }
        return nil
    }

    static func options(for scene: UIWindowScene) -> UIWindowScene.ActivationRequestOptions {
        let options = UIWindowScene.ActivationRequestOptions()
        options.requestingScene = scene
        // Default system placement supports the platform's native multitasking model.
        return options
    }
}
#endif
