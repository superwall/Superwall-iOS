//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/12/2022.
//

import XCTest
@testable import SuperwallKit
import Combine

final class HandleTriggerResultOperatorTests: XCTestCase {
  var cancellables: [AnyCancellable] = []

  func test_handleTriggerResult_paywall() {
    let input = AssignmentPipelineOutput(
      request: .stub(),
      triggerResult: .paywall(.init(id: "", groupId: "", variant: .init(id: "", type: .treatment, paywallId: ""))),
      debugInfo: [:]
    )

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.isInverted = true

    statePublisher.sink { state in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)

    let expectation = expectation(description: "Called publisher")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .handleTriggerResult(statePublisher)
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { output in
          expectation.fulfill()
        }
      )
      .store(in: &cancellables)

    wait(for: [expectation, stateExpectation], timeout: 0.1)
  }

  func test_handleTriggerResult_holdout() {
    //TODO: THis doesn't take into account activateSession
    let experimentId = "abc"
    let input = AssignmentPipelineOutput(
      request: .stub(),
      triggerResult: .holdout(.init(id: experimentId, groupId: "", variant: .init(id: "", type: .treatment, paywallId: ""))),
      debugInfo: [:]
    )

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.expectedFulfillmentCount = 2

    statePublisher.sink { completion in
      switch completion {
      case .finished:
        stateExpectation.fulfill()
      default:
        break
      }
    } receiveValue: { state in
      switch state {
      case .skipped(let reason):
        switch reason {
        case .holdout(let experiment):
          XCTAssertEqual(experiment.id, experimentId)
          stateExpectation.fulfill()
        default:
          break
        }
      default:
        break
      }
    }
    .store(in: &cancellables)

    let expectation = expectation(description: "Failed")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .handleTriggerResult(statePublisher)
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure:
            expectation.fulfill()
          default:
            break
          }
        },
        receiveValue: { output in
          XCTFail()
        }
      )
      .store(in: &cancellables)

    wait(for: [expectation, stateExpectation], timeout: 1)
  }

  func test_handleTriggerResult_noRuleMatch() {
    let input = AssignmentPipelineOutput(
      request: .stub(),
      triggerResult: .noRuleMatch,
      debugInfo: [:]
    )

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.expectedFulfillmentCount = 2

    statePublisher.sink { completion in
      switch completion {
      case .finished:
        stateExpectation.fulfill()
      default:
        break
      }
    } receiveValue: { state in
      switch state {
      case .skipped(let reason):
        switch reason {
        case .noRuleMatch:
          stateExpectation.fulfill()
        default:
          break
        }
      default:
        break
      }
    }
    .store(in: &cancellables)

    let expectation = expectation(description: "Failed")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .handleTriggerResult(statePublisher)
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure:
            expectation.fulfill()
          default:
            break
          }
        },
        receiveValue: { output in
          XCTFail()
        }
      )
      .store(in: &cancellables)

    wait(for: [expectation, stateExpectation], timeout: 1)
  }

  func test_handleTriggerResult_eventNotFound() {
    let input = AssignmentPipelineOutput(
      request: .stub(),
      triggerResult: .eventNotFound,
      debugInfo: [:]
    )

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.expectedFulfillmentCount = 2

    statePublisher.sink { completion in
      switch completion {
      case .finished:
        stateExpectation.fulfill()
      default:
        break
      }
    } receiveValue: { state in
      switch state {
      case .skipped(let reason):
        switch reason {
        case .eventNotFound:
          stateExpectation.fulfill()
        default:
          break
        }
      default:
        break
      }
    }
    .store(in: &cancellables)

    let expectation = expectation(description: "Failed")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .handleTriggerResult(statePublisher)
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure:
            expectation.fulfill()
          default:
            break
          }
        },
        receiveValue: { output in
          XCTFail()
        }
      )
      .store(in: &cancellables)

    wait(for: [expectation, stateExpectation], timeout: 0.1)
  }

  func test_handleTriggerResult_error() {
    let outputError = NSError(
      domain: "Test",
      code: 1
    )
    let input = AssignmentPipelineOutput(
      request: .stub(),
      triggerResult: .error(outputError),
      debugInfo: [:]
    )

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.expectedFulfillmentCount = 2

    statePublisher.sink { completion in
      switch completion {
      case .finished:
        stateExpectation.fulfill()
      default:
        break
      }
    } receiveValue: { state in
      switch state {
      case .presentationError(let error):
        XCTAssertEqual(error as NSError, outputError)
        stateExpectation.fulfill()
      default:
        break
      }
    }
    .store(in: &cancellables)

    let expectation = expectation(description: "Failed")
    CurrentValueSubject(input)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .handleTriggerResult(statePublisher)
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure:
            expectation.fulfill()
          default:
            break
          }
        },
        receiveValue: { output in
          XCTFail()
        }
      )
      .store(in: &cancellables)

    wait(for: [expectation, stateExpectation], timeout: 1)
  }
}
