/// Artificial dimensions for controlled experiments. No production profiles are provided.
public struct SyntheticDimensionProfile: Equatable, Sendable {
    public let first: PixelSize
    public let second: PixelSize

    public init?(first: PixelSize, second: PixelSize) {
        guard !sameDimensions(first, second) else { return nil }
        self.first = first
        self.second = second
    }

    fileprivate func matches(_ size: PixelSize) -> Bool {
        sameDimensions(first, size) || sameDimensions(second, size)
    }
}

public enum ClassificationPolicy: Equatable, Sendable {
    case observationOnly
    /// Only synthetic-origin inputs can participate in model inference.
    case synthetic(SyntheticDimensionProfile)
}

public enum FoldCapability: Equatable, Sendable {
    case unknown
    /// Simulator and synthetic samples do not establish physical hardware capability.
    case hingeObserved(origin: EvidenceOrigin)
}

public enum ModelInference: Equatable, Sendable {
    case insufficientInformation
    case syntheticDimensionCandidate
    case syntheticDuoInference
}

public enum EvidenceField: Equatable, Sendable {
    case hinge
    case nativeScreen
    case previousScreen
}

public enum AssessmentReason: Equatable, Sendable {
    case missing(EvidenceField, MissingDataReason)
    case historical(EvidenceField)
    case contextMismatch(EvidenceField)
    case unknownOrigin(EvidenceField)
    case hingeObserved
    case hingeStatusUnknown
    case modelInferenceDisabled
    case syntheticOriginRequired(EvidenceField)
    case screenAttributionUnsupported(EvidenceField, ScreenAttribution)
    case dimensionsMatch
    case dimensionsDoNotMatch
    case transitionNotComparable
    /// Supplementary dimensional evidence, not an independent signal.
    case compatibleDimensionTransition
}

public struct FoldAssessment: Equatable, Sendable {
    public let context: ObservationContext
    public let capability: FoldCapability
    public let model: ModelInference
    /// Deterministic explanations of accepted and rejected evidence.
    public let reasons: [AssessmentReason]
}

public enum FoldClassifier {
    /// Pure evaluation without clocks, UI, global state or implicit policy.
    /// Historical screen data is optional and cannot promote the model classification.
    public static func evaluate(
        evidence: FoldEvidence,
        policy: ClassificationPolicy,
        previousScreen: Observation<NativeScreenSize>? = nil
    ) -> FoldAssessment {
        var reasons: [AssessmentReason] = []
        let hinge = current(evidence.hinge, field: .hinge, context: evidence.context, reasons: &reasons)
        let capability: FoldCapability
        if let (sample, metadata) = hinge {
            capability = .hingeObserved(origin: metadata.origin)
            reasons.append(.hingeObserved)
            if sample.status == .unknown { reasons.append(.hingeStatusUnknown) }
        } else {
            capability = .unknown
        }

        func result(_ model: ModelInference) -> FoldAssessment {
            FoldAssessment(context: evidence.context, capability: capability, model: model, reasons: reasons)
        }

        guard case let .synthetic(profile) = policy else {
            reasons.append(.modelInferenceDisabled)
            return result(.insufficientInformation)
        }
        guard let (screen, metadata) = current(
            evidence.nativeScreenSize, field: .nativeScreen, context: evidence.context, reasons: &reasons
        ) else { return result(.insufficientInformation) }
        guard metadata.origin == .synthetic else {
            reasons.append(.syntheticOriginRequired(.nativeScreen))
            return result(.insufficientInformation)
        }
        guard screen.attribution == .deviceDisplay else {
            reasons.append(.screenAttributionUnsupported(.nativeScreen, screen.attribution))
            return result(.insufficientInformation)
        }
        guard profile.matches(screen.pixels) else {
            reasons.append(.dimensionsDoNotMatch)
            return result(.insufficientInformation)
        }
        reasons.append(.dimensionsMatch)
        if let previousScreen {
            appendTransitionReasons(previousScreen, current: screen, metadata: metadata,
                                    profile: profile, reasons: &reasons)
        }
        guard let (_, hingeMetadata) = hinge else { return result(.syntheticDimensionCandidate) }
        guard hingeMetadata.origin == .synthetic else {
            reasons.append(.syntheticOriginRequired(.hinge))
            return result(.syntheticDimensionCandidate)
        }
        return result(.syntheticDuoInference)
    }

    private static func current<Value>(
        _ observation: Observation<Value>, field: EvidenceField,
        context: ObservationContext, reasons: inout [AssessmentReason]
    ) -> (Value, EvidenceMetadata)? {
        switch observation {
        case let .missing(reason):
            reasons.append(.missing(field, reason))
            return nil
        case let .observed(value, metadata):
            var accepted = true
            if metadata.validity != .current {
                reasons.append(.historical(field))
                accepted = false
            }
            if metadata.context != context {
                reasons.append(.contextMismatch(field))
                accepted = false
            }
            if metadata.origin == .unknown {
                reasons.append(.unknownOrigin(field))
                accepted = false
            }
            return accepted ? (value, metadata) : nil
        }
    }

    private static func appendTransitionReasons(
        _ previous: Observation<NativeScreenSize>, current: NativeScreenSize,
        metadata: EvidenceMetadata, profile: SyntheticDimensionProfile,
        reasons: inout [AssessmentReason]
    ) {
        guard case let .observed(old, oldMetadata) = previous else {
            if case let .missing(reason) = previous { reasons.append(.missing(.previousScreen, reason)) }
            return
        }
        // Historical samples may cross display generations, but never windows or sessions.
        guard oldMetadata.context.sceneID == metadata.context.sceneID,
              oldMetadata.context.windowID == metadata.context.windowID,
              oldMetadata.context.generation <= metadata.context.generation else {
            reasons.append(.contextMismatch(.previousScreen))
            return
        }
        guard oldMetadata.origin == .synthetic else {
            reasons.append(.syntheticOriginRequired(.previousScreen))
            return
        }
        guard old.attribution == .deviceDisplay else {
            reasons.append(.screenAttributionUnsupported(.previousScreen, old.attribution))
            return
        }
        guard oldMetadata.sequence < metadata.sequence,
              profile.matches(old.pixels), !sameDimensions(old.pixels, current.pixels) else {
            reasons.append(.transitionNotComparable)
            return
        }
        reasons.append(.compatibleDimensionTransition)
    }
}

private func sameDimensions(_ lhs: PixelSize, _ rhs: PixelSize) -> Bool {
    (lhs.width == rhs.width && lhs.height == rhs.height)
        || (lhs.width == rhs.height && lhs.height == rhs.width)
}
