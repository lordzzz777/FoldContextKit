#if os(iOS)
import UIKit
import Testing
@testable import FoldContextKit

@MainActor
@Test func sceneActivationRejectsDisconnectedInactiveAndUnsupportedSources() {
    #expect(FoldWindowActivation.preflight(isConnected: false, isActive: false,
                                          supportsMultipleScenes: true) == .sourceUnavailable)
    #expect(FoldWindowActivation.preflight(isConnected: true, isActive: false,
                                          supportsMultipleScenes: true) == .sourceInactive)
    #expect(FoldWindowActivation.preflight(isConnected: true, isActive: true,
                                          supportsMultipleScenes: false) == .multipleScenesUnsupported)
    // Passing preflight means only that a request may be submitted, not that iOS accepts it.
    #expect(FoldWindowActivation.preflight(isConnected: true, isActive: true,
                                          supportsMultipleScenes: true) == nil)
}

@MainActor
@Test func activationActionDoesNotRetainSourceOrCreateActivityEarly() {
    var source: UIView? = UIView()
    weak var weakSource = source
    var activityCreated = false
    var action: UIWindowScene.ActivationAction?
    if let source {
        action = FoldWindowActivation.makeAction(title: "New window", from: source, userActivity: {
            activityCreated = true
            return NSUserActivity(activityType: "test.window")
        }, onFailure: { _ in })
    }
    source = nil
    #expect(weakSource == nil)
    #expect(action != nil)
    #expect(!activityCreated)
}
#endif
