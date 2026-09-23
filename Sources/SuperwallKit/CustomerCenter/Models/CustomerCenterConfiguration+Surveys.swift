//
//  CustomerCenterConfiguration+Surveys.swift
//
//
//  Created by Yusuf Tör on 23/09/2026.
//

import Foundation

public extension CustomerCenterConfiguration.FeedbackSurvey {
  /// The built-in cancellation survey, as used by the default configuration: "Why are you
  /// cancelling?" with the three built-in options, all localized.
  static var cancellation: CustomerCenterConfiguration.FeedbackSurvey {
    CustomerCenterConfiguration.FeedbackSurvey(
      id: "cancel_survey",
      options: [.tooExpensive, .dontUse, .boughtByMistake]
    )
  }
}

public extension CustomerCenterConfiguration.FeedbackSurvey.Option {
  /// "Too expensive", localized.
  static var tooExpensive: CustomerCenterConfiguration.FeedbackSurvey.Option { .init(id: "too_expensive") }
  /// "Don't use the app", localized.
  static var dontUse: CustomerCenterConfiguration.FeedbackSurvey.Option { .init(id: "dont_use") }
  /// "Bought by mistake", localized.
  static var boughtByMistake: CustomerCenterConfiguration.FeedbackSurvey.Option { .init(id: "bought_by_mistake") }
}
