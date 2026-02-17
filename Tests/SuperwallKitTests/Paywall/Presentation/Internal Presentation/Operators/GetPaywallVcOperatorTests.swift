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
final class GetPaywallVcOperatorTests {
  var cancellables: [AnyCancellable] = []

  @MainActor
  @Test func getPaywallViewController_success_paywallNotAlreadyPresented() async {
    let statePublisher = PassthroughSubject<PaywallState, Never>()

    await confirmation(expectedCount: 0) { stateConfirmation in
      statePublisher.sink { _ in
        stateConfirmation()
      }
      .store(in: &cancellables)

      let dependencyContainer = DependencyContainer()
      let paywallManager = PaywallManagerMock(
        factory: dependencyContainer,
        paywallRequestManager: dependencyContainer.paywallRequestManager
      )
      paywallManager.getPaywallVc = dependencyContainer.makePaywallViewController(
        for: .stub(),
        withCache: nil,
        withPaywallArchiveManager: nil,
        delegate: nil
      )
      dependencyContainer.paywallManager = paywallManager

      let request = PresentationRequest.stub()
        .setting(\.flags.isPaywallPresented, to: false)

      do {
        _ = try await Superwall.shared.getPaywallViewController(
          request: request,
          audienceOutcome: .init(triggerResult: .paywall(.init(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: "")))),
          debugInfo: [:],
          paywallStatePublisher: statePublisher,
          dependencyContainer: dependencyContainer
        )
      } catch {
        Issue.record("Shouldn't have failed \(error)")
      }
    }
  }
}
