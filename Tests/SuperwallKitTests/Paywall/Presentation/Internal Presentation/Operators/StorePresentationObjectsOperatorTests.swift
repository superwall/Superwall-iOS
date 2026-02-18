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
struct StorePresentationObjectsOperatorTests {
  @Test @MainActor
  func storePresentationObjects() {
    let dependencyContainer = DependencyContainer()

    let request = PresentationRequest.stub()
    let input = PresentablePipelineOutput(
      debugInfo: [:],
      paywallViewController: dependencyContainer.makePaywallViewController(
        for: .stub(),
        withCache: nil,
        withPaywallArchiveManager: nil,
        delegate: nil
      ),
      presenter: UIViewController(),
      assignment: nil
    )

    Superwall.shared.storePresentationObjects(
      request: request,
      paywallStatePublisher: .init(),
      featureGatingBehavior: .gated
    )

    #expect(Superwall.shared.presentationItems.last != nil)
  }
}
