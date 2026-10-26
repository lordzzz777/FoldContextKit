import FoldContextKit
import Testing

private struct Fixture {
    let context = ObservationContext(sceneID: "session-scene", windowID: "window", generation: 1)
    let first: PixelSize
    let second: PixelSize
    let policy: ClassificationPolicy

    init() throws {
        first = try #require(PixelSize(width: 100, height: 200))
        second = try #require(PixelSize(width: 300, height: 400))
        policy = .synthetic(try #require(SyntheticDimensionProfile(first: first, second: second)))
    }

    func metadata(context: ObservationContext? = nil, origin: EvidenceOrigin = .synthetic,
                  validity: EvidenceValidity = .current, sequence: UInt64 = 2) -> EvidenceMetadata {
        EvidenceMetadata(context: context ?? self.context, sequence: sequence, origin: origin, validity: validity)
    }

    func screen(_ size: PixelSize? = nil, attribution: ScreenAttribution = .deviceDisplay,
                metadata: EvidenceMetadata? = nil) -> Observation<NativeScreenSize> {
        .observed(NativeScreenSize(pixels: size ?? first, attribution: attribution),
                  metadata: metadata ?? self.metadata())
    }

    func hinge(status: HingeStatus = .fullyOpen, source: HingeSource = .uiHingeInteraction,
               metadata: EvidenceMetadata? = nil) throws -> Observation<HingeSample> {
        .observed(try #require(HingeSample(status: status, angleRadians: nil, source: source)),
                  metadata: metadata ?? self.metadata())
    }

    func evidence(screen: Observation<NativeScreenSize> = .missing(.awaitingSample),
                  hinge: Observation<HingeSample> = .missing(.awaitingSample),
                  presentation: Observation<PresentationSize> = .missing(.awaitingSample)) -> FoldEvidence {
        FoldEvidence(context: context, presentationSize: presentation, nativeScreenSize: screen, hinge: hinge)
    }
}

@Test(arguments: [MissingDataReason.apiUnavailable, .awaitingSample, .observationSuspended, .unavailableInContext])
func missingHingeNeverMeansPhysicalAbsence(_ reason: MissingDataReason) throws {
    let f = try Fixture()
    let result = FoldClassifier.evaluate(evidence: f.evidence(screen: f.screen(), hinge: .missing(reason)), policy: f.policy)
    #expect(result.capability == .unknown)
    #expect(result.model == .syntheticDimensionCandidate)
    #expect(result.reasons.contains(.missing(.hinge, reason)))
}

@Test(arguments: [HingeStatus.unknown, .closed, .partiallyOpen, .fullyOpen])
func hingeWithoutDimensionsObservesCapabilityOnly(_ status: HingeStatus) throws {
    let f = try Fixture()
    let result = FoldClassifier.evaluate(evidence: f.evidence(hinge: try f.hinge(status: status)), policy: f.policy)
    #expect(result.capability == .hingeObserved(origin: .synthetic))
    #expect(result.model == .insufficientInformation)
    #expect(result.reasons.contains(.hingeStatusUnknown) == (status == .unknown))
}

@Test func policyIsExplicitAndObservationOnlyCannotInfer() throws {
    let f = try Fixture()
    let input = f.evidence(screen: f.screen(), hinge: try f.hinge())
    let result = FoldClassifier.evaluate(evidence: input, policy: .observationOnly)
    #expect(result.model == .insufficientInformation)
    #expect(result.reasons.contains(.modelInferenceDisabled))
    #expect(result.capability == .hingeObserved(origin: .synthetic))
}

@Test(arguments: [HingeSource.uiHingeInteraction, .swiftUIHingeChange])
func syntheticCombinationNeedsNoInitialTransition(_ source: HingeSource) throws {
    let f = try Fixture()
    for size in [f.first, f.second] {
        let input = f.evidence(screen: f.screen(size), hinge: try f.hinge(source: source))
        let result = FoldClassifier.evaluate(evidence: input, policy: f.policy)
        #expect(result.model == .syntheticDuoInference)
        #expect(!result.reasons.contains(.compatibleDimensionTransition))
        #expect(result == FoldClassifier.evaluate(evidence: input, policy: f.policy))
    }
}

@Test func contradictoryDimensionsBlockInference() throws {
    let f = try Fixture()
    let other = try #require(PixelSize(width: 101, height: 200))
    let result = FoldClassifier.evaluate(evidence: f.evidence(screen: f.screen(other), hinge: try f.hinge()), policy: f.policy)
    #expect(result.model == .insufficientInformation)
    #expect(result.capability == .hingeObserved(origin: .synthetic))
    #expect(result.reasons.contains(.dimensionsDoNotMatch))
}

@Test func rotationMatchesButDoesNotBecomeATransition() throws {
    let f = try Fixture()
    let rotated = try #require(PixelSize(width: 200, height: 100))
    #expect(SyntheticDimensionProfile(first: f.first, second: rotated) == nil)
    let result = FoldClassifier.evaluate(
        evidence: f.evidence(screen: f.screen(rotated)), policy: f.policy,
        previousScreen: f.screen(metadata: f.metadata(validity: .historical, sequence: 1))
    )
    #expect(result.model == .syntheticDimensionCandidate)
    #expect(result.reasons.contains(.transitionNotComparable))
}

@Test(arguments: [PresentationSizeSource.uiWindowBounds, .uiViewBounds, .swiftUIGeometry])
func pointsCannotSubstituteForNativePixels(_ source: PresentationSizeSource) throws {
    let f = try Fixture()
    let points = try #require(PointSize(width: 100, height: 200))
    let presentation: Observation<PresentationSize> = .observed(
        PresentationSize(points: points, source: source), metadata: f.metadata()
    )
    let result = FoldClassifier.evaluate(
        evidence: f.evidence(hinge: try f.hinge(), presentation: presentation), policy: f.policy
    )
    #expect(result.model == .insufficientInformation)
    #expect(result.reasons.contains(.missing(.nativeScreen, .awaitingSample)))
}

@Test func transitionIsDependentAndNeverPromotesModel() throws {
    let f = try Fixture()
    let oldContext = ObservationContext(sceneID: f.context.sceneID, windowID: f.context.windowID, generation: 0)
    let previous = f.screen(metadata: f.metadata(context: oldContext, validity: .historical, sequence: 1))
    for hinge in [Observation<HingeSample>.missing(.awaitingSample), try f.hinge()] {
        let input = f.evidence(screen: f.screen(f.second), hinge: hinge)
        let baseline = FoldClassifier.evaluate(evidence: input, policy: f.policy)
        let result = FoldClassifier.evaluate(evidence: input, policy: f.policy, previousScreen: previous)
        #expect(result.model == baseline.model)
        #expect(result.reasons.contains(.compatibleDimensionTransition))
    }
    let noCurrentDimensions = FoldClassifier.evaluate(evidence: f.evidence(), policy: f.policy, previousScreen: previous)
    #expect(noCurrentDimensions.model == .insufficientInformation)
    #expect(!noCurrentDimensions.reasons.contains(.compatibleDimensionTransition))
}

@Test func historicalSamplesCannotActAsCurrentEvidence() throws {
    let f = try Fixture()
    let old = f.metadata(validity: .historical)
    let hingeResult = FoldClassifier.evaluate(evidence: f.evidence(screen: f.screen(), hinge: try f.hinge(metadata: old)), policy: f.policy)
    #expect(hingeResult.model == .syntheticDimensionCandidate)
    #expect(hingeResult.capability == .unknown)
    #expect(hingeResult.reasons.contains(.historical(.hinge)))
    let screenResult = FoldClassifier.evaluate(evidence: f.evidence(screen: f.screen(metadata: old), hinge: try f.hinge()), policy: f.policy)
    #expect(screenResult.model == .insufficientInformation)
    #expect(screenResult.reasons.contains(.historical(.nativeScreen)))
}

@Test func sceneWindowAndGenerationMismatchesAreRejected() throws {
    let f = try Fixture()
    let contexts = [
        ObservationContext(sceneID: "other", windowID: "window", generation: 1),
        ObservationContext(sceneID: "session-scene", windowID: "other", generation: 1),
        ObservationContext(sceneID: "session-scene", windowID: "window", generation: 0)
    ]
    for context in contexts {
        let metadata = f.metadata(context: context)
        let hingeResult = FoldClassifier.evaluate(evidence: f.evidence(screen: f.screen(), hinge: try f.hinge(metadata: metadata)), policy: f.policy)
        #expect(hingeResult.model == .syntheticDimensionCandidate)
        #expect(hingeResult.reasons.contains(.contextMismatch(.hinge)))
        let screenResult = FoldClassifier.evaluate(evidence: f.evidence(screen: f.screen(metadata: metadata), hinge: try f.hinge()), policy: f.policy)
        #expect(screenResult.model == .insufficientInformation)
        #expect(screenResult.reasons.contains(.contextMismatch(.nativeScreen)))
    }
}

@Test(arguments: [ScreenAttribution.unknown, .externalDisplay, .mirrored])
func screenAttributionBlocksInference(_ attribution: ScreenAttribution) throws {
    let f = try Fixture()
    let result = FoldClassifier.evaluate(evidence: f.evidence(screen: f.screen(attribution: attribution), hinge: try f.hinge()), policy: f.policy)
    #expect(result.model == .insufficientInformation)
    #expect(result.reasons.contains(.screenAttributionUnsupported(.nativeScreen, attribution)))
}

@Test(arguments: [EvidenceOrigin.system, .simulator, .unknown])
func nonsyntheticSourcesCannotProduceSyntheticInference(_ origin: EvidenceOrigin) throws {
    let f = try Fixture()
    let metadata = f.metadata(origin: origin)
    let screenResult = FoldClassifier.evaluate(evidence: f.evidence(screen: f.screen(metadata: metadata), hinge: try f.hinge()), policy: f.policy)
    #expect(screenResult.model == .insufficientInformation)
    let hingeResult = FoldClassifier.evaluate(evidence: f.evidence(screen: f.screen(), hinge: try f.hinge(metadata: metadata)), policy: f.policy)
    #expect(hingeResult.model == .syntheticDimensionCandidate)
    #expect(hingeResult.reasons.contains(origin == .unknown ? .unknownOrigin(.hinge) : .syntheticOriginRequired(.hinge)))
}

@Test func invalidHistoryAddsNoTransitionAndDoesNotOverrideCurrentEvidence() throws {
    let f = try Fixture()
    let other = ObservationContext(sceneID: "other", windowID: "window", generation: 0)
    let otherWindow = ObservationContext(sceneID: f.context.sceneID, windowID: "other", generation: 0)
    let future = ObservationContext(sceneID: f.context.sceneID, windowID: f.context.windowID, generation: 2)
    let wrongSize = try #require(PixelSize(width: 9, height: 10))
    let histories: [Observation<NativeScreenSize>] = [
        .missing(.unavailableInContext),
        f.screen(metadata: f.metadata(context: other, sequence: 1)),
        f.screen(metadata: f.metadata(context: otherWindow, sequence: 1)),
        f.screen(metadata: f.metadata(context: future, sequence: 1)),
        f.screen(metadata: f.metadata(origin: .system, sequence: 1)),
        f.screen(attribution: .unknown, metadata: f.metadata(sequence: 1)),
        f.screen(metadata: f.metadata(sequence: 2)),
        f.screen(metadata: f.metadata(sequence: 3)),
        f.screen(wrongSize, metadata: f.metadata(sequence: 1))
    ]
    for previous in histories {
        let result = FoldClassifier.evaluate(
            evidence: f.evidence(screen: f.screen(f.second), hinge: try f.hinge()),
            policy: f.policy, previousScreen: previous
        )
        #expect(result.model == .syntheticDuoInference)
        #expect(!result.reasons.contains(.compatibleDimensionTransition))
    }
}
