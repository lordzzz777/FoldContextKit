public enum FoldChange: Equatable, Sendable {
    case context
    case geometry
    case hingeStatus
    case hingeAngle
    case lifecycle
}

public enum FoldObservationEvent: Equatable, Sendable {
    case snapshot(FoldEvidence, change: FoldChange)
    /// Bounded delivery could not retain this many older events. Resample current state.
    case overflow(droppedEvents: Int)
}

/// Bounded storage shared by history and the deferred SwiftUI delivery queue.
/// Only consecutive angle-only events can replace one another.
struct FoldEventBuffer {
    let capacity: Int
    private(set) var events: [FoldObservationEvent] = []
    private(set) var dropped = 0

    init(capacity: Int) { self.capacity = max(1, capacity) }

    mutating func append(_ event: FoldObservationEvent) {
        if case .snapshot(_, .hingeAngle) = event,
           case .snapshot(_, .hingeAngle)? = events.last {
            events[events.count - 1] = event
            return
        }
        if events.count == capacity {
            events.removeFirst()
            dropped += 1
        }
        events.append(event)
    }

    mutating func drain() -> [FoldObservationEvent] {
        let result = (dropped > 0 ? [.overflow(droppedEvents: dropped)] : []) + events
        events.removeAll(keepingCapacity: true)
        dropped = 0
        return result
    }
}

func historicalEvent(_ event: FoldObservationEvent) -> FoldObservationEvent {
    guard case let .snapshot(evidence, change) = event else { return event }
    return .snapshot(FoldEvidence(
        context: evidence.context,
        presentationSize: historical(evidence.presentationSize),
        nativeScreenSize: historical(evidence.nativeScreenSize),
        hinge: historical(evidence.hinge),
        layoutGeometry: historical(evidence.layoutGeometry)
    ), change: change)
}

private func historical<T>(_ observation: Observation<T>) -> Observation<T> {
    guard case let .observed(value, metadata) = observation else { return observation }
    return .observed(value, metadata: EvidenceMetadata(
        context: metadata.context, sequence: metadata.sequence, origin: metadata.origin, validity: .historical
    ))
}
