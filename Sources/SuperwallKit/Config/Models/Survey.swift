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

  /// Rolls dice to see if survey should present.
  func shouldPresent(storage: Storage) -> Bool {
    // Return immediately if no chance to present.
    if presentationProbability == 0 {
      return false
    }

    // Choose random number to present the survey with
    // the probability of presentationProbability.
    let randomNumber = Double.random(in: 0..<1)
    guard randomNumber < presentationProbability else {
      return false
    }
    // If survey with assignment key already seen, don't present.
    let existingAssignmentKey = storage.get(SurveyAssignmentKey.self)

    guard existingAssignmentKey == nil || existingAssignmentKey != assignmentKey else {
      return false
    }

    return true
  }

  init(
    id: String,
    assignmentKey: String,
    title: String,
    message: String,
    options: [SurveyOption],
    presentationProbability: Double,
    includeOtherOption: Bool
  ) {
    self.id = id
    self.assignmentKey = assignmentKey
    self.title = title
    self.message = message
    self.options = options
    self.presentationProbability = presentationProbability
    self.includeOtherOption = includeOtherOption
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
      includeOtherOption: true
    )
  }
}
