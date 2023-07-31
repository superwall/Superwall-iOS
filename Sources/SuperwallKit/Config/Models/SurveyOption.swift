//
//  File.swift
//  
//
//  Created by Yusuf Tör on 31/07/2023.
//

import Foundation

@objc(SWKSurveyOption)
@objcMembers
final public class SurveyOption: NSObject, Decodable {
  /// The id of the survey option.
  public let id: String

  /// The title of the survey option.
  public let title: String

  init(id: String, title: String) {
    self.id = id
    self.title = title
  }
}

// MARK: - Stubbable
extension SurveyOption: Stubbable {
  static func stub() -> SurveyOption {
    return SurveyOption(
      id: UUID().uuidString,
      title: "abc"
    )
  }
}
