//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/08/2023.
//

@testable import SuperwallKit
import XCTest

@available(iOS 14.0, *)
final class SurveyTests: XCTestCase {
  func test_shouldAssignHoldout_debuggerLaunched() {
    let survey = Survey.stub()
    let isHoldout = survey.shouldAssignHoldout(
      isDebuggerLaunched: true,
      storage: StorageMock()
    )
    XCTAssertFalse(isHoldout)
  }

  func test_shouldAssignHoldout_presentationProbabilityZero() {
    let survey = Survey(
      id: UUID().uuidString,
      assignmentKey: "abc",
      title: "test",
      message: "test",
      options: [.stub()],
      presentationProbability: 0,
      includeOtherOption: true,
      includeCloseOption: true,
      presentationCondition: .onManualClose
    )
    let isHoldout = survey.shouldAssignHoldout(
      isDebuggerLaunched: false,
      storage: StorageMock()
    )
    XCTAssertTrue(isHoldout)
  }

  func test_shouldAssignHoldout_presentationProbabilityOne() {
    let survey = Survey(
      id: UUID().uuidString,
      assignmentKey: "abc",
      title: "test",
      message: "test",
      options: [.stub()],
      presentationProbability: 1,
      includeOtherOption: true,
      includeCloseOption: true,
      presentationCondition: .onManualClose
    )
    let isHoldout = survey.shouldAssignHoldout(
      isDebuggerLaunched: false,
      storage: StorageMock()
    )
    XCTAssertFalse(isHoldout)
  }

  func test_shouldAssignHoldout_presentationProbabilityPointFive() {
    let survey = Survey(
      id: UUID().uuidString,
      assignmentKey: "abc",
      title: "test",
      message: "test",
      options: [.stub()],
      presentationProbability: 0.4,
      includeOtherOption: true,
      includeCloseOption: true,
      presentationCondition: .onManualClose
    )
    func random(in: Range<Double>) -> Double {
      return 0.5
    }
    let isHoldout = survey.shouldAssignHoldout(
      isDebuggerLaunched: false,
      storage: StorageMock(),
      randomiser: random(in:)
    )
    XCTAssertTrue(isHoldout)
  }

  func test_hasSeenSurvey_noAssignmentKey() {
    let survey: Survey = .stub()
    let storage = StorageMock()
    let hasSeen = survey.hasSeenSurvey(storage: storage)
    XCTAssertFalse(hasSeen)
  }

  func test_hasSeenSurvey_sameAssignmentKey() {
    let survey = Survey(
      id: UUID().uuidString,
      assignmentKey: "abc",
      title: "test",
      message: "test",
      options: [.stub()],
      presentationProbability: 0.4,
      includeOtherOption: true,
      includeCloseOption: true,
      presentationCondition: .onManualClose
    )
    let existingAssignmentKey = "abc"
    let storage = StorageMock(internalSurveyAssignmentKey: existingAssignmentKey)
    let hasSeen = survey.hasSeenSurvey(storage: storage)
    XCTAssertTrue(hasSeen)
  }

  func test_hasSeenSurvey_diffAssignmentKey() {
    let survey = Survey(
      id: UUID().uuidString,
      assignmentKey: "cde",
      title: "test",
      message: "test",
      options: [.stub()],
      presentationProbability: 0.4,
      includeOtherOption: true,
      includeCloseOption: true,
      presentationCondition: .onManualClose
    )
    let existingAssignmentKey = "abc"
    let storage = StorageMock(internalSurveyAssignmentKey: existingAssignmentKey)
    let hasSeen = survey.hasSeenSurvey(storage: storage)
    XCTAssertFalse(hasSeen)
  }
}
