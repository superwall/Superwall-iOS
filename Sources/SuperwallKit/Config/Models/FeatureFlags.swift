//
//  File.swift
//  
//
//  Created by Yusuf Tör on 25/08/2022.
//

import Foundation

struct RawFeatureFlag: Decodable {
  let key: String
  let enabled: Bool
}

struct FeatureFlags: Decodable {
  var enableSessionEvents: Bool
  var enableExpressionParameters: Bool
  var enableUserIdSeed: Bool
  var disableVerbosePlacements: Bool
  var enableSuppressesIncrementalRendering: Bool
  var enableThrottleSchedulingPolicy: Bool
  var enableNoneSchedulingPolicy: Bool
  var enableMultiplePaywallUrls: Bool
  var enableConfigRefresh: Bool
  var enableTextInteraction: Bool

  enum CodingKeys: String, CodingKey {
    case toggles
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    let rawFeatureFlags = try values.decode([RawFeatureFlag].self, forKey: .toggles)

    enableSessionEvents = rawFeatureFlags.value(forKey: "enable_session_events", default: false)
    enableExpressionParameters = rawFeatureFlags.value(forKey: "enable_expression_params", default: false)
    enableUserIdSeed = rawFeatureFlags.value(forKey: "enable_userid_seed", default: false)
    disableVerbosePlacements = rawFeatureFlags.value(forKey: "disable_verbose_events", default: false)
    enableSuppressesIncrementalRendering = rawFeatureFlags.value(
      forKey: "enable_suppresses_incremental_rendering",
      default: false
    )
    enableThrottleSchedulingPolicy = rawFeatureFlags.value(forKey: "enable_throttle_scheduling_policy", default: false)
    enableNoneSchedulingPolicy = rawFeatureFlags.value(forKey: "enable_none_scheduling_policy", default: false)
    enableMultiplePaywallUrls = rawFeatureFlags.value(forKey: "enable_multiple_paywall_urls", default: false)
    enableConfigRefresh = rawFeatureFlags.value(forKey: "enable_config_refresh", default: false)
    enableTextInteraction = rawFeatureFlags.value(forKey: "enable_text_interaction", default: false)
  }

  init(
    enableSessionEvents: Bool,
    enableExpressionParameters: Bool,
    enableUserIdSeed: Bool,
    disableVerbosePlacements: Bool,
    enableSuppressesIncrementalRendering: Bool,
    enableThrottleSchedulingPolicy: Bool,
    enableNoneSchedulingPolicy: Bool,
    enableMultiplePaywallUrls: Bool,
    enableConfigRefresh: Bool,
    enableTextInteraction: Bool
  ) {
    self.enableSessionEvents = enableSessionEvents
    self.enableExpressionParameters = enableExpressionParameters
    self.enableUserIdSeed = enableUserIdSeed
    self.disableVerbosePlacements = disableVerbosePlacements
    self.enableSuppressesIncrementalRendering = enableSuppressesIncrementalRendering
    self.enableThrottleSchedulingPolicy = enableThrottleSchedulingPolicy
    self.enableNoneSchedulingPolicy = enableNoneSchedulingPolicy
    self.enableMultiplePaywallUrls = enableMultiplePaywallUrls
    self.enableConfigRefresh = enableConfigRefresh
    self.enableTextInteraction = enableTextInteraction
  }
}

// MARK: - Collection Feature Flag Extension
extension Collection where Element == RawFeatureFlag {
  func value(
    forKey key: String,
    default defaultExpression: @autoclosure () -> Bool
  ) -> Bool {
    let featureFlag = first { $0.key == key }
    return featureFlag?.enabled ?? defaultExpression()
  }
}

// MARK: - Stubbable
extension FeatureFlags: Stubbable {
  static func stub() -> FeatureFlags {
    return FeatureFlags(
      enableSessionEvents: true,
      enableExpressionParameters: true,
      enableUserIdSeed: true,
      disableVerbosePlacements: true,
      enableSuppressesIncrementalRendering: true,
      enableThrottleSchedulingPolicy: true,
      enableNoneSchedulingPolicy: true,
      enableMultiplePaywallUrls: true,
      enableConfigRefresh: true,
      enableTextInteraction: true
    )
  }
}
