//
//  File.swift
//  
//
//  Created by Yusuf Tör on 20/01/2023.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit
import Combine

final class CheckForPaywallResultTests: XCTestCase {
  var cancellables: [AnyCancellable] = []

  func test_checkForPaywallResult_eventNotFound() async {
    let expectation = expectation(description: "Did throw")

    let assignmentPipelineOutput = AssignmentPipelineOutput(
      request: .stub(),
      triggerResult: .eventNotFound,
      debugInfo: [:])

    CurrentValueSubject(assignmentPipelineOutput)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .checkForPaywallResult()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure(let error):
            guard let error = error as? GetPresentationResultError else {
              return XCTFail("Wrong type of error")
            }
            XCTAssertEqual(error, GetPresentationResultError.willNotPresent(.eventNotFound))
            expectation.fulfill()
          case .finished:
            XCTFail("Shouldn't have finished")
          }
        },
        receiveValue: { _ in }
      )
      .store(in: &cancellables)

    await fulfillment(of: [expectation], timeout: 0.1)
  }

  func test_checkForPaywallResult_noRuleMatch() async {
    let expectation = expectation(description: "Did throw")

    let assignmentPipelineOutput = AssignmentPipelineOutput(
      request: .stub(),
      triggerResult: .noRuleMatch,
      debugInfo: [:])

    CurrentValueSubject(assignmentPipelineOutput)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .checkForPaywallResult()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure(let error):
            guard let error = error as? GetPresentationResultError else {
              return XCTFail("Wrong type of error")
            }
            guard case .willNotPresent(let result) = error else {
              return XCTFail("Wrong type of error")
            }
            XCTAssertEqual(result, .noRuleMatch)
            expectation.fulfill()
          case .finished:
            XCTFail("Shouldn't have finished")
          }
        },
        receiveValue: { _ in }
      )
      .store(in: &cancellables)

    await fulfillment(of: [expectation], timeout: 0.1)
  }

  func test_checkForPaywallResult_holdout() async {
    let expectation = expectation(description: "Did throw")

    let assignmentPipelineOutput = AssignmentPipelineOutput(
      request: .stub(),
      triggerResult: .holdout(.stub()),
      debugInfo: [:])

    CurrentValueSubject(assignmentPipelineOutput)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .checkForPaywallResult()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure(let error):
            guard let error = error as? GetPresentationResultError else {
              return XCTFail("Wrong type of error")
            }
            guard case .willNotPresent(let result) = error else {
              return XCTFail("Wrong type of error")
            }
            guard case .holdout(let experiment) = result else {
              return XCTFail("Wrong type of error")
            }
            XCTAssertEqual(result, .holdout(experiment))
            expectation.fulfill()
          case .finished:
            XCTFail("Shouldn't have finished")
          }
        },
        receiveValue: { _ in }
      )
      .store(in: &cancellables)

    await fulfillment(of: [expectation], timeout: 0.1)
  }

  func test_checkForPaywallResult_error() async {
    let expectation = expectation(description: "Did throw")

    let myError = NSError(domain: "a", code: 1)
    let assignmentPipelineOutput = AssignmentPipelineOutput(
      request: .stub(),
      triggerResult: .error(myError),
      debugInfo: [:])

    CurrentValueSubject(assignmentPipelineOutput)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .checkForPaywallResult()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure(let error):
            guard let error = error as? GetPresentationResultError else {
              return XCTFail("Wrong type of error")
            }
            guard case .willNotPresent(let result) = error else {
              return XCTFail("Wrong type of error")
            }
            guard case .error(let error) = result else {
              return XCTFail("Wrong type of error")
            }
            XCTAssertEqual(error, myError)
            expectation.fulfill()
          case .finished:
            XCTFail("Shouldn't have finished")
          }
        },
        receiveValue: { _ in }
      )
      .store(in: &cancellables)

    await fulfillment(of: [expectation], timeout: 0.1)
  }

  func test_checkForPaywallResult_paywall() async {
    let expectation = expectation(description: "Did return")

    let request: PresentationRequest = .stub()
    let experiment: Experiment = .stub()
    let triggerResult: TriggerResult = .paywall(experiment)
    let debugInfo = ["test": true]
    let assignmentPipelineOutput = AssignmentPipelineOutput(
      request: request,
      triggerResult: triggerResult,
      debugInfo: debugInfo)

    CurrentValueSubject(assignmentPipelineOutput)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .checkForPaywallResult()
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { completion in
          XCTFail("Shouldn't have finished")
        },
        receiveValue: { result in
          XCTAssertEqual(result.experiment, experiment)
          XCTAssertNil(result.confirmableAssignment)
          XCTAssertEqual(result.triggerResult, triggerResult)
          XCTAssertEqual(result.debugInfo["test"] as! Bool, true)
          expectation.fulfill()
        }
      )
      .store(in: &cancellables)

    await fulfillment(of: [expectation], timeout: 0.1)
  }
}
