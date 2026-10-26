#if os(iOS)
import UIKit

@MainActor
struct FoldWindowEnvironment {
    let scene: AnyObject
    let screen: AnyObject
    let isActive: Bool
    let nativeBounds: CGRect
}

@MainActor
protocol FoldHingeDriver: AnyObject {
    var isAvailable: Bool { get }
    func start(in view: UIView, receive: @escaping @MainActor (HingeSample?) -> Void)
    func stop()
}

@MainActor
final class SystemHingeDriver: FoldHingeDriver {
    private weak var view: UIView?
    private var interaction: (any UIInteraction)?
    private var epoch: UInt64 = 0
    var isAvailable: Bool {
        if #available(iOS 27.1, *) { return true }
        return false
    }

    func start(in view: UIView, receive: @escaping @MainActor (HingeSample?) -> Void) {
        stop()
        guard #available(iOS 27.1, *) else { return }
        self.view = view
        let currentEpoch = epoch
        let newInteraction = UIHingeInteraction { [weak self] _, update in
            guard let self, self.epoch == currentEpoch else { return }
            let sample = update.hinge.flatMap { hinge -> HingeSample? in
                let status: HingeStatus
                switch hinge.status {
                case .closed: status = .closed
                case .partiallyOpen: status = .partiallyOpen
                case .fullyOpen: status = .fullyOpen
                default: status = .unknown
                }
                return HingeSample(status: status, angleRadians: Double(hinge.angle), source: .uiHingeInteraction)
            }
            receive(sample)
        }
        // Delivery during initialization may cause the owner to stop.
        guard epoch == currentEpoch else { return }
        interaction = newInteraction
        view.addInteraction(newInteraction)
    }

    func stop() {
        epoch += 1
        if let interaction { view?.removeInteraction(interaction) }
        interaction = nil
        view = nil
    }

    isolated deinit {
        if let interaction { view?.removeInteraction(interaction) }
    }
}
#endif
