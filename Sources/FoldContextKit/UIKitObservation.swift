#if os(iOS)
import Foundation
import UIKit

/// Own one observer per tracked root view/window. Retain it and call stop() on teardown.
/// A transparent tracking subview detects hierarchy and layout changes.
@MainActor
public final class FoldContextObserver: NSObject {
    public private(set) var snapshot: FoldEvidence?
    /// App-selected arrangement; read assessment again after changing it.
    public var interiorLayout: FoldInteriorLayout = .unspecified
    /// Current inference; unavailable while there is no snapshot.
    public var assessment: FoldAssessment? {
        snapshot.map { FoldClassifier.evaluate(evidence: $0, interiorLayout: interiorLayout) }
    }
    /// Synchronous delivery on MainActor. Capture your owner weakly to avoid cycles.
    public var onChange: (@MainActor (FoldObservationEvent) -> Void)?
    public var history: [FoldObservationEvent] { historyBuffer.events.map(historicalEvent) }
    public var discardedHistoryEvents: Int { historyBuffer.dropped }
    /// API availability only, never a hardware-capability claim.
    public var isHingeAPIAvailable: Bool { driver.isAvailable }
    public var isEnabled = true {
        didSet {
            guard oldValue != isEnabled else { return }
            if !isEnabled, running {
                removeInteraction()
                publishSuspended()
            } else { reconcile(force: true) }
        }
    }

    private let probe = FoldTrackingView()
    private var historyBuffer = FoldEventBuffer(capacity: 32)
    private weak var trackedWindow: UIView?
    private weak var trackedScene: AnyObject?
    private weak var trackedScreen: AnyObject?
    private var context = ObservationContext(sceneID: UUID().uuidString, windowID: UUID().uuidString, generation: 0)
    private var sequence: UInt64 = 0
    private var running = false
    private var acceptingHinge = false
    private var driverStarted = false
    private var interactionEpoch: UInt64 = 0
    private var reconciling = false
    private var sceneIsActive: Bool?

    private let environment: @MainActor (UIView) -> FoldWindowEnvironment?
    private let windowForView: @MainActor (UIView) -> UIView?
    private let driver: any FoldHingeDriver
    private let origin: EvidenceOrigin

    public override convenience init() {
        self.init(environment: { window in
            guard let window = window as? UIWindow, let scene = window.windowScene else { return nil }
            return FoldWindowEnvironment(scene: scene, screen: scene.screen,
                                         isActive: scene.activationState == .foregroundActive,
                                         nativeBounds: scene.screen.nativeBounds)
        }, driver: SystemHingeDriver(), origin: Self.runtimeOrigin)
    }

    // Dependency injection is internal. Controlled tests must declare synthetic origin.
    init(environment: @escaping @MainActor (UIView) -> FoldWindowEnvironment?,
         driver: any FoldHingeDriver, origin: EvidenceOrigin,
         windowForView: @escaping @MainActor (UIView) -> UIView? = { $0.window }) {
        self.environment = environment
        self.windowForView = windowForView
        self.driver = driver
        self.origin = origin
        super.init()
        probe.owner = self
        probe.isUserInteractionEnabled = false
        probe.isAccessibilityElement = false
        probe.accessibilityElementsHidden = true
        probe.backgroundColor = .clear
    }

    /// Moving to another root invalidates all previous samples.
    public func start(in view: UIView) {
        stop()
        running = true
        registerLifecycle()
        probe.frame = view.bounds
        probe.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(probe)
        reconcile(force: true)
    }

    /// Idempotent. Removes interactions and lifecycle observers, and invalidates samples.
    public func stop() {
        guard running else { return }
        running = false
        removeInteraction()
        NotificationCenter.default.removeObserver(self)
        probe.removeFromSuperview()
        sceneIsActive = nil
        publishSuspended()
    }

    isolated deinit {
        NotificationCenter.default.removeObserver(self)
        driver.stop()
        probe.removeFromSuperview()
    }

    /// Refresh geometry explicitly if the host changes presentation without a layout pass.
    public func refresh() { reconcile(force: false) }

    private func registerLifecycle() {
        for name in [UIScene.didActivateNotification, UIScene.willDeactivateNotification,
                     UIScene.didEnterBackgroundNotification, UIScene.didDisconnectNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(sceneChanged(_:)), name: name, object: nil)
        }
    }

    @objc private func sceneChanged(_ notification: Notification) {
        guard let scene = notification.object as? UIWindowScene else { return }
        lifecycleChanged(scene: scene, active: notification.name == UIScene.didActivateNotification)
    }

    func lifecycleChanged(scene: AnyObject, active: Bool) {
        guard scene === trackedScene else { return }
        // willDeactivate precedes the activationState change.
        sceneIsActive = active
        reconcile(force: true)
    }

    fileprivate func hierarchyChanged() {
        guard running else { return }
        removeInteraction()
        context = ObservationContext(sceneID: context.sceneID, windowID: context.windowID,
                                     generation: context.generation + 1)
        reconcile(force: true)
    }

    private func removeInteraction() {
        acceptingHinge = false
        interactionEpoch += 1
        driver.stop()
        driverStarted = false
    }

    private func reconcile(force: Bool) {
        guard running, !reconciling else { return }
        reconciling = true
        defer { reconciling = false }
        let window = windowForView(probe)
        let environment = window.flatMap(environment)
        let scene = environment?.scene
        let screen = environment?.screen
        let changed = window !== trackedWindow || scene !== trackedScene || screen !== trackedScreen
        if changed {
            removeInteraction()
            let sceneID = scene === trackedScene ? context.sceneID : UUID().uuidString
            let windowID = window === trackedWindow ? context.windowID : UUID().uuidString
            context = ObservationContext(sceneID: sceneID, windowID: windowID, generation: context.generation + 1)
            trackedWindow = window
            trackedScene = scene
            trackedScreen = screen
            sceneIsActive = nil
        }
        guard isEnabled, let window, let environment,
              sceneIsActive ?? environment.isActive else {
            removeInteraction()
            publishSuspended()
            return
        }
        let points = PointSize(width: Double(window.bounds.width), height: Double(window.bounds.height))
        let bounds = environment.nativeBounds
        let pixels: PixelSize?
        if bounds.width.isFinite, bounds.height.isFinite,
           bounds.width > 0, bounds.height > 0,
           bounds.width < CGFloat(Int.max), bounds.height < CGFloat(Int.max),
           bounds.width.rounded() == bounds.width, bounds.height.rounded() == bounds.height {
            pixels = PixelSize(width: Int(bounds.width), height: Int(bounds.height))
        } else { pixels = nil }
        let presentation = points.map { PresentationSize(points: $0, source: .uiWindowBounds) }
        // Scene role describes presentation, not hardware identity or iPhone Mirroring status.
        let attribution: ScreenAttribution
        if let scene = environment.scene as? UIWindowScene {
            if scene.screen.mirrored != nil {
                attribution = .mirrored
            } else if scene.session.role == .windowApplication {
                attribution = .applicationDisplay
            } else {
                attribution = .externalDisplay
            }
        } else {
            attribution = .unknown
        }
        let captureState: FoldCaptureState
        switch probe.traitCollection.sceneCaptureState {
        case .active: captureState = .active
        case .inactive: captureState = .inactive
        default: captureState = .unknown
        }
        let native = pixels.map {
            NativeScreenSize(pixels: $0, attribution: attribution, captureState: captureState)
        }
        let geometry = readLayoutGeometry(in: window)
        let old = snapshot
        // A display can change its native metrics without replacing the UIScreen object.
        if !changed, let previous = observedValue(old?.nativeScreenSize),
           (previous.pixels != native?.pixels || previous.attribution != native?.attribution
               || previous.captureState != native?.captureState) {
            removeInteraction()
            context = ObservationContext(sceneID: context.sceneID, windowID: context.windowID,
                                         generation: context.generation + 1)
        }
        let contextChanged = old?.context != context
        if contextChanged || force || presentation != observedValue(old?.presentationSize) || native != observedValue(old?.nativeScreenSize)
            || geometry != observedValue(old?.layoutGeometry) {
            let metadata = nextMetadata()
            let hinge: Observation<HingeSample>
            if contextChanged || !acceptingHinge { hinge = waitingHinge() }
            else { hinge = old?.hinge ?? waitingHinge() }
            publish(FoldEvidence(
                context: context,
                presentationSize: presentation.map { .observed($0, metadata: metadata) } ?? .missing(.unavailableInContext),
                nativeScreenSize: native.map { .observed($0, metadata: metadata) } ?? .missing(.unavailableInContext),
                hinge: hinge,
                layoutGeometry: geometry.map { .observed($0, metadata: metadata) } ?? .missing(.unavailableInContext)
            ), change: contextChanged ? .context : .geometry)
        }
        // A handler may stop or disable the observer synchronously.
        guard running, isEnabled else { return }
        if !driverStarted {
            acceptingHinge = true
            driverStarted = true
            let epoch = interactionEpoch
            driver.start(in: probe) { [weak self] sample in
                guard let self, self.running, self.isEnabled, self.acceptingHinge,
                      self.interactionEpoch == epoch else { return }
                self.receive(sample)
            }
        }
    }

    private func receive(_ sample: HingeSample?) {
        let epoch = interactionEpoch
        reconcile(force: false)
        guard acceptingHinge, interactionEpoch == epoch else { return }
        guard let old = snapshot, let window = windowForView(probe),
              let environment = environment(window), window === trackedWindow,
              environment.scene === trackedScene, environment.screen === trackedScreen else {
            reconcile(force: true)
            return
        }
        let previous = observedValue(old.hinge)
        guard previous != sample || isMissing(old.hinge) else { return }
        let observation: Observation<HingeSample> = sample.map { .observed($0, metadata: nextMetadata()) }
            ?? .missing(.unavailableInContext)
        publish(FoldEvidence(context: context, presentationSize: old.presentationSize,
                             nativeScreenSize: old.nativeScreenSize, hinge: observation,
                             layoutGeometry: old.layoutGeometry),
                change: previous != nil && sample != nil && previous?.status == sample?.status ? .hingeAngle : .hingeStatus)
    }

    private func readLayoutGeometry(in window: UIView) -> FoldLayoutGeometry? {
        guard let root = probe.superview else { return nil }
        let safeRect = root.convert(root.safeAreaLayoutGuide.layoutFrame, to: window)
            .intersection(window.bounds)
        guard !safeRect.isNull, !safeRect.isInfinite else { return nil }
        func frame(_ rect: CGRect) -> FoldPresentationRegion {
            // Normalize to the window-bounds origin used by presentationSize.
            FoldPresentationRegion(x: Double(rect.minX - window.bounds.minX),
                                   y: Double(rect.minY - window.bounds.minY),
                                   width: Double(rect.width), height: Double(rect.height))
        }
        if #available(iOS 27.1, *) {
            func regions(_ kind: UIView.ReservedRegion.Kind) -> [FoldReservedRegion] {
                root.reservedRegions(kind: kind).filter(\.isActive).map { region in
                    let rect = root.convert(region.frame, to: window)
                    return FoldReservedRegion(frame: frame(rect), margins: FoldRegionMargins(
                        top: Double(region.margins.top), left: Double(region.margins.left),
                        bottom: Double(region.margins.bottom), right: Double(region.margins.right)))
                }
            }
            return FoldLayoutGeometry(safeArea: frame(safeRect), divisions: regions(.division),
                                      occlusions: regions(.occlusion), reservedRegionAPIAvailable: true)
        }
        return FoldLayoutGeometry(safeArea: frame(safeRect), divisions: [], occlusions: [],
                                  reservedRegionAPIAvailable: false)
    }

    private func waitingHinge() -> Observation<HingeSample> {
        if driver.isAvailable { return .missing(.awaitingSample) }
        return .missing(.apiUnavailable)
    }

    private func publishSuspended() {
        let evidence = FoldEvidence(context: context, presentationSize: .missing(.observationSuspended),
                                    nativeScreenSize: .missing(.observationSuspended), hinge: .missing(.observationSuspended),
                                    layoutGeometry: .missing(.observationSuspended))
        guard evidence != snapshot else { return }
        publish(evidence, change: .lifecycle)
    }

    private func nextMetadata() -> EvidenceMetadata {
        sequence += 1
        return EvidenceMetadata(context: context, sequence: sequence, origin: origin, validity: .current)
    }

    private static var runtimeOrigin: EvidenceOrigin {
        #if targetEnvironment(simulator)
        .simulator
        #else
        .system
        #endif
    }

    private func publish(_ evidence: FoldEvidence, change: FoldChange) {
        snapshot = evidence
        let event = FoldObservationEvent.snapshot(evidence, change: change)
        historyBuffer.append(event)
        onChange?(event)
    }
}

@MainActor
private func observedValue<T>(_ observation: Observation<T>?) -> T? {
    if case let .observed(value, _) = observation { return value }
    return nil
}

private func isMissing<T>(_ observation: Observation<T>) -> Bool {
    if case .missing = observation { return true }
    return false
}

@MainActor
private final class FoldTrackingView: UIView {
    weak var owner: FoldContextObserver?

    override init(frame: CGRect) {
        super.init(frame: frame)
        registerForTraitChanges([UITraitSceneCaptureState.self]) { (view: FoldTrackingView, _: UITraitCollection) in
            view.owner?.refresh()
        }
    }

    required init?(coder: NSCoder) { return nil }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        owner?.refresh()
    }
    override func didMoveToWindow() { super.didMoveToWindow(); owner?.hierarchyChanged() }
    override func didMoveToSuperview() { super.didMoveToSuperview(); owner?.hierarchyChanged() }
    override func layoutSubviews() { super.layoutSubviews(); owner?.refresh() }
}
#endif
