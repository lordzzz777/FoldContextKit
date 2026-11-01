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
    /// Infer Duo from native pixels and a current hinge sample; not official model identification.
    case duo
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
    case duoDimensionCandidate(origin: EvidenceOrigin)
    case duoInferred(origin: EvidenceOrigin)
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
    case runtimeOriginRequired(EvidenceField)
    case originMismatch(EvidenceField)
    /// The screen belongs to an application scene; physical display identity is not certified.
    case displayIdentityUnverified
    case sceneCaptureActive
    case sceneCaptureUnknown
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
    public let presentation: FoldPresentation
    public let displayContext: Observation<FoldDisplayContext>
    /// Deterministic explanations of accepted and rejected evidence.
    public let reasons: [AssessmentReason]
}

public enum FoldClassifier {
    /// Pure evaluation without clocks, UI, global state or implicit policy.
    /// Historical screen data is optional and cannot promote the model classification.
    public static func evaluate(
        evidence: FoldEvidence,
        policy: ClassificationPolicy = .duo,
        previousScreen: Observation<NativeScreenSize>? = nil,
        interiorLayout: FoldInteriorLayout = .unspecified
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
            FoldAssessment(context: evidence.context, capability: capability, model: model,
                           presentation: presentation(evidence: evidence, model: model, layout: interiorLayout),
                           displayContext: evidence.displayContext, reasons: reasons)
        }

        if policy == .duo {
            return inferDuo(evidence: evidence, hinge: hinge, capability: capability,
                            previousScreen: previousScreen, interiorLayout: interiorLayout, reasons: reasons)
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



    private static func duoDisplay(_ size: PixelSize, origin: EvidenceOrigin) -> FoldDisplay {
        switch (min(size.width, size.height), max(size.width, size.height)) {
        case (1398, 2034): .exterior
        case (1878, 2670): .interior
        // Recorded nativeBounds from Duo Simulator 27.1. Do not promote a
        // simulator-specific profile into an unverified physical-device profile.
        case (2007, 2853) where origin == .simulator: .interior
        default: .unknown
        }
    }

    private static func presentation(
        evidence: FoldEvidence, model: ModelInference, layout: FoldInteriorLayout
    ) -> FoldPresentation {
        var reasons: [AssessmentReason] = []
        let hinge: Observation<HingeSample>
        if let (value, metadata) = current(
            evidence.hinge, field: .hinge, context: evidence.context, reasons: &reasons
        ) {
            hinge = .observed(value, metadata: metadata)
        } else if case let .missing(reason) = evidence.hinge {
            hinge = .missing(reason)
        } else {
            hinge = .missing(.unavailableInContext)
        }
        var display: FoldDisplay = .unknown
        var origin: EvidenceOrigin?
        if case let .duoInferred(inferredOrigin) = model,
           case let .observed(screen, _) = evidence.nativeScreenSize {
            display = duoDisplay(screen.pixels, origin: inferredOrigin)
            origin = inferredOrigin
        }
        let mode: FoldPresentationMode
        switch display {
        case .unknown: mode = .unknown
        case .exterior: mode = .exterior
        case .interior:
            switch layout {
            case .unspecified: mode = .interiorUnspecified
            case .extended: mode = .interiorExtended
            case let .divided(axis): mode = .interiorDivided(axis: axis)
            }
        }
        var regions: [FoldPresentationRegion] = []
        var regionMetadata: EvidenceMetadata?
        var regionSource: FoldRegionSource = .unavailable
        var layoutGeometry: Observation<FoldLayoutGeometry> = .missing(.unavailableInContext)
        if case let .observed(geometry, metadata) = evidence.layoutGeometry,
           metadata.context == evidence.context, metadata.validity == .current,
           metadata.origin != .unknown {
            layoutGeometry = .observed(geometry, metadata: metadata)
        } else if case let .missing(reason) = evidence.layoutGeometry {
            layoutGeometry = .missing(reason)
        }
        if display != .unknown,
           case let .observed(size, metadata) = evidence.presentationSize,
           metadata.context == evidence.context, metadata.validity == .current,
           metadata.origin == origin, size.source == .uiWindowBounds,
           size.points.width > 0, size.points.height > 0 {
            let width = size.points.width
            let height = size.points.height
            switch mode {
            case .exterior, .interiorExtended:
                regions = [FoldPresentationRegion(x: 0, y: 0, width: width, height: height)]
            case let .interiorDivided(axis):
                switch axis {
                case .horizontal:
                    regions = [
                        FoldPresentationRegion(x: 0, y: 0, width: width / 2, height: height),
                        FoldPresentationRegion(x: width / 2, y: 0, width: width / 2, height: height)
                    ]
                case .vertical:
                    regions = [
                        FoldPresentationRegion(x: 0, y: 0, width: width, height: height / 2),
                        FoldPresentationRegion(x: 0, y: height / 2, width: width, height: height / 2)
                    ]
                }
            case .unknown, .interiorUnspecified:
                break
            }
            if !regions.isEmpty {
                regionMetadata = metadata
                regionSource = .windowBounds
                if case .interiorDivided = mode { regionSource = .appEqualSplit }
            }
            if case let .observed(geometry, geometryMetadata) = layoutGeometry,
               geometryMetadata.origin == metadata.origin,
               geometryMetadata.sequence == metadata.sequence {
                let resolved = FoldRegionResolver.resolve(mode: mode, geometry: geometry,
                    window: FoldPresentationRegion(x: 0, y: 0, width: width, height: height))
                regions = resolved.regions
                regionSource = resolved.source
                regionMetadata = regions.isEmpty ? nil : geometryMetadata
            }
        }
        let unobscured: (regions: [FoldPresentationRegion], truncated: Bool)
        if case let .observed(geometry, metadata) = layoutGeometry,
           metadata == regionMetadata, geometry.reservedRegionAPIAvailable {
            unobscured = FoldRegionResolver.subtractOcclusions(geometry.occlusions, from: regions)
        } else {
            // Without contemporaneous occlusion evidence, do not label regions unobscured.
            unobscured = ([], false)
        }
        return FoldPresentation(context: evidence.context, display: display, mode: mode,
                                requestedInteriorLayout: layout, hinge: hinge,
                                regions: regions, regionMetadata: regionMetadata,
                                regionSource: regionSource, layoutGeometry: layoutGeometry,
                                unobscuredRegions: unobscured.regions,
                                unobscuredRegionsTruncated: unobscured.truncated)
    }

    private static func matchesDuo(_ size: PixelSize, origin: EvidenceOrigin) -> Bool {
        duoDisplay(size, origin: origin) != .unknown
    }

    private static func inferDuo(
        evidence: FoldEvidence, hinge: (HingeSample, EvidenceMetadata)?,
        capability: FoldCapability, previousScreen: Observation<NativeScreenSize>?,
        interiorLayout: FoldInteriorLayout, reasons initialReasons: [AssessmentReason]
    ) -> FoldAssessment {
        var reasons = initialReasons
        func result(_ model: ModelInference) -> FoldAssessment {
            FoldAssessment(context: evidence.context, capability: capability, model: model,
                           presentation: presentation(evidence: evidence, model: model, layout: interiorLayout),
                           displayContext: evidence.displayContext, reasons: reasons)
        }
        guard let (screen, metadata) = current(
            evidence.nativeScreenSize, field: .nativeScreen, context: evidence.context, reasons: &reasons
        ) else { return result(.insufficientInformation) }
        guard metadata.origin == .system || metadata.origin == .simulator else {
            reasons.append(.runtimeOriginRequired(.nativeScreen))
            return result(.insufficientInformation)
        }
        guard screen.attribution == .deviceDisplay || screen.attribution == .applicationDisplay else {
            reasons.append(.screenAttributionUnsupported(.nativeScreen, screen.attribution))
            return result(.insufficientInformation)
        }
        if screen.attribution == .applicationDisplay { reasons.append(.displayIdentityUnverified) }
        if screen.captureState == .active {
            reasons.append(.sceneCaptureActive)
            return result(.insufficientInformation)
        }
        if screen.captureState == .unknown {
            reasons.append(.sceneCaptureUnknown)
            return result(.insufficientInformation)
        }
        guard matchesDuo(screen.pixels, origin: metadata.origin) else {
            reasons.append(.dimensionsDoNotMatch)
            return result(.insufficientInformation)
        }
        reasons.append(.dimensionsMatch)
        if let previousScreen {
            if case let .observed(old, oldMetadata) = previousScreen {
                if oldMetadata.context.sceneID != metadata.context.sceneID
                    || oldMetadata.context.windowID != metadata.context.windowID
                    || oldMetadata.context.generation > metadata.context.generation {
                    reasons.append(.contextMismatch(.previousScreen))
                } else if oldMetadata.origin != metadata.origin {
                    reasons.append(.originMismatch(.previousScreen))
                } else if old.attribution != screen.attribution {
                    reasons.append(.screenAttributionUnsupported(.previousScreen, old.attribution))
                } else if oldMetadata.sequence < metadata.sequence,
                          matchesDuo(old.pixels, origin: oldMetadata.origin), !sameDimensions(old.pixels, screen.pixels) {
                    reasons.append(.compatibleDimensionTransition)
                } else {
                    reasons.append(.transitionNotComparable)
                }
            } else if case let .missing(reason) = previousScreen {
                reasons.append(.missing(.previousScreen, reason))
            }
        }
        guard let (_, hingeMetadata) = hinge else {
            return result(.duoDimensionCandidate(origin: metadata.origin))
        }
        guard hingeMetadata.origin == metadata.origin else {
            reasons.append(.originMismatch(.hinge))
            return result(.duoDimensionCandidate(origin: metadata.origin))
        }
        return result(.duoInferred(origin: metadata.origin))
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
