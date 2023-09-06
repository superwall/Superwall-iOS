//
//  File.swift
//  
//
//  Created by Yusuf Tör on 25/07/2023.
//

import Foundation

@objc(SWKSurvey)
@objcMembers
final public class Survey: NSObject, Decodable {
  /// The id of the survey.
  public let id: String

  /// The assigned key for the survey.
  ///
  /// A user will only see one survey per assignment key.
  public internal(set) var assignmentKey: String

  /// The title of the survey's alert controller.
  public let title: String

  /// The message of the survey's alert controller.
  public let message: String

  /// The options to display in the alert controller.
  public let options: [SurveyOption]

  /// The probability that the survey will present to the user.
  public internal(set) var presentationProbability: Double

  /// Whether the "Other" option should appear to allow a user to provide a custom
  /// response.
  public let includeOtherOption: Bool

  /// Whether a close button should appear to allow users to skip the survey.
  public let includeCloseButton: Bool

  /// Rolls dice to see if survey should present or is in holdout.
  ///
  /// - Returns: `true` if user is in holdout, false if survey should present.
  func shouldAssignHoldout(
    isDebuggerLaunched: Bool,
    storage: Storage,
    randomiser: (Range<Double>) -> Double = Double.random
  ) -> Bool {
    if isDebuggerLaunched {
      return false
    }
    // Return immediately if no chance to present.
    if presentationProbability == 0 {
      return true
    }

    // Choose random number to present the survey with
    // the probability of presentationProbability.
    let randomNumber = randomiser(0..<1)
    guard randomNumber < presentationProbability else {
      return true
    }

    return false
  }

  /// Determines whether a survey with the same `assignmentKey` has been
  /// seen before.
  func hasSeenSurvey(storage: Storage) -> Bool {
    let existingAssignmentKey = storage.get(SurveyAssignmentKey.self)

    if existingAssignmentKey == nil {
      return false
    }

    if existingAssignmentKey == assignmentKey {
      return true
    }

    return false
  }

  init(
    id: String,
    assignmentKey: String,
    title: String,
    message: String,
    options: [SurveyOption],
    presentationProbability: Double,
    includeOtherOption: Bool,
    includeCloseButton: Bool
  ) {
    self.id = id
    self.assignmentKey = assignmentKey
    self.title = title
    self.message = message
    self.options = options
    self.presentationProbability = presentationProbability
    self.includeOtherOption = includeOtherOption
    self.includeCloseButton = includeCloseButton
  }
}

// MARK: - Stubbable
extension Survey: Stubbable {
  static func stub() -> Survey {
    return Survey(
      id: UUID().uuidString,
      assignmentKey: "abc",
      title: "test",
      message: "test",
      options: [.stub()],
      presentationProbability: 1,
      includeOtherOption: true,
      includeCloseButton: true
    )
  }
}
