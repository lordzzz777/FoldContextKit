import FoldContextKit

let context = ObservationContext(sceneID: "fixture", windowID: "window", generation: 0)
let evidence = FoldEvidence(
    context: context,
    presentationSize: .missing(.awaitingSample),
    nativeScreenSize: .missing(.awaitingSample),
    hinge: .missing(.apiUnavailable)
)
precondition(evidence.hinge == .missing(.apiUnavailable))
print("FoldContextKit local import OK (synthetic input, no hardware observation)")
