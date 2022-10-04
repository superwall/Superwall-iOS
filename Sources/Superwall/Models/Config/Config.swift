//
//  Config.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct Config: Decodable {
  var triggers: Set<Trigger>
  var paywalls: [Paywall]
  var logLevel: Int
  var postback: PostbackRequest
  var locales: Set<String>
  var appSessionTimeout: Milliseconds
  var featureFlags: FeatureFlags

  var requestId: String?

  enum CodingKeys: String, CodingKey {
    case triggers = "triggerOptions"
    case paywalls = "paywallReponses"
    case logLevel
    case postback
    case localization
    case appSessionTimeout = "appSessionTimeoutMs"
    case featureFlags = "toggles"
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    triggers = try values.decode(Set<Trigger>.self, forKey: .triggers)
    paywalls = try values.decode([Paywall].self, forKey: .paywalls)
    logLevel = try values.decode(Int.self, forKey: .logLevel)
    postback = try values.decode(PostbackRequest.self, forKey: .postback)
    appSessionTimeout = try values.decode(Milliseconds.self, forKey: .appSessionTimeout)
    featureFlags = try FeatureFlags(from: decoder)

    let localization = try values.decode(LocalizationConfig.self, forKey: .localization)
    locales = Set(localization.locales.map { $0.locale })
  }

  init(
    triggers: Set<Trigger>,
    paywalls: [Paywall],
    logLevel: Int,
    postback: PostbackRequest,
    locales: Set<String>,
    appSessionTimeout: Milliseconds,
    featureFlags: FeatureFlags
  ) {
    self.triggers = triggers
    self.paywalls = paywalls
    self.logLevel = logLevel
    self.postback = postback
    self.locales = locales
    self.appSessionTimeout = appSessionTimeout
    self.featureFlags = featureFlags
  }
}

// MARK: - Stubbable
extension Config: Stubbable {
  static func stub() -> Config {
    return Config(
      triggers: [.stub()],
      paywalls: [.stub()],
      logLevel: 0,
      postback: .stub(),
      locales: [],
      appSessionTimeout: 3600000,
      featureFlags: .stub()
    )
  }
}
