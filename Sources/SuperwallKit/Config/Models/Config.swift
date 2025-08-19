//
//  Config.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct Config: Codable, Equatable {
  var buildId: String
  var triggers: Set<Trigger>
  var paywalls: [Paywall]
  var logLevel: Int
  var locales: Set<String>
  var appSessionTimeout: Milliseconds
  var featureFlags: FeatureFlags
  var preloadingDisabled: PreloadingDisabled
  var requestId: String?
  var attribution: Attribution?
  var products: [Product]
  var web2appConfig: Web2AppConfig?
  var allComputedProperties: [ComputedPropertyRequest] {
    return triggers.flatMap {
      $0.audiences.flatMap {
        $0.computedPropertyRequests
      }
    }
  }
  var iosAppId: String?

  struct Web2AppConfig: Codable, Equatable {
    let entitlementsMaxAge: Seconds
    let restoreAccessURL: URL

    enum CodingKeys: String, CodingKey {
      case entitlementsMaxAgeMs = "entitlementsMaxAgeMs"
      case restoreAccessURL = "restoreAccessUrl"
    }

    init(
      entitlementsMaxAge: Seconds,
      restoreAccessURL: URL
    ) {
      self.entitlementsMaxAge = entitlementsMaxAge
      self.restoreAccessURL = restoreAccessURL
    }

    init(from decoder: Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      let entitlementsMaxAgeMs = try values.decode(Milliseconds.self, forKey: .entitlementsMaxAgeMs)
      entitlementsMaxAge = entitlementsMaxAgeMs / 1000

      let restoreAccessURLString = try values.decode(String.self, forKey: .restoreAccessURL)
      if let url = URL(string: restoreAccessURLString) {
        restoreAccessURL = url
      } else {
        // Should never reach here but just incase.
        // swiftlint:disable:next force_unwrapping
        restoreAccessURL = URL(string: "https://superwall.com")!
      }
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode((entitlementsMaxAge * 1000), forKey: .entitlementsMaxAgeMs)
      try container.encode(restoreAccessURL.absoluteString, forKey: .restoreAccessURL)
    }
  }

  enum CodingKeys: String, CodingKey {
    case requestId
    case buildId
    case triggers = "triggerOptions"
    case paywalls = "paywallResponses"
    case logLevel
    case localization
    case appSessionTimeout = "appSessionTimeoutMs"
    case featureFlags = "toggles"
    case preloadingDisabled = "disablePreload"
    case attribution = "attributionOptions"
    case products = "products"
    case web2appConfig
    case iosAppId
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    buildId = try values.decode(String.self, forKey: .buildId)
    triggers = try values.decode(Set<Trigger>.self, forKey: .triggers)
    paywalls = try values.decode([Paywall].self, forKey: .paywalls)
    logLevel = try values.decode(Int.self, forKey: .logLevel)
    appSessionTimeout = try values.decode(Milliseconds.self, forKey: .appSessionTimeout)
    featureFlags = try FeatureFlags(from: decoder)
    preloadingDisabled = try values.decode(PreloadingDisabled.self, forKey: .preloadingDisabled)
    attribution = try values.decodeIfPresent(Attribution.self, forKey: .attribution)
    web2appConfig = try values.decodeIfPresent(Web2AppConfig.self, forKey: .web2appConfig)
    iosAppId = try values.decodeIfPresent(String.self, forKey: .iosAppId)

    let localization = try values.decode(LocalizationConfig.self, forKey: .localization)
    locales = Set(localization.locales.map { $0.locale })
    requestId = try values.decodeIfPresent(String.self, forKey: .requestId)

    let products = try values.decodeIfPresent(
      [Throwable<Product>].self,
      forKey: .products
    ) ?? []
    self.products = products.compactMap { try? $0.result.get() }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(buildId, forKey: .buildId)
    try container.encode(triggers, forKey: .triggers)
    try container.encode(paywalls, forKey: .paywalls)
    try container.encode(logLevel, forKey: .logLevel)
    try container.encode(appSessionTimeout, forKey: .appSessionTimeout)
    try container.encode(preloadingDisabled, forKey: .preloadingDisabled)
    try container.encodeIfPresent(attribution, forKey: .attribution)

    if !products.isEmpty {
      try container.encode(products, forKey: .products)
    }

    let localizationConfig = LocalizationConfig(locales: locales.map { LocalizationConfig.LocaleConfig(locale: $0) })
    try container.encode(localizationConfig, forKey: .localization)

    try featureFlags.encode(to: encoder)
    try container.encodeIfPresent(requestId, forKey: .requestId)
  }

  init(
    buildId: String,
    triggers: Set<Trigger>,
    paywalls: [Paywall],
    logLevel: Int,
    locales: Set<String>,
    appSessionTimeout: Milliseconds,
    featureFlags: FeatureFlags,
    preloadingDisabled: PreloadingDisabled,
    attribution: Attribution,
    products: [Product]
  ) {
    self.buildId = buildId
    self.triggers = triggers
    self.paywalls = paywalls
    self.logLevel = logLevel
    self.locales = locales
    self.appSessionTimeout = appSessionTimeout
    self.featureFlags = featureFlags
    self.preloadingDisabled = preloadingDisabled
    self.attribution = attribution
    self.products = products
  }
}

// MARK: - Stubbable
extension Config: Stubbable {
  static func stub() -> Config {
    return Config(
      buildId: "poWduJZYQbCA8QbWLrjJC",
      triggers: [.stub()],
      paywalls: [.stub()],
      logLevel: 0,
      locales: [],
      appSessionTimeout: 3600000,
      featureFlags: .stub(),
      preloadingDisabled: .stub(),
      attribution: .init(appleSearchAds: .init(enabled: true)),
      products: []
    )
  }
}
