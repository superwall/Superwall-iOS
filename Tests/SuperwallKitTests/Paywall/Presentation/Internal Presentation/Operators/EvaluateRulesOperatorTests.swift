//
//  File.swift
//
//
//  Created by Yusuf Tör on 05/12/2022.
//

import Testing
@testable import SuperwallKit
import Combine

@Suite(.serialized)
struct EvaluateRulesOperatorTests {
  @Test func evaluateRules_isDebugger() async {
    let dependencyContainer = DependencyContainer()
    let identifier = "abc"

    let request = dependencyContainer.makePresentationRequest(
      .fromIdentifier(identifier, freeTrialOverride: false),
      isDebuggerLaunched: true,
      isPaywallPresented: false,
      type: .getPaywall(.stub())
    )

    do {
      let output = try await Superwall.shared.evaluateAudienceFilter(
        from: request
      )
      #expect(output.assignment == nil)

      switch output.triggerResult {
      case .paywall(let experiment):
        #expect(experiment.id == identifier)
        #expect(experiment.groupId == "")
        #expect(experiment.variant.id == "")
        #expect(experiment.variant.type == .treatment)
        #expect(experiment.variant.paywallId == identifier)
      default:
        Issue.record("Wrong trigger result")
      }
    } catch {
      Issue.record("Shouldn't throw")
    }
  }

  @Test func evaluateRules_isNotDebugger() async {
    let dependencyContainer = DependencyContainer()
    let request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      isDebuggerLaunched: false,
      isPaywallPresented: false,
      type: .getPaywall(.stub())
    )

    do {
      let output = try await Superwall.shared.evaluateAudienceFilter(
        from: request
      )
      #expect(output.assignment == nil)

      switch output.triggerResult {
      case .placementNotFound:
        break
      default:
        Issue.record("Wrong trigger result")
      }
    } catch {
      Issue.record("Shouldn't throw")
    }
  }
}
