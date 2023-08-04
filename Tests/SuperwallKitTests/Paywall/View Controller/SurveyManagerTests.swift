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
      paywallIsDeclined: false,
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
      paywallIsDeclined: true,
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
      paywallIsDeclined: true,
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
      paywallIsDeclined: true,
      paywallInfo: .stub(),
      storage: storageMock,
      completion: {
        expectation.fulfill()
      }
    )
    wait(for: [expectation])
    XCTAssertTrue(storageMock.didSave)
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
      paywallIsDeclined: true,
      paywallInfo: .stub(),
      storage: storageMock,
      completion: {
        expectation.fulfill()
      }
    )
    wait(for: [expectation], timeout: 0.1)
  }
}
