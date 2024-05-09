//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/12/2022.
//

import XCTest
@testable import SuperwallKit
import Combine

final class StorePresentationObjectsOperatorTests: XCTestCase {
  var cancellables: [AnyCancellable] = []

  @MainActor
  func test_storePresentationObjects() {
    let dependencyContainer = DependencyContainer()

    let request = PresentationRequest.stub()
    let input = PresentablePipelineOutput(
      debugInfo: [:],
      paywallViewController: dependencyContainer.makePaywallViewController(
        for: .stub(),
        withCache: nil,
        withPaywallArchivalManager: nil,
        delegate: nil
      ),
      presenter: UIViewController(),
      confirmableAssignment: nil
    )

    Superwall.shared.storePresentationObjects(
      request: request,
      paywallStatePublisher: .init(),
      featureGatingBehavior: .gated
    )

    XCTAssertNotNil(Superwall.shared.presentationItems.last)
  }
}
