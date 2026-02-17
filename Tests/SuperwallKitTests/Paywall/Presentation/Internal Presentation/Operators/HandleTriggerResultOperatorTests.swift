//
//  File.swift
//
//
//  Created by Yusuf Tör on 05/12/2022.
//

import Foundation
import Testing
@testable import SuperwallKit
import Combine

@Suite(.serialized)
final class HandleTriggerResultOperatorTests {
  var cancellables: [AnyCancellable] = []

  @Test func handleTriggerResult_paywall() async {
    let input = AudienceFilterEvaluationOutcome(
      triggerResult: .paywall(.init(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: "")))
    )

    let statePublisher = PassthroughSubject<PaywallState, Never>()

    await confirmation(expectedCount: 0) { stateConfirmation in
      statePublisher.sink { state in
        stateConfirmation()
      }
      .store(in: &cancellables)

      do {
        _ = try await Superwall.shared.getExperiment(
          request: .stub(),
          audienceOutcome: input,
          debugInfo: [:],
          paywallStatePublisher: statePublisher,
          storage: StorageMock()
        )
      } catch {
        Issue.record()
      }
    }
  }

  @Test func handleTriggerResult_holdout() async {
    //TODO: THis doesn't take into account activateSession
    let experimentId = "abc"
    let input = AudienceFilterEvaluationOutcome(
      triggerResult: .holdout(.init(id: experimentId, groupId: "", variant: .init(id: "", type: .treatment, paywallId: "")))
    )

    let statePublisher = PassthroughSubject<PaywallState, Never>()

    await confirmation(expectedCount: 2) { stateConfirmation in
      statePublisher.sink { completion in
        switch completion {
        case .finished:
          stateConfirmation()
        default:
          break
        }
      } receiveValue: { state in
        switch state {
        case .skipped(let reason):
          switch reason {
          case .holdout(let experiment):
            #expect(experiment.id == experimentId)
            stateConfirmation()
          default:
            break
          }
        default:
          break
        }
      }
      .store(in: &cancellables)

      do {
        _ = try await Superwall.shared.getExperiment(
          request: .stub(),
          audienceOutcome: input,
          debugInfo: [:],
          paywallStatePublisher: statePublisher,
          storage: StorageMock()
        )
        Issue.record("Should fail")
      } catch {
        if let error = error as? PresentationPipelineError,
          case .holdout = error {

        } else {
          Issue.record("Wrong error type")
        }
      }
    }
  }

  @Test func handleTriggerResult_noRuleMatch() async {
    let input = AudienceFilterEvaluationOutcome(
      triggerResult: .noAudienceMatch([])
    )

    let statePublisher = PassthroughSubject<PaywallState, Never>()

    await confirmation(expectedCount: 2) { stateConfirmation in
      statePublisher.sink { completion in
        switch completion {
        case .finished:
          stateConfirmation()
        default:
          break
        }
      } receiveValue: { state in
        switch state {
        case .skipped(let reason):
          switch reason {
          case .noAudienceMatch:
            stateConfirmation()
          default:
            break
          }
        default:
          break
        }
      }
      .store(in: &cancellables)

      do {
        _ = try await Superwall.shared.getExperiment(
          request: .stub(),
          audienceOutcome: input,
          debugInfo: [:],
          paywallStatePublisher: statePublisher,
          storage: StorageMock()
        )
        Issue.record("Should fail")
      } catch {
        if let error = error as? PresentationPipelineError,
          case .noAudienceMatch = error {

        } else {
          Issue.record("Wrong error type")
        }
      }
    }
  }

  @Test func handleTriggerResult_eventNotFound() async {
    let input = AudienceFilterEvaluationOutcome(
      triggerResult: .placementNotFound
    )

    let statePublisher = PassthroughSubject<PaywallState, Never>()

    await confirmation(expectedCount: 2) { stateConfirmation in
      statePublisher.sink { completion in
        switch completion {
        case .finished:
          stateConfirmation()
        default:
          break
        }
      } receiveValue: { state in
        switch state {
        case .skipped(let reason):
          switch reason {
          case .placementNotFound:
            stateConfirmation()
          default:
            break
          }
        default:
          break
        }
      }
      .store(in: &cancellables)

      do {
        _ = try await Superwall.shared.getExperiment(
          request: .stub(),
          audienceOutcome: input,
          debugInfo: [:],
          paywallStatePublisher: statePublisher,
          storage: StorageMock()
        )
        Issue.record("Should fail")
      } catch {
        if let error = error as? PresentationPipelineError,
          case .placementNotFound = error {

        } else {
          Issue.record("Wrong error type")
        }
      }
    }
  }

  @Test func handleTriggerResult_error() async {
    let outputError = NSError(
      domain: "Test",
      code: 1
    )
    let input = AudienceFilterEvaluationOutcome(
      triggerResult: .error(outputError)
    )

    let statePublisher = PassthroughSubject<PaywallState, Never>()

    await confirmation(expectedCount: 2) { stateConfirmation in
      statePublisher.sink { completion in
        switch completion {
        case .finished:
          stateConfirmation()
        default:
          break
        }
      } receiveValue: { state in
        switch state {
        case .presentationError(let error):
          #expect(error as NSError == outputError)
          stateConfirmation()
        default:
          break
        }
      }
      .store(in: &cancellables)

      do {
        _ = try await Superwall.shared.getExperiment(
          request: .stub(),
          audienceOutcome: input,
          debugInfo: [:],
          paywallStatePublisher: statePublisher,
          storage: StorageMock()
        )
        Issue.record("Should fail")
      } catch {
        if let error = error as? PresentationPipelineError,
           case .noPaywallViewController = error {

        } else {
          Issue.record("Wrong error type")
        }
      }
    }
  }
}
