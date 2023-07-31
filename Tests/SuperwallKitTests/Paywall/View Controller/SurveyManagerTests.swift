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
  func test_presentSurvey_paywallDeclined() {
    let survey = Survey.stub()
    let result = SurveyManager.presentSurvey(
      survey,
      using: UIViewController(),
      paywallIsDeclined: false,
      paywallInfo: .stub(),
      storage: StorageMock(),
      completion: {}
    )
    XCTAssertFalse(result)
  }

  func test_presentSurvey_surveyNil() {
    let result = SurveyManager.presentSurvey(
      nil,
      using: UIViewController(),
      paywallIsDeclined: true,
      paywallInfo: .stub(),
      storage: StorageMock(),
      completion: {}
    )
    XCTAssertFalse(result)
  }

  func test_presentSurvey_sameAssignmentKey() {
    let storageMock = StorageMock()

    let survey = Survey.stub()
      .setting(\.assignmentKey, to: "1")
    storageMock.save("1", forType: SurveyAssignmentKey.self)

    let result = SurveyManager.presentSurvey(
      survey,
      using: UIViewController(),
      paywallIsDeclined: true,
      paywallInfo: .stub(),
      storage: storageMock,
      completion: {}
    )
    XCTAssertFalse(result)
    XCTAssertTrue(storageMock.didSave)
  }

  func test_presentSurvey_zeroPresentationProbability() {
    let storageMock = StorageMock()

    let survey = Survey.stub()
      .setting(\.presentationProbability, to: 0)

    let result = SurveyManager.presentSurvey(
      survey,
      using: UIViewController(),
      paywallIsDeclined: true,
      paywallInfo: .stub(),
      storage: storageMock,
      completion: {}
    )
    XCTAssertFalse(result)
    XCTAssertTrue(storageMock.didSave)
  }

  func test_presentSurvey_success() {
    let storageMock = StorageMock()
    storageMock.reset()

    let survey = Survey.stub()
      .setting(\.presentationProbability, to: 1)

    let result = SurveyManager.presentSurvey(
      survey,
      using: UIViewController(),
      paywallIsDeclined: true,
      paywallInfo: .stub(),
      storage: storageMock,
      completion: {}
    )
    XCTAssertTrue(result)
  }
}
