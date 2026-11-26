//
//  CELEvaluatorTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 14/10/2024.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

@Suite(.serialized)
struct CELEvaluatorTests {
  @Test func evaluateExpression_expressionMatchesAll() async {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.reset()
    let evaluator = CELEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )

    let rule: TriggerRule = .stub()
      .setting(\.expression, to: nil)
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: .stub()
    )

    #expect(result == .match(audience: rule))
  }

  @Test func evaluateExpression_expressionTrue() async {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.reset()
    let evaluator = CELEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    dependencyContainer.identityManager.mergeUserAttributes(["a": "b"])
    let rule: TriggerRule = .stub()
      .setting(\.expression, to: "user.a == \"b\"")
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: PlacementData(name: "ss", parameters: [:], createdAt: Date())
    )

    #expect(result == .match(audience: rule))
  }

  @Test func evaluateExpression_expression_withOccurrence() async {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.reset()
    let evaluator = CELEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    dependencyContainer.identityManager.mergeUserAttributes(["a": "b"])
    let occurrence = TriggerAudienceOccurrence(key: "a", maxCount: 1, interval: .infinity)
    let rule: TriggerRule = .stub()
      .setting(\.expression, to: "user.a == \"b\"")
      .setting(\.occurrence, to: occurrence)
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: PlacementData(name: "ss", parameters: [:], createdAt: Date())
    )

    #expect(result == .match(audience: rule, unsavedOccurrence: occurrence))
  }

  @Test func evaluateExpression_expressionParams() async {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.reset()
    let evaluator = CELEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    dependencyContainer.identityManager.mergeUserAttributes([:])
    let rule: TriggerRule = .stub()
      .setting(\.expression, to: "params.a == \"b\"")
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: PlacementData(name: "ss", parameters: ["a": "b"], createdAt: Date())
    )
    #expect(result == .match(audience: rule))
  }

  @Test func evaluateExpression_expressionDeviceTrue() async {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.reset()
    let evaluator = CELEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    dependencyContainer.identityManager.mergeUserAttributes([:])
    let rule: TriggerRule = .stub()
      .setting(\.expression, to: "device.platform == \"iOS\"")
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: PlacementData(name: "ss", parameters: ["a": "b"], createdAt: Date())
    )
    #expect(result == .match(audience: rule))
  }

  @Test func evaluateExpression_expressionDeviceFalse() async {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.reset()
    let evaluator = CELEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    dependencyContainer.identityManager.mergeUserAttributes([:])
    let rule: TriggerRule = .stub()
      .setting(\.expression, to: "device.platform == \"Android\"")
    let result = await evaluator.evaluateExpression(
        fromAudienceFilter: rule,
      placementData: PlacementData(name: "ss", parameters: ["a": "b"], createdAt: Date())
    )
    #expect(result == .noMatch(source: .expression, experimentId: rule.experiment.id))
  }

  @Test func evaluateExpression_expressionFalse() async {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.reset()
    let evaluator = CELEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    dependencyContainer.identityManager.mergeUserAttributes([:])
    let rule: TriggerRule = .stub()
      .setting(\.expression, to: "a == \"b\"")
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: .stub()
    )
    #expect(result == .noMatch(source: .expression, experimentId: rule.experiment.id))
  }

  @Test func evaluateExpression_unresolvableFunctionArgument_noMatch() async {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.reset()
    let evaluator = CELEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    dependencyContainer.identityManager.mergeUserAttributes([:])
    // A function argument that fails to resolve must degrade to noMatch —
    // Superscript < 1.0.15 aborted the process when evaluating this.
    let rule: TriggerRule = .stub()
      .setting(\.expression, to: "daysSince(app_install) >= 1")
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: .stub()
    )
    #expect(result == .noMatch(source: .expression, experimentId: rule.experiment.id))
  }

  @Test func evaluateExpression_noEntitlements_match() async {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.reset()
    dependencyContainer.entitlementsInfo.subscriptionStatusDidSet(.inactive)
    let evaluator = CELEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    print("device entitlements", dependencyContainer.entitlementsInfo.active)
    let rule: TriggerRule = .stub()
      .setting(\.expression, to: "size(device.activeEntitlements) == 0")
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: .stub()
    )
    #expect(result == .match(audience: rule))
  }

  @Test func evaluateExpression_noEntitlements_noMatch() async {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.reset()
    dependencyContainer.entitlementsInfo.subscriptionStatusDidSet(.active([.stub()]))
    let evaluator = CELEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    let rule: TriggerRule = .stub()
      .setting(\.expression, to: "size(device.activeEntitlements) == 0")
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: .stub()
    )
    #expect(result == .noMatch(source: .expression, experimentId: rule.experiment.id))
  }

  @Test func evaluateExpression_containsSpecificEntitlement() async {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.reset()
    dependencyContainer.entitlementsInfo.subscriptionStatusDidSet(.active([.init(id: "bronze")]))
    let evaluator = CELEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    let rule: TriggerRule = .stub()
      .setting(\.expression, to: "[\"bronze\"].all(identifier, device.activeEntitlements.contains(identifier))")
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: .stub()
    )
    #expect(result == .match(audience: rule))
  }
  @Test func evaluateExpression_passingInDecimal() async {
    let dependencyContainer = DependencyContainer()
    dependencyContainer.storage.reset()
    let evaluator = CELEvaluator(
      storage: dependencyContainer.storage,
      factory: dependencyContainer
    )
    let value = Decimal(1.0)
    dependencyContainer.identityManager.mergeUserAttributes(["a": value])
    let rule: TriggerRule = .stub()
      .setting(\.expression, to: "user.a == 1.0")
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: PlacementData(name: "ss", parameters: [:], createdAt: Date())
    )

    #expect(result == .match(audience: rule))
  }

  @Test(arguments: [(0, true), (2, true), (3, false)])
  func evaluateExpression_placementCount(savedPlacements: Int, matches: Bool) async {
    let dependencyContainer = DependencyContainer()
    let storage = StorageMock()
    for _ in 0..<savedPlacements {
      await withCheckedContinuation { continuation in
        storage.coreDataManager.savePlacementData(
          PlacementData(name: "freeTrial_start", parameters: [:], createdAt: Date())
        ) { _ in
          continuation.resume()
        }
      }
    }
    let evaluator = CELEvaluator(
      storage: storage,
      factory: dependencyContainer
    )
    let rule: TriggerRule = .stub()
      .setting(\.expression, to: "device.placementsSinceInstall(\"freeTrial_start\") <= 2")
    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: PlacementData(name: "ss", parameters: [:], createdAt: Date())
    )

    if matches {
      #expect(result == .match(audience: rule))
    } else {
      #expect(result == .noMatch(source: .expression, experimentId: rule.experiment.id))
    }
  }

  /// The time since the placement a filter is being checked for is the time since
  /// the one before it, not since the one that has just been tracked. The first
  /// time it happens there's none before it, so it reads zero.
  @Test(arguments: [(true, 5, true), (true, 0, false), (false, 0, true), (false, 5, false)])
  func evaluateExpression_timeSinceThePlacementBeingChecked(
    happenedBefore: Bool,
    hours: Int,
    matches: Bool
  ) async {
    let dependencyContainer = DependencyContainer()
    let storage = StorageMock()
    let earlier = PlacementData(
      name: "paywall_decline",
      parameters: [:],
      createdAt: Date().addingTimeInterval(-5 * 60 * 60 - 60)
    )
    let current = PlacementData(name: "paywall_decline", parameters: [:], createdAt: Date())
    for placement in happenedBefore ? [earlier, current] : [current] {
      await withCheckedContinuation { continuation in
        storage.coreDataManager.savePlacementData(placement) { _ in
          continuation.resume()
        }
      }
    }
    let evaluator = CELEvaluator(
      storage: storage,
      factory: dependencyContainer
    )
    let rule: TriggerRule = .stub()
      .setting(\.expression, to: "device.hoursSince(\"paywall_decline\") == \(hours)")

    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: current
    )

    if matches {
      #expect(result == .match(audience: rule))
    } else {
      #expect(result == .noMatch(source: .expression, experimentId: rule.experiment.id))
    }
  }

  /// An evaluation can still be running when whatever made the evaluator lets go
  /// of the storage, so the evaluator has to keep the storage itself.
  @Test func evaluateExpression_keepsItsStorage() async {
    let dependencyContainer = DependencyContainer()
    var storage: StorageMock? = StorageMock()
    let evaluator = CELEvaluator(
      storage: storage!,
      factory: dependencyContainer
    )
    storage = nil
    let rule: TriggerRule = .stub()
      .setting(\.expression, to: "device.placementsSinceInstall(\"freeTrial_start\") == 0")

    let result = await evaluator.evaluateExpression(
      fromAudienceFilter: rule,
      placementData: PlacementData(name: "ss", parameters: [:], createdAt: Date())
    )

    #expect(result == .match(audience: rule))
  }
}
