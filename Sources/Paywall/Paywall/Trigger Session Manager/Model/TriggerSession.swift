//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

/// This represents the possibilty of a trigger being fired.
struct TriggerSession: Codable {
  /// Trigger session ID
  var id = UUID().uuidString

  /// The id of the request
  let configRequestId: String

  /// The start time of the trigger session
  var startAt = Date()

  ///  The end time of the trigger session
  var endAt: Date?

  /// The most on device user attributes
  var userAttributes: JSON?

  /// Indicates whether the user has an active subscription or not.
  var isSubscribed: Bool

  enum PresentationOutcome: String, Codable {
    case paywall = "PAYWALL"
    case holdout = "HOLDOUT"
    case noRuleMatch = "NO_RULE_MATCH"
  }
  var presentationOutcome: PresentationOutcome?

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
    case isSubscribed = "user_is_subscribed"
  }

  init(
    configRequestId: String,
    userAttributes: JSON?,
    isSubscribed: Bool,
    presentationOutcome: PresentationOutcome? = nil,
    trigger: Trigger,
    paywall: Paywall? = nil,
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
    self.isSubscribed = isSubscribed
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    configRequestId = try values.decode(String.self, forKey: .configRequestId)
    startAt = try values.decode(Date.self, forKey: .startAt)
    endAt = try values.decodeIfPresent(Date.self, forKey: .endAt)
    userAttributes = try values.decodeIfPresent(JSON.self, forKey: .userAttributes)
    presentationOutcome = try values.decodeIfPresent(PresentationOutcome.self, forKey: .presentationOutcome)
    isSubscribed = try values.decode(Bool.self, forKey: .isSubscribed)

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
    try container.encode(isSubscribed, forKey: .isSubscribed)
    try container.encodeIfPresent(endAt, forKey: .endAt)
    try container.encodeIfPresent(userAttributes, forKey: .userAttributes)
    try container.encodeIfPresent(presentationOutcome, forKey: .presentationOutcome)

    try trigger.encode(to: encoder)
    try paywall?.encode(to: encoder)
    try products.encode(to: encoder)
    try transaction?.encode(to: encoder)
    try appSession.encode(to: encoder)
  }
}
