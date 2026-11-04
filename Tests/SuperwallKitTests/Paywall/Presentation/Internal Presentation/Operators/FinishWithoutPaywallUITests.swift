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

  /// Runs the step and returns the states it sent, and whether it threw.
  private func run(
    _ triggerResult: InternalTriggerResult
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
        publisher: statePublisher
      )
    } catch {
      didThrow = true
    }
    return (states, didThrow, didFinish)
  }

  @Test func paywall_sendsUnavailableError() async {
    let result = await run(.paywall(experiment()))

    #expect(result.didThrow)
    #expect(result.didFinish)
    #expect(result.states.count == 1)
    guard case .presentationError(let error) = result.states.first else {
      Issue.record("Expected a presentation error, got \(result.states)")
      return
    }
    let nsError = error as NSError
    #expect(nsError.domain == "SWKPresentationError")
    #expect(nsError.code == 108)
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
