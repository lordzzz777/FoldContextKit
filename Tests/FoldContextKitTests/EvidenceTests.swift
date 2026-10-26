import FoldContextKit
import Testing

@Test func rejectsInvalidMeasurements() {
    #expect(PixelSize(width: 0, height: 100) == nil)
    #expect(PixelSize(width: -1, height: 100) == nil)
    #expect(PointSize(width: .infinity, height: 100) == nil)
    #expect(PointSize(width: 100, height: .nan) == nil)
    #expect(PointSize(width: -1, height: 100) == nil)
    #expect(PointSize(width: 0, height: 0) != nil)
    #expect(HingeSample(status: .unknown, angleRadians: .nan, source: .uiHingeInteraction) == nil)
    #expect(HingeSample(status: .unknown, angleRadians: nil, source: .uiHingeInteraction) != nil)
}

@Test func missingDataDoesNotCollapseIntoOneState() {
    let reasons: [MissingDataReason] = [
        .apiUnavailable, .awaitingSample, .observationSuspended, .unavailableInContext
    ]
    for (index, reason) in reasons.enumerated() {
        let value: Observation<HingeSample> = .missing(reason)
        for other in reasons.dropFirst(index + 1) {
            #expect(value != .missing(other))
        }
    }
}

@Test func historicalEvidenceRetainsItsOwnWindowAndGeneration() throws {
    let oldContext = ObservationContext(sceneID: "scene", windowID: "first", generation: 0)
    let newContext = ObservationContext(sceneID: "scene", windowID: "second", generation: 1)
    let sample = try #require(HingeSample(
        status: .fullyOpen, angleRadians: 3, source: .uiHingeInteraction
    ))
    let metadata = EvidenceMetadata(
        context: oldContext, sequence: 1, origin: .synthetic, validity: .historical
    )
    let evidence = FoldEvidence(
        context: newContext,
        presentationSize: .missing(.awaitingSample),
        nativeScreenSize: .missing(.awaitingSample),
        hinge: .observed(sample, metadata: metadata)
    )
    guard case let .observed(_, recorded) = evidence.hinge else {
        Issue.record("Expected retained historical evidence")
        return
    }
    #expect(recorded.context != evidence.context)
    #expect(recorded.validity == .historical)
    #expect(recorded.origin == .synthetic)
}
