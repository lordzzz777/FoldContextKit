// Compilation probes, never called by tests; excluded from the library product.
import FoldContextKit

#if os(iOS)
import SwiftUI
import UIKit

@available(iOS 27.1, *)
@MainActor
func validateUIKitSignature(on view: UIView) -> UIHingeInteraction {
    let interaction = UIHingeInteraction { _, update in
        let hinge: UIHinge? = update.hinge
        let _: CGFloat? = hinge?.angle
        let _: UIHinge.Status? = hinge?.status
    }
    interaction.isEnabled = true
    view.addInteraction(interaction)
    return interaction
}

@available(iOS 27.1, *)
@MainActor
func validateSwiftUISignature<V: View>(_ content: V) -> some View {
    content.onHingeChange(isEnabled: true) { oldContext, newContext in
        let _: DeviceHingeContext = oldContext
        let hinge: DeviceHinge? = newContext.hinge
        let _: Angle? = hinge?.angle
        let _: DeviceHinge.Status? = hinge?.status
    }
}

@MainActor
func validateUIKitAvailability(on view: UIView) {
    if #available(iOS 27.1, *) {
        _ = validateUIKitSignature(on: view)
    }
}

@MainActor
@ViewBuilder
func validateSwiftUIAvailability<V: View>(_ content: V) -> some View {
    if #available(iOS 27.1, *) {
        validateSwiftUISignature(content)
    } else {
        content
    }
}
#endif
