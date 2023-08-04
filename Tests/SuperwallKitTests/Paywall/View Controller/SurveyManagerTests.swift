//
//  SurveyManagerTests.swift
//  
//
//  Created by Yusuf Tör on 31/07/2023.
//

import XCTest
@testable import SuperwallKit

@available(iOS 14.0, *)
final class SurveyManagerTests: XCTestCase {
  func test_presentSurveyIfAvailable_paywallDeclined() {
    let survey = Survey.stub()
    let expectation = expectation(description: "called completion block")
    SurveyManager.presentSurveyIfAvailable(
      survey,
      using: UIViewController(),
      loadingState: .ready,
      paywallIsManuallyDeclined: false,
      isDebuggerLaunched: false,
      paywallInfo: .stub(),
      storage: StorageMock(),
      completion: {
        expectation.fulfill()
      }
    )
    wait(for: [expectation])
  }

  func test_presentSurveyIfAvailable_surveyNil() {
    let expectation = expectation(description: "called completion block")
    SurveyManager.presentSurveyIfAvailable(
      nil,
      using: UIViewController(),
      loadingState: .ready,
      paywallIsManuallyDeclined: true,
      isDebuggerLaunched: false,
      paywallInfo: .stub(),
      storage: StorageMock(),
      completion: {
        expectation.fulfill()
      }
    )
    wait(for: [expectation])
  }

  func test_presentSurveyIfAvailable_loadingState_loadingPurchase() {
    let expectation = expectation(description: "called completion block")
    SurveyManager.presentSurveyIfAvailable(
      .stub(),
      using: UIViewController(),
      loadingState: .loadingPurchase,
      paywallIsManuallyDeclined: true,
      isDebuggerLaunched: false,
      paywallInfo: .stub(),
      storage: StorageMock(),
      completion: {
        expectation.fulfill()
      }
    )
    wait(for: [expectation])
  }

  func test_presentSurveyIfAvailable_loadingState_loadingURL() {
    let expectation = expectation(description: "called completion block")
    SurveyManager.presentSurveyIfAvailable(
      .stub(),
      using: UIViewController(),
      loadingState: .loadingURL,
      paywallIsManuallyDeclined: true,
      isDebuggerLaunched: false,
      paywallInfo: .stub(),
      storage: StorageMock(),
      completion: {
        expectation.fulfill()
      }
    )
    wait(for: [expectation])
  }

  func test_presentSurveyIfAvailable_loadingState_manualLoading() {
    let expectation = expectation(description: "called completion block")
    SurveyManager.presentSurveyIfAvailable(
      .stub(),
      using: UIViewController(),
      loadingState: .manualLoading,
      paywallIsManuallyDeclined: true,
      isDebuggerLaunched: false,
      paywallInfo: .stub(),
      storage: StorageMock(),
      completion: {
        expectation.fulfill()
      }
    )
    wait(for: [expectation])
  }

  func test_presentSurveyIfAvailable_loadingState_unknown() {
    let expectation = expectation(description: "called completion block")
    SurveyManager.presentSurveyIfAvailable(
      .stub(),
      using: UIViewController(),
      loadingState: .unknown,
      paywallIsManuallyDeclined: true,
      isDebuggerLaunched: false,
      paywallInfo: .stub(),
      storage: StorageMock(),
      completion: {
        expectation.fulfill()
      }
    )
    wait(for: [expectation])
  }

  func test_presentSurveyIfAvailable_sameAssignmentKey() {
    let storageMock = StorageMock()

    let survey = Survey.stub()
      .setting(\.assignmentKey, to: "1")
    storageMock.save("1", forType: SurveyAssignmentKey.self)

    let expectation = expectation(description: "called completion block")
    SurveyManager.presentSurveyIfAvailable(
      survey,
      using: UIViewController(),
      loadingState: .ready,
      paywallIsManuallyDeclined: true,
      isDebuggerLaunched: false,
      paywallInfo: .stub(),
      storage: storageMock,
      completion: {
        expectation.fulfill()
      }
    )
    wait(for: [expectation])
    XCTAssertTrue(storageMock.didSave)
  }

  func test_presentSurveyIfAvailable_zeroPresentationProbability() {
    let storageMock = StorageMock()

    let survey = Survey.stub()
      .setting(\.presentationProbability, to: 0)

    let expectation = expectation(description: "called completion block")

    SurveyManager.presentSurveyIfAvailable(
      survey,
      using: UIViewController(),
      loadingState: .ready,
      paywallIsManuallyDeclined: true,
      isDebuggerLaunched: false,
      paywallInfo: .stub(),
      storage: storageMock,
      completion: {
        expectation.fulfill()
      }
    )
    wait(for: [expectation])
    XCTAssertTrue(storageMock.didSave)
  }

  func test_presentSurveyIfAvailable_debuggerLaunched() {
    let storageMock = StorageMock()

    let survey = Survey.stub()

    let expectation = expectation(description: "called completion block")
    expectation.isInverted = true

    SurveyManager.presentSurveyIfAvailable(
      survey,
      using: UIViewController(),
      loadingState: .ready,
      paywallIsManuallyDeclined: true,
      isDebuggerLaunched: true,
      paywallInfo: .stub(),
      storage: storageMock,
      completion: {
        expectation.fulfill()
      }
    )
    wait(for: [expectation], timeout: 0.1)
    XCTAssertFalse(storageMock.didSave)
  }

  func test_presentSurveyIfAvailable_success() {
    let storageMock = StorageMock()
    storageMock.reset()

    let survey = Survey.stub()
      .setting(\.presentationProbability, to: 1)

    let expectation = expectation(description: "called completion block")
    expectation.isInverted = true
    SurveyManager.presentSurveyIfAvailable(
      survey,
      using: UIViewController(),
      loadingState: .ready,
      paywallIsManuallyDeclined: true,
      isDebuggerLaunched: false,
      paywallInfo: .stub(),
      storage: storageMock,
      completion: {
        expectation.fulfill()
      }
    )
    wait(for: [expectation], timeout: 0.1)
  }
}
