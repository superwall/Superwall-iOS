//
//  File.swift
//
//
//  Created by Yusuf Tör on 16/08/2023.
//

import Foundation
@testable import SuperwallKit
import Testing

struct SurveyTests {
  @Test func shouldAssignHoldout_debuggerLaunched() {
    let survey = Survey.stub()
    let isHoldout = survey.shouldAssignHoldout(
      isDebuggerLaunched: true,
      storage: StorageMock()
    )
    #expect(!isHoldout)
  }

  @Test func shouldAssignHoldout_presentationProbabilityZero() {
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
    #expect(isHoldout)
  }

  @Test func shouldAssignHoldout_presentationProbabilityOne() {
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
    #expect(!isHoldout)
  }

  @Test func shouldAssignHoldout_presentationProbabilityPointFive() {
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
    #expect(isHoldout)
  }

  @Test func hasSeenSurvey_noAssignmentKey() {
    let survey: Survey = .stub()
    let storage = StorageMock()
    let hasSeen = survey.hasSeenSurvey(storage: storage)
    #expect(!hasSeen)
  }

  @Test func hasSeenSurvey_sameAssignmentKey() {
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
    #expect(hasSeen)
  }

  @Test func hasSeenSurvey_diffAssignmentKey() {
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
    #expect(!hasSeen)
  }
}
