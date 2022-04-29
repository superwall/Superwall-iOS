//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

struct PaywallSession: Encodable, KeyPathWritable {
  // TODO: Move this id into the header
  /// Paywall session ID
  let id = UUID().uuidString

  /// If the app was closed from the paywall screen. Meaning they saw a paywall and instantly bounced
  var closedFromPaywall: Bool = false

  /// When the user installed the app
  let installAt: String = DeviceHelper.shared.appInstalledAtString

  /// The start time of the paywall session
  let startAt: Date = Date()

  ///  The end time of the paywall session
  var endAt: Date?

  /// The most on device user attributes
  var userAttributes: JSON?

  /// Whether a free trial is available or not
  let isFreeTrialAvailable: Bool

  /// Info about the trigger for the paywall session
  var trigger: Trigger

  /// Info about restoring
  var restore: RestoreInfo?

  /// Paywall nth impressions
  var paywallStats: PaywallStats

  /// Paywall info
  var paywall: Paywall

  /// Available products
  var products: Products

  /// The transaction associated with the paywall
  var transaction: Transaction?

  enum CodingKeys: String, CodingKey {
    case id = "paywall_session_id"
    case startAt = "paywall_session_start_ts"
    case endAt = "paywall_session_end_ts"
    case closedFromPaywall = "app_closed_from_paywall"
    case installAt = "install_ts"
    case userAttributes = "user_properties"
    case isFreeTrialAvailable = "is_free_trial_available"
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(startAt, forKey: .startAt)
    try container.encodeIfPresent(endAt, forKey: .endAt)
    try container.encode(closedFromPaywall, forKey: .closedFromPaywall)
    try container.encode(installAt, forKey: .installAt)
    try container.encodeIfPresent(userAttributes, forKey: .userAttributes)
    try container.encode(isFreeTrialAvailable, forKey: .isFreeTrialAvailable)

    try trigger.encode(to: encoder)
    try restore.encode(to: encoder)
    try paywallStats.encode(to: encoder)
    try products.encode(to: encoder)
    try transaction.encode(to: encoder)
  }
}
