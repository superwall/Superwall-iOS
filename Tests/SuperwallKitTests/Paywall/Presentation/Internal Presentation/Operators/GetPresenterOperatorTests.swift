//
//  File.swift
//
//
//  Created by Yusuf Tör on 06/12/2022.
//

import Testing
import UIKit
@testable import SuperwallKit
import Combine

@Suite(.serialized)
final class GetPresenterOperatorTests {
  var cancellables: [AnyCancellable] = []
  let superwall = Superwall.shared

  @MainActor
  @Test func checkPaywallIsPresentable_noPresenter() async {
    let experiment = Experiment(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: ""))

    let statePublisher = PassthroughSubject<PaywallState, Never>()

    await confirmation(expectedCount: 2) { stateConfirmation in
      statePublisher.sink { completion in
        switch completion {
        case .finished:
          stateConfirmation()
        }
      } receiveValue: { state in
        switch state {
        case .presentationError:
          stateConfirmation()
        default:
          break
        }
      }
      .store(in: &cancellables)

      Superwall.shared.presentationItems.window = UIWindow()

      let dependencyContainer = DependencyContainer()
      let request = dependencyContainer.makePresentationRequest(
        .explicitTrigger(.stub()),
        isDebuggerLaunched: false,
        isPaywallPresented: false,
        type: .presentation
      )
      .setting(\.presenter, to: nil)

      let paywallVc = dependencyContainer.makePaywallViewController(
        for: .stub(),
        withCache: nil,
        withPaywallArchiveManager: nil,
        delegate: nil
      )
      paywallVc.loadViewIfNeeded()

      await confirmation { noPresenterConfirmation in
        do {
          try await Superwall.shared.getPresenterIfNecessary(
            for: paywallVc,
            audienceOutcome: AudienceFilterEvaluationOutcome(triggerResult: .paywall(experiment)),
            request: request,
            debugInfo: [:],
            paywallStatePublisher: statePublisher
          )
          Issue.record("Should throw")
        } catch {
          if let error = error as? PresentationPipelineError,
             case .noPresenter = error {
            noPresenterConfirmation()
          }
        }
      }
    }
  }

  @MainActor
  @Test func checkPaywallIsPresentable_success() async {
    let experiment = Experiment(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: ""))

    let statePublisher = PassthroughSubject<PaywallState, Never>()

    await confirmation(expectedCount: 0) { stateConfirmation in
      statePublisher.sink { completion in
        stateConfirmation()
      } receiveValue: { state in
        stateConfirmation()
      }
      .store(in: &cancellables)

      let request = PresentationRequest.stub()
        .setting(\.presenter, to: UIViewController())

      let dependencyContainer = DependencyContainer()
      let paywallVc = dependencyContainer.makePaywallViewController(
        for: .stub(),
        withCache: nil,
        withPaywallArchiveManager: nil,
        delegate: nil
      )
      paywallVc.loadViewIfNeeded()
      do {
        try await Superwall.shared.getPresenterIfNecessary(
          for: paywallVc,
          audienceOutcome: AudienceFilterEvaluationOutcome(triggerResult: .paywall(experiment)),
          request: request,
          debugInfo: [:],
          paywallStatePublisher: statePublisher
        )
      } catch {
        Issue.record()
      }
    }
  }
}
