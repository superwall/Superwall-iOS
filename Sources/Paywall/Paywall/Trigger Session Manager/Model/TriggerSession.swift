//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

struct TriggerSession: Codable {
  /// Trigger session ID
  var id = UUID().uuidString

  /// The id of the request
  let configRequestId: String

  /// The start time of the trigger session
  var startAt: Date = Date()

  ///  The end time of the trigger session
  var endAt: Date?

  /// The most on device user attributes
  var userAttributes: JSON?

  enum PresentationOutcome: String, Codable {
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

  init(
    configRequestId: String,
    userAttributes: JSON?,
    presentationOutcome: PresentationOutcome,
    trigger: Trigger,
    paywall: Paywall?,
    products: Products,
    appSession: AppSession
  ) {
    self.configRequestId = configRequestId
    self.userAttributes = userAttributes
    self.presentationOutcome = presentationOutcome
    self.trigger = trigger
    self.paywall = paywall
    self.products = products
    self.appSession = appSession
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    configRequestId = try values.decode(String.self, forKey: .configRequestId)
    startAt = try values.decode(Date.self, forKey: .startAt)
    endAt = try values.decodeIfPresent(Date.self, forKey: .endAt)
    userAttributes = try values.decodeIfPresent(JSON.self, forKey: .userAttributes)
    presentationOutcome = try values.decode(PresentationOutcome.self, forKey: .presentationOutcome)

    trigger = try Trigger(from: decoder)
    paywall = try? Paywall(from: decoder)
    products = try Products(from: decoder)
    transaction = try? Transaction(from: decoder)
    appSession = try AppSession(from: decoder)
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
