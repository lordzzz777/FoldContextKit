@testable import FoldContextKit
import Testing

private func event(_ generation: UInt64, _ change: FoldChange) -> FoldObservationEvent {
    let context = ObservationContext(sceneID: "test", windowID: "test", generation: generation)
    return .snapshot(FoldEvidence(context: context, presentationSize: .missing(.awaitingSample),
                                  nativeScreenSize: .missing(.awaitingSample), hinge: .missing(.awaitingSample)), change: change)
}

@Test func boundedBufferPreservesDiscreteEventsAndReportsOverflow() {
    var buffer = FoldEventBuffer(capacity: 3)
    buffer.append(event(0, .hingeStatus))
    buffer.append(event(1, .hingeAngle))
    buffer.append(event(2, .hingeAngle))
    buffer.append(event(3, .lifecycle))
    #expect(buffer.events == [event(0, .hingeStatus), event(2, .hingeAngle), event(3, .lifecycle)])
    buffer.append(event(4, .context))
    #expect(buffer.drain() == [.overflow(droppedEvents: 1), event(2, .hingeAngle), event(3, .lifecycle), event(4, .context)])
    #expect(buffer.events.isEmpty)
    #expect(buffer.dropped == 0)
}

@Test func archivalCopyDoesNotMutateCurrentEvidence() throws {
    let context = ObservationContext(sceneID: "test", windowID: "test", generation: 0)
    let candidate = HingeSample(status: .closed, angleRadians: 0, source: .uiHingeInteraction)
    let sample = try #require(candidate)
    let input = FoldEvidence(context: context, presentationSize: .missing(.awaitingSample),
                             nativeScreenSize: .missing(.awaitingSample), hinge: .observed(sample, metadata:
                                EvidenceMetadata(context: context, sequence: 1, origin: .synthetic, validity: .current)))
    guard case let .snapshot(history, _) = historicalEvent(.snapshot(input, change: .hingeStatus)) else {
        Issue.record("Missing history")
        return
    }
    #expect(FoldClassifier.evaluate(evidence: input, policy: .observationOnly).capability == .hingeObserved(origin: .synthetic))
    #expect(FoldClassifier.evaluate(evidence: history, policy: .observationOnly).capability == .unknown)
}

#if os(iOS)
import UIKit
import SwiftUI

@Suite(.serialized)
@MainActor
struct UIKitObservationTests {
    @Test func detachedStartDeliversAndStopRemovesProbe() throws {
        let view = UIView()
        let observer = FoldContextObserver()
        var events: [FoldObservationEvent] = []
        observer.onChange = { events.append($0) }
        observer.start(in: view)
        #expect(events.count >= 1)
        #expect(observer.snapshot?.hinge == .missing(.observationSuspended))
        #expect(view.subviews.count == 1)
        observer.stop()
        let count = events.count
        observer.refresh()
        observer.stop()
        #expect(events.count == count)
        #expect(view.subviews.isEmpty)
    }

    @Test func releaseCleansUpWithoutRetainCycle() {
        let view = UIView()
        weak var released: FoldContextObserver?
        do {
            let observer = FoldContextObserver()
            released = observer
            observer.start(in: view)
        }
        #expect(released == nil)
        #expect(view.subviews.isEmpty)
    }

    @Test func swiftUICoordinatorFirstDeliveryAndDismantle() async throws {
        let view = UIView()
        let coordinator = FoldObservationBridge.Coordinator()
        var events: [FoldObservationEvent] = []
        coordinator.configure(view: view, enabled: true) { events.append($0) }
        // Allow deferred configuration/delivery; no hinge motion is requested.
        for _ in 0..<100 where events.isEmpty { await Task.yield() }
        #expect(!events.isEmpty)
        FoldObservationBridge.dismantleUIView(view, coordinator: coordinator)
        let count = events.count
        coordinator.enqueue(event(100, .hingeStatus))
        for _ in 0..<10 { await Task.yield() }
        #expect(events.count == count)
        #expect(view.subviews.isEmpty)
    }

    @Test func swiftUIDeliveryReportsOverflowAndKeepsDiscreteOrder() async {
        let view = UIView()
        let coordinator = FoldObservationBridge.Coordinator()
        var events: [FoldObservationEvent] = []
        coordinator.configure(view: view, enabled: true) { events.append($0) }
        for _ in 0..<100 where events.isEmpty { await Task.yield() }
        events.removeAll()
        for i in 0..<40 { coordinator.enqueue(event(UInt64(i), .hingeStatus)) }
        for _ in 0..<100 where events.count < 33 { await Task.yield() }
        #expect(events.first == .overflow(droppedEvents: 8))
        #expect(Array(events.dropFirst()) == (8..<40).map { event(UInt64($0), .hingeStatus) })
        coordinator.cancel()
    }

    @Test func initialDeliveryNativeChangeAndDisableInsideCallback() throws {
        let scene = NSObject()
        let screen = NSObject()
        let geometry = TestScreenGeometry()
        let window = TestWindowContainer(frame: CGRect(x: 0, y: 0, width: 200, height: 400))
        let root = UIView(frame: window.bounds)
        window.addSubview(root)
        let driver = ControlledHingeDriver()
        driver.initialSample = HingeSample(status: .closed, angleRadians: 0, source: .uiHingeInteraction)
        let observer = FoldContextObserver(environment: { _ in
            FoldWindowEnvironment(scene: scene, screen: screen, isActive: true, nativeBounds: geometry.bounds)
        }, driver: driver, origin: .synthetic, windowForView: testWindow(for:))
        defer { observer.stop() }
        observer.start(in: root)
        let initial = try #require(observer.snapshot)
        #expect(FoldClassifier.evaluate(evidence: initial, policy: .observationOnly).capability == .hingeObserved(origin: .synthetic))
        let late = driver.receive
        driver.initialSample = nil
        geometry.bounds.size = CGSize(width: 3000, height: 4000)
        observer.refresh()
        #expect(try #require(observer.snapshot?.context.generation) > initial.context.generation)
        #expect(observer.snapshot?.hinge == .missing(.awaitingSample))
        late?(HingeSample(status: .closed, angleRadians: 0, source: .uiHingeInteraction))
        #expect(observer.snapshot?.hinge == .missing(.awaitingSample))
        observer.onChange = { [weak observer] event in
            if case .snapshot(_, .geometry) = event { observer?.isEnabled = false }
        }
        window.bounds.size.width += 10
        observer.refresh()
        #expect(driver.receive == nil)
        #expect(observer.snapshot?.hinge == .missing(.observationSuspended))
    }

    @Test func unavailableAPIAndControlledHierarchyChanges() throws {
        let scene = NSObject()
        let screen = NSObject()
        let window = TestWindowContainer(frame: CGRect(x: 0, y: 0, width: 200, height: 400))
        let root = UIView(frame: window.bounds)
        window.addSubview(root)
        let driver = ControlledHingeDriver()
        driver.isAvailable = false
        let observer = FoldContextObserver(environment: { _ in
            FoldWindowEnvironment(scene: scene, screen: screen, isActive: true,
                                  nativeBounds: CGRect(x: 0, y: 0, width: 1000, height: 2000))
        }, driver: driver, origin: .synthetic, windowForView: testWindow(for:))
        defer { observer.stop() }
        observer.start(in: root)
        #expect(!observer.isHingeAPIAvailable)
        #expect(observer.snapshot?.hinge == .missing(.apiUnavailable))
        let active = observer.snapshot
        observer.lifecycleChanged(scene: NSObject(), active: false)
        #expect(observer.snapshot == active)
        root.removeFromSuperview()
        // Synthetic containers have no UIKit window-change notification.
        observer.refresh()
        #expect(observer.snapshot?.hinge == .missing(.observationSuspended))
        #expect(driver.receive == nil)
        window.addSubview(root)
        observer.refresh()
        #expect(observer.snapshot?.hinge == .missing(.apiUnavailable))
    }

    @Test func windowsLifecycleGeometryAndIsolation() throws {
        // Controlled environment: these tests do not claim an actual connected scene.
        let scene = NSObject()
        let screen = NSObject()
        let first = TestWindowContainer(frame: CGRect(x: 0, y: 0, width: 200, height: 400))
        let second = TestWindowContainer(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        let nativeBounds = CGRect(x: 0, y: 0, width: 1000, height: 2000)
        let environment: @MainActor (UIView) -> FoldWindowEnvironment? = { _ in
            FoldWindowEnvironment(scene: scene, screen: screen, isActive: true, nativeBounds: nativeBounds)
        }
        let driverA = ControlledHingeDriver()
        let driverB = ControlledHingeDriver()
        let a = FoldContextObserver(environment: environment, driver: driverA, origin: .synthetic, windowForView: testWindow(for:))
        let b = FoldContextObserver(environment: environment, driver: driverB, origin: .synthetic, windowForView: testWindow(for:))
        defer { a.stop(); b.stop(); first.isHidden = true; second.isHidden = true }
        let firstRoot = UIView(frame: first.bounds)
        let secondRoot = UIView(frame: second.bounds)
        first.addSubview(firstRoot)
        second.addSubview(secondRoot)
        a.start(in: firstRoot)
        b.start(in: secondRoot)
        // Injected lifecycle signals exercise handling, not physical scene transitions.
        a.lifecycleChanged(scene: scene, active: true)
        b.lifecycleChanged(scene: scene, active: true)
        first.bounds.size = CGSize(width: 321, height: 654)
        a.refresh()
        guard case let .observed(presentation, _)? = a.snapshot?.presentationSize else {
            Issue.record("Expected window geometry")
            return
        }
        #expect(presentation.source == .uiWindowBounds)
        #expect(presentation.points == PointSize(width: 321, height: 654))
        #expect(a.snapshot?.context.windowID != b.snapshot?.context.windowID)
        let untouched = b.snapshot
        let lateDelivery = driverA.receive
        a.isEnabled = false
        lateDelivery?(HingeSample(status: .closed, angleRadians: 0, source: .uiHingeInteraction))
        #expect(a.snapshot?.hinge == .missing(.observationSuspended))
        #expect(b.snapshot == untouched)
        a.isEnabled = true
        #expect(a.snapshot?.hinge == .missing(.awaitingSample))
        driverA.receive?(HingeSample(status: .partiallyOpen, angleRadians: 1, source: .uiHingeInteraction))
        if case let .observed(hinge, metadata)? = a.snapshot?.hinge {
            #expect(hinge.angleRadians == 1)
            #expect(metadata.origin == .synthetic)
        } else { Issue.record("Expected injected hinge sample") }
        driverA.receive?(nil)
        #expect(a.snapshot?.hinge == .missing(.unavailableInContext))
        #expect(a.snapshot?.presentationSize != .missing(.observationSuspended))
        a.lifecycleChanged(scene: scene, active: false)
        b.lifecycleChanged(scene: scene, active: false)
        #expect(a.snapshot?.hinge == .missing(.observationSuspended))
        a.lifecycleChanged(scene: scene, active: true)
        b.lifecycleChanged(scene: scene, active: true)
        #expect(a.snapshot?.presentationSize != .missing(.observationSuspended))
        let oldContext = a.snapshot?.context
        a.start(in: secondRoot)
        a.lifecycleChanged(scene: scene, active: true)
        b.lifecycleChanged(scene: scene, active: true)
        #expect(a.snapshot?.context != oldContext)
        if case let .observed(screen, _)? = a.snapshot?.nativeScreenSize {
            #expect(screen.pixels.width == Int(nativeBounds.width))
            #expect(screen.pixels.height == Int(nativeBounds.height))
            #expect(screen.attribution == .unknown)
        } else { Issue.record("Expected screen pixels") }
    }
}
// Scene-less SwiftPM tests use synthetic containers rather than deprecated UIWindow initializers.
@MainActor
private final class TestWindowContainer: UIView {}

@MainActor
private func testWindow(for view: UIView) -> UIView? {
    var current: UIView? = view
    while let candidate = current {
        if candidate is TestWindowContainer { return candidate }
        current = candidate.superview
    }
    return nil
}

@MainActor
private final class TestScreenGeometry {
    var bounds = CGRect(x: 0, y: 0, width: 1000, height: 2000)
}

@MainActor
private final class ControlledHingeDriver: FoldHingeDriver {
    var isAvailable = true
    var initialSample: HingeSample?
    var receive: (@MainActor (HingeSample?) -> Void)?
    func start(in view: UIView, receive: @escaping @MainActor (HingeSample?) -> Void) {
        guard isAvailable else { return }
        self.receive = receive
        if let initialSample { receive(initialSample) }
    }
    func stop() { receive = nil }
}
#endif
