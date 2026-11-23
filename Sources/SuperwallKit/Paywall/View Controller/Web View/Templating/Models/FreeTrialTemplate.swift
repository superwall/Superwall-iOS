//
//  TemplateSubstitutionPrefix.swift
//  Superwall
//
//  Created by Yusuf Tör on 28/02/2022.
//

#if canImport(WebKit)
import Foundation

struct FreeTrialTemplate: Codable {
  var eventName: String
  // Right now can be `null` or `freeTrial`
  var prefix: String?

  enum CodingKeys: String, CodingKey {
    case eventName = "event_name"
    case prefix
  }
}
#endif
