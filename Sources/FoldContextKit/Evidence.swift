/// Ephemeral observer identity, never a hardware or account identifier.
/// Change generation when the window changes hierarchy or screen.
public struct ObservationContext: Equatable, Sendable {
    public let sceneID: String
    public let windowID: String
    public let generation: UInt64

    public init(sceneID: String, windowID: String, generation: UInt64) {
        self.sceneID = sceneID
        self.windowID = windowID
        self.generation = generation
    }
}

public enum EvidenceOrigin: Equatable, Sendable {
    case system
    case simulator
    case synthetic
    case unknown
}

public enum EvidenceValidity: Equatable, Sendable {
    /// Valid only in the context and generation recorded on the sample.
    case current
    /// Retained for explanation, not proof of the current presentation.
    case historical
}

/// Per-sample metadata: geometry and hinge callbacks need not arrive together.
public struct EvidenceMetadata: Equatable, Sendable {
    public let context: ObservationContext
    /// Increasing within an observation session; not a wall-clock timestamp.
    public let sequence: UInt64
    public let origin: EvidenceOrigin
    public let validity: EvidenceValidity

    public init(context: ObservationContext, sequence: UInt64,
                origin: EvidenceOrigin, validity: EvidenceValidity) {
        self.context = context
        self.sequence = sequence
        self.origin = origin
        self.validity = validity
    }
}

public enum MissingDataReason: Equatable, Sendable {
    case apiUnavailable
    case awaitingSample
    case observationSuspended
    /// A callback contained no value; this does not establish physical absence.
    case unavailableInContext
}

public enum Observation<Value: Equatable & Sendable>: Equatable, Sendable {
    case missing(MissingDataReason)
    case observed(Value, metadata: EvidenceMetadata)
}

/// Native screen pixels, deliberately distinct from presentation points.
public struct PixelSize: Equatable, Sendable {
    public let width: Int
    public let height: Int

    public init?(width: Int, height: Int) {
        guard width > 0, height > 0 else { return nil }
        self.width = width
        self.height = height
    }
}

/// Local presentation points. Zero is valid during layout.
public struct PointSize: Equatable, Sendable {
    public let width: Double
    public let height: Double

    public init?(width: Double, height: Double) {
        guard width.isFinite, height.isFinite, width >= 0, height >= 0 else { return nil }
        self.width = width
        self.height = height
    }
}

public enum PresentationSizeSource: Equatable, Sendable {
    case uiWindowBounds
    case uiViewBounds
    case swiftUIGeometry
}

public struct PresentationSize: Equatable, Sendable {
    public let points: PointSize
    public let source: PresentationSizeSource

    public init(points: PointSize, source: PresentationSizeSource) {
        self.points = points
        self.source = source
    }
}

public enum ScreenAttribution: Equatable, Sendable {
    case deviceDisplay
    case externalDisplay
    case mirrored
    case unknown
}

/// UIScreen.nativeBounds resolved from the observed window's scene.
/// Axes use the API's native reference orientation, not the window orientation.
public struct NativeScreenSize: Equatable, Sendable {
    public let pixels: PixelSize
    public let attribution: ScreenAttribution

    public init(pixels: PixelSize, attribution: ScreenAttribution) {
        self.pixels = pixels
        self.attribution = attribution
    }
}

public enum HingeStatus: Equatable, Sendable {
    case unknown
    case closed
    case partiallyOpen
    case fullyOpen
}

public enum HingeSource: Equatable, Sendable {
    case uiHingeInteraction
    case swiftUIHingeChange
}

public struct HingeSample: Equatable, Sendable {
    public let status: HingeStatus
    /// Nil means unavailable. No universal maximum opening angle is assumed.
    public let angleRadians: Double?
    public let source: HingeSource

    public init?(status: HingeStatus, angleRadians: Double?, source: HingeSource) {
        if let angleRadians, !angleRadians.isFinite { return nil }
        self.status = status
        self.angleRadians = angleRadians
        self.source = source
    }
}

/// Evidence only: no classification or observation side effects.
/// Each sample retains its context to expose stale or mismatched inputs.
public struct FoldEvidence: Equatable, Sendable {
    public let context: ObservationContext
    public let presentationSize: Observation<PresentationSize>
    public let nativeScreenSize: Observation<NativeScreenSize>
    public let hinge: Observation<HingeSample>

    public init(context: ObservationContext,
                presentationSize: Observation<PresentationSize>,
                nativeScreenSize: Observation<NativeScreenSize>,
                hinge: Observation<HingeSample>) {
        self.context = context
        self.presentationSize = presentationSize
        self.nativeScreenSize = nativeScreenSize
        self.hinge = hinge
    }
}
