// swiftlint:disable all
#if os(macOS)
import Foundation
import Testing
@testable import SuperwallKit

/// Audience filters run through Superscript's native code, which ships a macOS slice.
@Suite(.serialized)
struct SuperscriptMacTests {
  @Test
  func evaluatesAudienceExpression() async {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.reset()
    let evaluator = CELEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    dependencyContainer.identityManager.mergeUserAttributes(["a": "b"])
    let placement = PlacementData(name: "ss", parameters: [:], createdAt: Date())

    let matching: TriggerRule = .stub()
      .setting(\.expression, to: "user.a == \"b\"")
    let matchResult = await evaluator.evaluateExpression(
      fromAudienceFilter: matching,
      placementData: placement
    )
    #expect(matchResult == .match(audience: matching))

    let failing: TriggerRule = .stub()
      .setting(\.expression, to: "user.a == \"c\"")
    let failResult = await evaluator.evaluateExpression(
      fromAudienceFilter: failing,
      placementData: placement
    )
    #expect(failResult != .match(audience: failing))
  }
}
#endif
