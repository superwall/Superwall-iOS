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

  func test_storePresentationObjects() {
    let request = PresentationRequest.stub()
    let input = PresentablePipelineOutput(
      request: request,
      debugInfo: [:],
      paywallViewController: PaywallViewController(paywall: .stub()),
      presenter: UIViewController(),
      confirmableAssignment: nil
    )

    let subjectExpectation = expectation(description: "Subject completed")
    subjectExpectation.expectedFulfillmentCount = 2
    let subject = PresentationSubject(request)

    subject
      .sink { completion in
        switch completion {
        case .finished:
          subjectExpectation.fulfill()
        default:
          break
        }
      } receiveValue: { _ in
        subjectExpectation.fulfill()
      }
      .store(in: &cancellables)

    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .storePresentationObjects(subject)
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { _ in }
      )
      .store(in: &cancellables)

    wait(for: [subjectExpectation], timeout: 0.1)
  }
}