import Testing
@testable import FoldContextKit

// Controlled inputs with declared origins exercise rules, not simulator/hardware behavior.
private struct PresentationFixture {
    let context = ObservationContext(sceneID: "presentation-scene", windowID: "presentation-window", generation: 1)
    var metadata: EvidenceMetadata {
        EvidenceMetadata(context: context, sequence: 2, origin: .simulator, validity: .current)
    }
    let safe = FoldPresentationRegion(x: 10, y: 20, width: 780, height: 560)

    func evidence(interior: Bool = true, rotated: Bool = false,
                  capture: FoldCaptureState = .inactive,
                  attribution: ScreenAttribution = .applicationDisplay,
                  hingePresent: Bool = true, geometry: FoldLayoutGeometry? = nil,
                  geometryMetadata: EvidenceMetadata? = nil) throws -> FoldEvidence {
        let w = interior ? 2007 : 1398
        let h = interior ? 2853 : 2034
        let pixels = try #require(PixelSize(width: rotated ? h : w, height: rotated ? w : h))
        let points = try #require(PointSize(width: 800, height: 600))
        let hinge = try #require(HingeSample(status: .partiallyOpen, angleRadians: .pi / 2, source: .uiHingeInteraction))
        return FoldEvidence(context: context,
            presentationSize: .observed(PresentationSize(points: points, source: .uiWindowBounds), metadata: metadata),
            nativeScreenSize: .observed(NativeScreenSize(pixels: pixels, attribution: attribution, captureState: capture), metadata: metadata),
            hinge: hingePresent ? .observed(hinge, metadata: metadata) : .missing(.awaitingSample),
            layoutGeometry: geometry.map { .observed($0, metadata: geometryMetadata ?? metadata) } ?? .missing(.awaitingSample))
    }

    func geometry(divisions: [FoldReservedRegion] = [], occlusions: [FoldReservedRegion] = [],
                  available: Bool = true) -> FoldLayoutGeometry {
        FoldLayoutGeometry(safeArea: safe, divisions: divisions, occlusions: occlusions,
                           reservedRegionAPIAvailable: available)
    }
    func reserved(_ frame: FoldPresentationRegion) -> FoldReservedRegion {
        FoldReservedRegion(frame: frame, margins: FoldRegionMargins(top: 0, left: 0, bottom: 0, right: 0))
    }
}

@Test func duoInferenceAndPanelRespectEvidenceAndRotation() throws {
    let f = PresentationFixture()
    for interior in [false, true] {
        for rotated in [false, true] {
            let input = try f.evidence(interior: interior, rotated: rotated)
            let result = FoldClassifier.evaluate(evidence: input, interiorLayout: .extended)
            #expect(result.model == .duoInferred(origin: .simulator))
            #expect(result.presentation.display == (interior ? .interior : .exterior))
            #expect(result.presentation.mode == (interior ? .interiorExtended : .exterior))
            #expect(result.reasons.contains(.displayIdentityUnverified))
            #expect(!result.reasons.contains(.compatibleDimensionTransition))
        }
    }
    let candidate = FoldClassifier.evaluate(evidence: try f.evidence(hingePresent: false))
    #expect(candidate.model == .duoDimensionCandidate(origin: .simulator))
    #expect(candidate.presentation.display == .unknown)
    #expect(candidate.presentation.regions.isEmpty)
}

@Test func captureAndExternalContextsBlockDuoInference() throws {
    let f = PresentationFixture()
    for state in [FoldCaptureState.active, .unknown] {
        let result = FoldClassifier.evaluate(evidence: try f.evidence(capture: state))
        #expect(result.model == .insufficientInformation)
        #expect(result.capability == .hingeObserved(origin: .simulator))
        #expect(result.reasons.contains(state == .active ? .sceneCaptureActive : .sceneCaptureUnknown))
    }
    for attribution in [ScreenAttribution.externalDisplay, .mirrored, .unknown] {
        let result = FoldClassifier.evaluate(evidence: try f.evidence(attribution: attribution))
        #expect(result.model == .insufficientInformation)
        #expect(result.reasons.contains(.screenAttributionUnsupported(.nativeScreen, attribution)))
    }
    let captured = try f.evidence(capture: .active)
    #expect(captured.displayContext == .observed(.recordingOrMirroring, metadata: f.metadata))
    #expect(try f.evidence().displayContext == .observed(.applicationDisplayUnresolved, metadata: f.metadata))
}

@Test func layoutChoiceDoesNotFollowHingeAngle() throws {
    let f = PresentationFixture()
    let input = try f.evidence(geometry: f.geometry())
    let unspecified = FoldClassifier.evaluate(evidence: input)
    #expect(unspecified.presentation.mode == .interiorUnspecified)
    #expect(unspecified.presentation.regions.isEmpty)
    let extended = FoldClassifier.evaluate(evidence: input, interiorLayout: .extended)
    #expect(extended.presentation.regions == [f.safe])
    #expect(extended.presentation.regionSource == .safeArea)
    #expect(extended.presentation.unobscuredRegions == [f.safe])
    for axis in [FoldRegionAxis.horizontal, .vertical] {
        let divided = FoldClassifier.evaluate(evidence: input, interiorLayout: .divided(axis: axis))
        #expect(divided.presentation.mode == .interiorDivided(axis: axis))
        #expect(divided.presentation.regionSource == .appEqualSplit)
        #expect(divided.presentation.regions.count == 2)
        #expect(divided.model == extended.model)
        #expect(divided.presentation.hinge == extended.presentation.hinge)
    }
}

@Test func measuredDivisionOverridesEqualHalvesAndKeepsMargins() throws {
    let f = PresentationFixture()
    let band = f.reserved(FoldPresentationRegion(x: 300, y: 0, width: 24, height: 600))
    let result = FoldClassifier.evaluate(evidence: try f.evidence(geometry: f.geometry(divisions: [band])),
                                         interiorLayout: .divided(axis: .horizontal))
    #expect(result.presentation.regionSource == .systemDivision)
    #expect(result.presentation.regions == [
        FoldPresentationRegion(x: 10, y: 20, width: 290, height: 560),
        FoldPresentationRegion(x: 324, y: 20, width: 466, height: 560)
    ])
    let horizontal = f.reserved(FoldPresentationRegion(x: 0, y: 200, width: 800, height: 12))
    let vertical = FoldClassifier.evaluate(evidence: try f.evidence(geometry: f.geometry(divisions: [horizontal])),
                                           interiorLayout: .divided(axis: .vertical))
    #expect(vertical.presentation.regionSource == .systemDivision)
    #expect(vertical.presentation.regions.map(\.height) == [180, 368])
}

@Test func occlusionsAreExcludedWithoutLosingUnobscuredArea() throws {
    let f = PresentationFixture()
    let cut = f.reserved(FoldPresentationRegion(x: 100, y: 100, width: 50, height: 60))
    let result = FoldClassifier.evaluate(evidence: try f.evidence(geometry: f.geometry(occlusions: [cut])),
                                         interiorLayout: .extended)
    let pieces = result.presentation.unobscuredRegions
    #expect(pieces.count == 4)
    #expect(pieces.reduce(0) { $0 + $1.width * $1.height } == 780 * 560 - 50 * 60)
    for r in pieces {
        #expect(r.x + r.width <= 100 || r.x >= 150 || r.y + r.height <= 100 || r.y >= 160)
    }
    #expect(!result.presentation.unobscuredRegionsTruncated)
    let unavailable = FoldClassifier.evaluate(evidence: try f.evidence(geometry: f.geometry(available: false)),
                                              interiorLayout: .extended)
    #expect(unavailable.presentation.unobscuredRegions.isEmpty)
}

@Test func staleOrForeignGeometryCannotSupplySafeRegions() throws {
    let f = PresentationFixture()
    let foreign = ObservationContext(sceneID: "other-scene", windowID: "other-window", generation: 1)
    for metadata in [
        EvidenceMetadata(context: f.context, sequence: 2, origin: .simulator, validity: .historical),
        EvidenceMetadata(context: foreign, sequence: 2, origin: .simulator, validity: .current),
        EvidenceMetadata(context: f.context, sequence: 1, origin: .simulator, validity: .current),
        EvidenceMetadata(context: f.context, sequence: 2, origin: .system, validity: .current)
    ] {
        let result = FoldClassifier.evaluate(evidence: try f.evidence(geometry: f.geometry(), geometryMetadata: metadata),
                                             interiorLayout: .extended)
        #expect(result.presentation.regionSource == .windowBounds)
        #expect(result.presentation.unobscuredRegions.isEmpty)
    }
    let event = historicalEvent(.snapshot(try f.evidence(geometry: f.geometry()), change: .geometry))
    guard case let .snapshot(old, _) = event else { Issue.record("Missing snapshot"); return }
    #expect(FoldClassifier.evaluate(evidence: old).model == .insufficientInformation)
    if case let .observed(_, metadata) = old.layoutGeometry { #expect(metadata.validity == .historical) }
    else { Issue.record("Missing historical geometry") }
}

@Test func fragmentedRegionsAreBoundedAndRemainOutsideOcclusions() {
    let f = PresentationFixture()
    let base = FoldPresentationRegion(x: 0, y: 0, width: 1000, height: 1000)
    let occlusions = (1...40).map { i in
        f.reserved(FoldPresentationRegion(x: Double(i * 20), y: 0, width: 2, height: 1000))
    }
    let result = FoldRegionResolver.subtractOcclusions(occlusions, from: [base])
    #expect(result.truncated)
    #expect(result.regions.count <= 32)
    for r in result.regions {
        for cut in occlusions {
            #expect(r.x + r.width <= cut.frame.x || r.x >= cut.frame.x + cut.frame.width)
        }
    }
}

// Regression for the recorded simulator interior size. These are controlled
// rule tests; runtime posture validation is recorded separately.
@Test(arguments: [HingeStatus.closed, .partiallyOpen, .fullyOpen])
func recordedSimulatorInteriorPreservesPostureAndLayout(status: HingeStatus) throws {
    let f = PresentationFixture()
    let base = try f.evidence(geometry: f.geometry())
    let hinge = try #require(HingeSample(status: status,
        angleRadians: status == .closed ? 0 : status == .fullyOpen ? .pi : .pi / 2,
        source: .uiHingeInteraction))
    let input = FoldEvidence(context: base.context, presentationSize: base.presentationSize,
        nativeScreenSize: base.nativeScreenSize,
        hinge: .observed(hinge, metadata: f.metadata), layoutGeometry: base.layoutGeometry)
    for layout in [FoldInteriorLayout.extended, .divided(axis: .horizontal), .divided(axis: .vertical)] {
        let result = FoldClassifier.evaluate(evidence: input, interiorLayout: layout)
        #expect(result.model == .duoInferred(origin: .simulator))
        #expect(result.presentation.display == .interior)
        #expect(result.presentation.hinge == input.hinge)
        #expect(result.presentation.regions.count == (layout == .extended ? 1 : 2))
    }
}

@Test(arguments: [EvidenceOrigin.system, .simulator])
func simulatorInteriorProfileDoesNotExpandPhysicalProfile(origin: EvidenceOrigin) throws {
    let f = PresentationFixture()
    let metadata = EvidenceMetadata(context: f.context, sequence: 1, origin: origin, validity: .current)
    let hinge = try #require(HingeSample(status: .fullyOpen, angleRadians: .pi, source: .uiHingeInteraction))
    for rotated in [false, true] {
        let pixels = try #require(PixelSize(width: rotated ? 2853 : 2007, height: rotated ? 2007 : 2853))
        let input = FoldEvidence(context: f.context, presentationSize: .missing(.awaitingSample),
            nativeScreenSize: .observed(NativeScreenSize(pixels: pixels,
                attribution: .applicationDisplay, captureState: .inactive), metadata: metadata),
            hinge: .observed(hinge, metadata: metadata))
        let result = FoldClassifier.evaluate(evidence: input)
        #expect(result.model == (origin == .simulator ? .duoInferred(origin: .simulator) : .insufficientInformation))
        #expect(result.presentation.display == (origin == .simulator ? .interior : .unknown))
    }
}

@Test func originalInteriorProfileRemainsCompatible() throws {
    let f = PresentationFixture()
    let pixels = try #require(PixelSize(width: 1878, height: 2670))
    let hinge = try #require(HingeSample(status: .fullyOpen, angleRadians: .pi, source: .uiHingeInteraction))
    let input = FoldEvidence(context: f.context, presentationSize: .missing(.awaitingSample),
        nativeScreenSize: .observed(NativeScreenSize(pixels: pixels, attribution: .applicationDisplay,
            captureState: .inactive), metadata: f.metadata),
        hinge: .observed(hinge, metadata: f.metadata))
    #expect(FoldClassifier.evaluate(evidence: input).presentation.display == .interior)
}
