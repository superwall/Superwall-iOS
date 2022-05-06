//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

struct TriggerSession: Encodable {
  /// Trigger session ID
  var id = UUID().uuidString

  /// The id of the request
  let configRequestId: String

  /// The start time of the trigger session
  let startAt: Date = Date()

  ///  The end time of the trigger session
  var endAt: Date?

  /// The most on device user attributes
  var userAttributes: JSON?

  enum PresentationOutcome: String, Encodable {
    case paywall = "PAYWALL"
    case holdout = "HOLDOUT"
    case noRuleMatch = "NO_RULE_MATCH"
  }
  let presentationOutcome: PresentationOutcome

  /// Info about the trigger for the trigger session
  var trigger: Trigger

  /// Paywall info
  var paywall: Paywall?

  /// Available products
  var products: Products

  /// The transaction associated with the paywall
  var transaction: Transaction?

  var appSession: AppSession

  enum CodingKeys: String, CodingKey {
    case id = "trigger_session_id"
    case configRequestId = "config_request_id"
    case startAt = "trigger_session_start_ts"
    case endAt = "trigger_session_end_ts"
    case presentationOutcome = "trigger_session_presentation_outcome"
    case userAttributes = "user_attributes"
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(configRequestId, forKey: .configRequestId)
    try container.encode(startAt, forKey: .startAt)
    try container.encodeIfPresent(endAt, forKey: .endAt)
    try container.encodeIfPresent(userAttributes, forKey: .userAttributes)
    try container.encode(presentationOutcome, forKey: .presentationOutcome)

    try trigger.encode(to: encoder)
    try paywall?.encode(to: encoder)
    try products.encode(to: encoder)
    try transaction?.encode(to: encoder)
    try appSession.encode(to: encoder)
  }
}
