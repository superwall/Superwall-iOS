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
  // TODO: Comment this
  /// The id of the survey.
  public let id: String

  /// The assigned key for the survey.
  ///
  /// A user will only see one survey per assignment key.
  public let assignmentKey: String

  /// The title of the survey's alert controller.
  public let title: String

  /// The message of the survey's alert controller.
  public let message: String

  /// The options to display in the alert controller.
  public let options: [SurveyOption]

  /// The probability that the survey will present to the user.
  public let presentationProbability: Double
  public let locale: String
  public let includeOtherOption: Bool

  /// Rolls dice to see if survey should present.
  func shouldPresent(storage: Storage) -> Bool {
    // If survey with assignment key already seen, don't present.
    guard storage.get(SurveyAssignmentKey.self) == nil else {
      return false
    }

    let randomNumber = Double.random(in: 0...1)
    guard randomNumber <= presentationProbability else {
      return false
    }

    return true
  }
  private static let maxOptions = 4

  init(
    id: String,
    assignmentKey: String,
    title: String,
    message: String,
    options: [SurveyOption],
    presentationProbability: Double,
    locale: String,
    includeOtherOption: Bool
  ) {
    self.id = id
    self.assignmentKey = assignmentKey
    self.title = title
    self.message = message
    self.options = options
    self.presentationProbability = presentationProbability
    self.locale = locale
    self.includeOtherOption = includeOtherOption
  }

  func getShuffledOptions() -> [SurveyOption] {
    // Shuffle options
    var options = options
    options.shuffle()

    // Make sure there aren't more than the max amount.
    if options.count > Self.maxOptions {
      let excess = options.count - Self.maxOptions
      options = options.dropLast(excess)
    }
    return options
  }
}

@objc(SWKSurveyOption)
@objcMembers
final public class SurveyOption: NSObject, Decodable {
  public let id: String
  public let title: String

  init(id: String, title: String) {
    self.id = id
    self.title = title
  }
}
