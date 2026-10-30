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
    /// Screen resolved from a local application scene, not a certified physical display identity.
    case applicationDisplay
    case externalDisplay
    case mirrored
    case unknown
}

/// UIScreen.nativeBounds resolved from the observed window's scene.
/// Axes use the API's native reference orientation, not the window orientation.
public enum FoldCaptureState: Equatable, Sendable {
    case unknown
    case inactive
    /// Recording or mirroring; this does not identify iPhone Mirroring specifically.
    case active
}

public struct NativeScreenSize: Equatable, Sendable {
    public let pixels: PixelSize
    public let attribution: ScreenAttribution
    public let captureState: FoldCaptureState

    public init(pixels: PixelSize, attribution: ScreenAttribution, captureState: FoldCaptureState = .unknown) {
        self.pixels = pixels
        self.attribution = attribution
        self.captureState = captureState
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
    public let layoutGeometry: Observation<FoldLayoutGeometry>

    public init(context: ObservationContext,
                presentationSize: Observation<PresentationSize>,
                nativeScreenSize: Observation<NativeScreenSize>,
                hinge: Observation<HingeSample>,
                layoutGeometry: Observation<FoldLayoutGeometry> = .missing(.awaitingSample)) {
        self.context = context
        self.presentationSize = presentationSize
        self.nativeScreenSize = nativeScreenSize
        self.hinge = hinge
        self.layoutGeometry = layoutGeometry
    }
}

/// Which Duo panel is inferred to host this window, not a count of connected displays.
public enum FoldDisplay: Equatable, Sendable {
    case unknown
    case exterior
    case interior
}

public enum FoldRegionAxis: Equatable, Sendable {
    /// Two regions next to each other in window coordinates.
    case horizontal
    /// Two regions stacked in window coordinates.
    case vertical
}

/// Layout intent supplied by the app. Never inferred from hinge angle.
public enum FoldInteriorLayout: Equatable, Sendable {
    case unspecified
    case extended
    case divided(axis: FoldRegionAxis)
}

public enum FoldPresentationMode: Equatable, Sendable {
    case unknown
    case exterior
    case interiorUnspecified
    case interiorExtended
    case interiorDivided(axis: FoldRegionAxis)
}

/// A logical app region in UIWindow.bounds coordinates, measured in points.
/// Its provenance is described by FoldPresentation.regionSource.
public struct FoldPresentationRegion: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Per-window presentation inferred from evidence plus the app's layout intent.
public struct FoldPresentation: Equatable, Sendable {
    public let context: ObservationContext
    public let display: FoldDisplay
    public let mode: FoldPresentationMode
    public let requestedInteriorLayout: FoldInteriorLayout
    /// Current hinge observation, including missing-data reasons; no assumed posture.
    public let hinge: Observation<HingeSample>
    /// Empty if current window geometry is unavailable or the panel is unknown.
    public let regions: [FoldPresentationRegion]
    /// Metadata of the window measurement used to calculate the logical regions.
    public let regionMetadata: EvidenceMetadata?
    public let regionSource: FoldRegionSource
    /// Measured safe area, reserved division/occlusion frames and included margins.
    public let layoutGeometry: Observation<FoldLayoutGeometry>
    /// Content rectangles after excluding occlusions; may contain more than two rectangles.
    public let unobscuredRegions: [FoldPresentationRegion]
    public let unobscuredRegionsTruncated: Bool
}

public enum FoldRegionSource: Equatable, Sendable {
    case unavailable
    case windowBounds
    case safeArea
    case systemDivision
    /// Equal split requested by the app when no matching system division is available.
    case appEqualSplit
}

public struct FoldRegionMargins: Equatable, Sendable {
    public let top: Double
    public let left: Double
    public let bottom: Double
    public let right: Double

    public init(top: Double, left: Double, bottom: Double, right: Double) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }
}

public struct FoldReservedRegion: Equatable, Sendable {
    /// Includes system margins. Coordinates are in the observed window, in points.
    public let frame: FoldPresentationRegion
    public let margins: FoldRegionMargins

    public init(frame: FoldPresentationRegion, margins: FoldRegionMargins) {
        self.frame = frame
        self.margins = margins
    }
}

public struct FoldLayoutGeometry: Equatable, Sendable {
    /// Visible safe area of the observed root, converted into window coordinates.
    public let safeArea: FoldPresentationRegion
    /// Active regions from UIView.reservedRegions(kind:), including margins.
    public let divisions: [FoldReservedRegion]
    public let occlusions: [FoldReservedRegion]
    public let reservedRegionAPIAvailable: Bool

    public init(safeArea: FoldPresentationRegion, divisions: [FoldReservedRegion],
                occlusions: [FoldReservedRegion], reservedRegionAPIAvailable: Bool) {
        self.safeArea = safeArea
        self.divisions = divisions
        self.occlusions = occlusions
        self.reservedRegionAPIAvailable = reservedRegionAPIAvailable
    }
}

/// What public presentation signals establish, independent of inferred device model.
public enum FoldDisplayContext: Equatable, Sendable {
    case deviceDisplay
    case externalDisplay
    /// Receiver identified by UIScreen.mirrored, not specifically iPhone Mirroring.
    case mirroringReceiver
    /// Capture API deliberately does not identify which capture feature is in use.
    case recordingOrMirroring
    /// Application role can also occur on an interactive external display.
    case applicationDisplayUnresolved
    case unknown
}

extension FoldEvidence {
    /// Current context evidence with its original provenance. No global screen lookup.
    public var displayContext: Observation<FoldDisplayContext> {
        switch nativeScreenSize {
        case let .missing(reason):
            return .missing(reason)
        case let .observed(screen, metadata):
            guard metadata.context == context, metadata.validity == .current,
                  metadata.origin != .unknown else { return .missing(.unavailableInContext) }
            let value: FoldDisplayContext
            if screen.attribution == .mirrored {
                value = .mirroringReceiver
            } else if screen.attribution == .externalDisplay {
                value = .externalDisplay
            } else if screen.captureState == .active {
                value = .recordingOrMirroring
            } else if screen.captureState == .unknown {
                value = .unknown
            } else {
                switch screen.attribution {
                case .deviceDisplay: value = .deviceDisplay
                case .applicationDisplay: value = .applicationDisplayUnresolved
                case .externalDisplay: value = .externalDisplay
                case .mirrored: value = .mirroringReceiver
                case .unknown: value = .unknown
                }
            }
            return .observed(value, metadata: metadata)
        }
    }
}
