//
//  ExperimentTemplate.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 09/05/2025.
//

struct ExperimentTemplate: Codable {
  var eventName = "experiment"

  var experimentId: String
  var variantId: String
  var campaignId: String

  enum CodingKeys: String, CodingKey {
    case eventName = "event_name"
    case experimentId
    case variantId
    case campaignId
  }
}
