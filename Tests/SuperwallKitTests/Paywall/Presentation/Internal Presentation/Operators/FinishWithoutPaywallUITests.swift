//
//  FinishWithoutPaywallUITests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 04/11/2026.
//

import Foundation
import Testing
@testable import SuperwallKit
import Combine

@Suite(.serialized)
final class FinishWithoutPaywallUITests {
  var cancellables: [AnyCancellable] = []

  private func experiment(id: String = "abc") -> Experiment {
    return .init(id: id, groupId: "", variant: .init(id: "", type: .treatment, paywallId: ""))
  }

  private struct FetchFailed: Error {}

  /// Runs the step and returns the states it sent, and whether it threw.
  private func run(
    _ triggerResult: InternalTriggerResult,
    getPaywall: @escaping (PaywallRequest) async throws -> Paywall = { _ in .stub() }
  ) async -> (states: [PaywallState], didThrow: Bool, didFinish: Bool) {
    let statePublisher = PassthroughSubject<PaywallState, Never>()
    var states: [PaywallState] = []
    var didFinish = false
    statePublisher.sink { _ in
      didFinish = true
    } receiveValue: { state in
      states.append(state)
    }
    .store(in: &cancellables)

    var didThrow = false
    do {
      try await Superwall.shared.finishWithoutPaywallUI(
        request: .stub(),
        audienceOutcome: AudienceFilterEvaluationOutcome(triggerResult: triggerResult),
        debugInfo: [:],
        publisher: statePublisher,
        getPaywall: getPaywall
      )
    } catch {
      didThrow = true
    }
    return (states, didThrow, didFinish)
  }

  private func paywall(gating: FeatureGatingBehavior) -> Paywall {
    var paywall = Paywall.stub()
    paywall.featureGating = gating
    return paywall
  }

  /// Checks the step declined the paywall as if its page failed to load,
  /// which is what iOS does without an internet connection.
  private func expectDeclinedAsFailedToLoad(
    _ result: (states: [PaywallState], didThrow: Bool, didFinish: Bool),
    gating: FeatureGatingBehavior
  ) {
    #expect(!result.didThrow)
    #expect(result.didFinish)
    guard
      result.states.count == 1,
      case let .dismissed(paywallInfo, paywallResult) = result.states[0]
    else {
      Issue.record("Expected a dismissal, got \(result.states)")
      return
    }
    guard case .declined = paywallResult else {
      Issue.record("Expected the paywall to be declined, got \(paywallResult)")
      return
    }
    #expect(paywallInfo.closeReason == .webViewFailedToLoad)
    #expect(paywallInfo.featureGatingBehavior == gating)
  }

  @Test func nonGatedPaywall_isDeclinedAsFailedToLoad() async {
    let result = await run(.paywall(experiment())) { _ in
      self.paywall(gating: .nonGated)
    }
    expectDeclinedAsFailedToLoad(result, gating: .nonGated)
  }

  @Test func gatedPaywall_isDeclinedAsFailedToLoad() async {
    let result = await run(.paywall(experiment())) { _ in
      self.paywall(gating: .gated)
    }
    expectDeclinedAsFailedToLoad(result, gating: .gated)
  }

  @Test func paywallFetchFailure_sendsError() async {
    let result = await run(.paywall(experiment())) { _ in
      throw FetchFailed()
    }

    #expect(result.didThrow)
    #expect(result.didFinish)
    guard
      result.states.count == 1,
      case .presentationError(let error) = result.states[0]
    else {
      Issue.record("Expected a presentation error, got \(result.states)")
      return
    }
    #expect(error is FetchFailed)
  }

  @Test func paywallRequest_usesTheExperimentsPaywall() async {
    var requestedPaywallId: String?
    _ = await run(.paywall(.init(id: "exp", groupId: "", variant: .init(id: "", type: .treatment, paywallId: "pw")))) {
      requestedPaywallId = $0.responseIdentifiers.paywallId
      return .stub()
    }
    #expect(requestedPaywallId == "pw")
  }

  @Test func noAudienceMatch_isSkipped() async {
    let result = await run(.noAudienceMatch([]))

    #expect(result.didThrow)
    #expect(result.didFinish)
    guard
      result.states.count == 1,
      case .skipped(.noAudienceMatch) = result.states[0]
    else {
      Issue.record("Expected a no audience match skip, got \(result.states)")
      return
    }
  }

  @Test func holdout_isSkipped() async {
    let result = await run(.holdout(experiment(id: "holdout")))

    #expect(result.didThrow)
    #expect(result.didFinish)
    guard
      result.states.count == 1,
      case .skipped(.holdout(let experiment)) = result.states[0]
    else {
      Issue.record("Expected a holdout skip, got \(result.states)")
      return
    }
    #expect(experiment.id == "holdout")
  }

  @Test func placementNotFound_isSkipped() async {
    let result = await run(.placementNotFound)

    #expect(result.didThrow)
    #expect(result.didFinish)
    guard
      result.states.count == 1,
      case .skipped(.placementNotFound) = result.states[0]
    else {
      Issue.record("Expected a placement not found skip, got \(result.states)")
      return
    }
  }
}
