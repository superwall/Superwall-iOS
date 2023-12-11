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
  var enablePostback: Bool
  var enableExpressionParameters: Bool
  var enableUserIdSeed: Bool
  var disableVerboseEvents: Bool

  enum CodingKeys: String, CodingKey {
    case toggles
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    let rawFeatureFlags = try values.decode([RawFeatureFlag].self, forKey: .toggles)

    enableSessionEvents = rawFeatureFlags.value(forKey: "enable_session_events", default: false)
    enableExpressionParameters = rawFeatureFlags.value(forKey: "enable_expression_params", default: false)
    enablePostback = rawFeatureFlags.value(forKey: "enable_postback", default: false)
    enableUserIdSeed = rawFeatureFlags.value(forKey: "enable_userid_seed", default: false)
    disableVerboseEvents = rawFeatureFlags.value(forKey: "disable_verbose_events", default: false)
  }

  init(
    enableSessionEvents: Bool,
    enablePostback: Bool,
    enableExpressionParameters: Bool,
    enableUserIdSeed: Bool,
    disableVerboseEvents: Bool
  ) {
    self.enableSessionEvents = enableSessionEvents
    self.enablePostback = enablePostback
    self.enableExpressionParameters = enableExpressionParameters
    self.enableUserIdSeed = enableUserIdSeed
    self.disableVerboseEvents = disableVerboseEvents
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
      enablePostback: true,
      enableExpressionParameters: true,
      enableUserIdSeed: true,
      disableVerboseEvents: true
    )
  }
}
