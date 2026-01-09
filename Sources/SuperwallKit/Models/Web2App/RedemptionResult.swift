//
//  RedemptionResult.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 14/03/2025.
//
// swiftlint:disable type_body_length file_length

import Foundation

/// The result of redeeming a code via web checkout.
public enum RedemptionResult: Codable {
  /// The redemption succeeded.
  case success(code: String, redemptionInfo: RedemptionInfo)

  /// The redemption failed.
  case error(code: String, error: ErrorInfo)

  /// The code has expired.
  case expiredCode(code: String, info: ExpiredCodeInfo)

  /// The code is invalid.
  case invalidCode(code: String)

  /// The subscription that the code redeems has expired.
  case expiredSubscription(code: String, redemptionInfo: RedemptionInfo)

  /// Convenience variable to get the stripe subscription IDs.
  public var stripeSubscriptionIds: [String]? {
    switch self {
    case let .success(_, info):
      switch info.purchaserInfo.storeIdentifiers {
      case .stripe(_, let subscriptionIds):
        return subscriptionIds
      default:
        return nil
      }
    default:
      return nil
    }
  }

  /// Convenience variable to extract the code
  var code: String {
    switch self {
    case let .success(code, _),
      let .error(code, _),
      let .expiredCode(code, _),
      let .invalidCode(code),
      let .expiredSubscription(code, _):
      return code
    }
  }

  /// The error info.
  public struct ErrorInfo: Codable {
    /// The message of the error.
    public let message: String

    func toObjc() -> RedemptionResultObjc.ErrorInfo {
      return RedemptionResultObjc.ErrorInfo(message: self.message)
    }
  }

  /// Info about the expired code.
  public struct ExpiredCodeInfo: Codable {
    /// A boolean indicating whether the redemption email has been resent.
    public let resent: Bool

    /// An optional `String` indicated the obfuscated email address that the
    /// redemption email was sent to.
    public let obfuscatedEmail: String?

    public func toObjc() -> RedemptionResultObjc.ExpiredCodeInfo {
      return RedemptionResultObjc.ExpiredCodeInfo(
        resent: self.resent,
        obfuscatedEmail: self.obfuscatedEmail
      )
    }
  }

  /// Information about the redemption.
  public struct RedemptionInfo: Codable {
    /// The ownership of the code.
    public let ownership: Ownership

    /// Info about the purchaser.
    public let purchaserInfo: PurchaserInfo

    /// Info about the paywall the purchase was made from.
    public let paywallInfo: PaywallInfo?

    /// The entitlements array
    public let entitlements: Set<Entitlement>

    /// Enum specifiying code ownership.
    public enum Ownership: Codable {
      /// The code belongs to the identified user.
      case appUser(appUserId: String)

      /// The code belongs to the device.
      case device(deviceId: String)

      private enum CodingKeys: String, CodingKey {
        case type
        case appUserId
        case deviceId
      }

      enum OwnershipType: String, Codable {
        case appUser = "APP_USER"
        case device = "DEVICE"
      }

      public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(OwnershipType.self, forKey: .type)

        switch type {
        case .appUser:
          let appUserId = try container.decode(String.self, forKey: .appUserId)
          self = .appUser(appUserId: appUserId)
        case .device:
          let deviceId = try container.decode(String.self, forKey: .deviceId)
          self = .device(deviceId: deviceId)
        }
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .appUser(let appUserId):
          try container.encode(OwnershipType.appUser, forKey: .type)
          try container.encode(appUserId, forKey: .appUserId)

        case .device(let deviceId):
          try container.encode(OwnershipType.device, forKey: .type)
          try container.encode(deviceId, forKey: .deviceId)
        }
      }

      func toObjc() -> RedemptionResultObjc.Ownership {
        switch self {
        case .appUser(let appUserId):
          return RedemptionResultObjc.Ownership(appUserId: appUserId)
        case .device(let deviceId):
          return RedemptionResultObjc.Ownership(deviceId: deviceId)
        }
      }
    }

    /// Info about the purchaser.
    public struct PurchaserInfo: Codable {
      /// The app user ID of the purchaser.
      public let appUserId: String

      /// The email address of the purchaser.
      public let email: String?

      /// The identifiers of the store that was purchased from.
      public let storeIdentifiers: StoreIdentifiers

      /// Identifiers of the store that was purchased from.
      public enum StoreIdentifiers: Codable {
        /// The subscription was purchased via Stripe.
        case stripe(customerId: String, subscriptionIds: [String])

        /// The subscription was purchased via Paddle.
        case paddle(customerId: String, subscriptionIds: [String])

        /// The subscription was purchased from an unknown store type.
        case unknown(store: String, additionalInfo: [String: Any])

        private enum CodingKeys: String, CodingKey, CaseIterable {
          case store
          case stripeCustomerId
          case stripeSubscriptionIds
          case paddleCustomerId
          case paddleSubscriptionIds
        }

        struct DynamicCodingKey: CodingKey {
          var stringValue: String
          var intValue: Int?

          init?(intValue: Int) { nil }
          init?(stringValue: String) { self.stringValue = stringValue }
        }

        public init(from decoder: Decoder) throws {
          let container = try decoder.container(keyedBy: CodingKeys.self)
          let store = try container.decode(String.self, forKey: .store)

          switch store {
          case "STRIPE":
            let stripeCustomerId = try container.decode(String.self, forKey: .stripeCustomerId)
            let stripeSubscriptionIds = try container.decode([String].self, forKey: .stripeSubscriptionIds)
            self = .stripe(
              customerId: stripeCustomerId,
              subscriptionIds: stripeSubscriptionIds
            )
          case "PADDLE":
            let paddleCustomerId = try container.decode(String.self, forKey: .paddleCustomerId)
            let paddleSubscriptionIds = try container.decode([String].self, forKey: .paddleSubscriptionIds)
            self = .paddle(
              customerId: paddleCustomerId,
              subscriptionIds: paddleSubscriptionIds
            )
          default:
            // Decode entire JSON payload to capture additional fields
            let json = try JSON(from: decoder)
            // Explicitly remove known keys
            var additionalInfo = json
            for key in CodingKeys.allCases.map({ $0.rawValue }) {
              additionalInfo.dictionaryObject?.removeValue(forKey: key)
            }

            self = .unknown(store: store, additionalInfo: additionalInfo.dictionaryObject ?? [:])
          }
        }

        public func encode(to encoder: Encoder) throws {
          var container = encoder.container(keyedBy: CodingKeys.self)

          switch self {
          case let .paddle(customerId, subscriptionIds):
            try container.encode("PADDLE", forKey: .store)
            try container.encode(customerId, forKey: .paddleCustomerId)
            try container.encode(subscriptionIds, forKey: .paddleSubscriptionIds)
          case let .stripe(customerId, subscriptionIds):
            try container.encode("STRIPE", forKey: .store)
            try container.encode(customerId, forKey: .stripeCustomerId)
            try container.encode(subscriptionIds, forKey: .stripeSubscriptionIds)
          case let .unknown(store, additionalInfo):
            try container.encode(store, forKey: .store)

            // Create a dynamic coding container to encode arbitrary keys and values
            var dynamicContainer = encoder.container(keyedBy: DynamicCodingKey.self)

            // Iterate over each key-value pair in the additional JSON info
            for (key, value) in JSON(additionalInfo).dictionaryValue {
              // Skip keys that are already explicitly defined in `CodingKeys`
              guard !CodingKeys.allCases.map({ $0.rawValue }).contains(key) else { continue }

              // Create a dynamic coding key from the current key string
              if let dynamicKey = DynamicCodingKey(stringValue: key) {
                // Encode the JSON value associated with the dynamic key
                try dynamicContainer.encode(value, forKey: dynamicKey)
              }
            }
          }
        }

        func toObjc() -> RedemptionResultObjc.StoreIdentifiers {
          switch self {
          case let .stripe(customerId, subscriptionIds):
            return RedemptionResultObjc.StoreIdentifiers(
              stripeWithCustomerId: customerId,
              subscriptionIds: subscriptionIds
            )
          case let .paddle(customerId, subscriptionIds):
            return RedemptionResultObjc.StoreIdentifiers(
              paddleWithCustomerId: customerId,
              subscriptionIds: subscriptionIds
            )
          case let .unknown(store, additionalInfo):
            return RedemptionResultObjc.StoreIdentifiers(
              unknownStore: store,
              additionalInfo: additionalInfo
            )
          }
        }
      }

      public func toObjc() -> RedemptionResultObjc.PurchaserInfo {
        let objcStoreIdentifiers = storeIdentifiers.toObjc()
        return RedemptionResultObjc.PurchaserInfo(
          appUserId: self.appUserId,
          email: self.email,
          storeIdentifiers: objcStoreIdentifiers
        )
      }
    }

    /// Info about the paywall the purchase was made from.
    public struct PaywallInfo: Codable {
      /// Product variables from the paywall checkout context.
      public struct PaywallProduct: Codable {
        public let identifier: String
        public let languageCode: String
        public let locale: String
        public let currencyCode: String
        public let currencySymbol: String
        public let period: String
        public let periodly: String
        public let localizedPeriod: String
        public let periodAlt: String
        public let periodDays: Int
        public let periodWeeks: Int
        public let periodMonths: Int
        public let periodYears: Int
        public let rawPrice: Double
        public let price: String
        public let dailyPrice: String
        public let weeklyPrice: String
        public let monthlyPrice: String
        public let yearlyPrice: String
        public let rawTrialPeriodPrice: Double
        public let trialPeriodPrice: String
        public let trialPeriodDailyPrice: String
        public let trialPeriodWeeklyPrice: String
        public let trialPeriodMonthlyPrice: String
        public let trialPeriodYearlyPrice: String
        public let trialPeriodDays: Int
        public let trialPeriodWeeks: Int
        public let trialPeriodMonths: Int
        public let trialPeriodYears: Int
        public let trialPeriodText: String
        public let trialPeriodEndDate: String

        func toObjc() -> RedemptionResultObjc.PaywallProduct {
          return RedemptionResultObjc.PaywallProduct(
            identifier: identifier,
            languageCode: languageCode,
            locale: locale,
            currencyCode: currencyCode,
            currencySymbol: currencySymbol,
            period: period,
            periodly: periodly,
            localizedPeriod: localizedPeriod,
            periodAlt: periodAlt,
            periodDays: periodDays,
            periodWeeks: periodWeeks,
            periodMonths: periodMonths,
            periodYears: periodYears,
            rawPrice: rawPrice,
            price: price,
            dailyPrice: dailyPrice,
            weeklyPrice: weeklyPrice,
            monthlyPrice: monthlyPrice,
            yearlyPrice: yearlyPrice,
            rawTrialPeriodPrice: rawTrialPeriodPrice,
            trialPeriodPrice: trialPeriodPrice,
            trialPeriodDailyPrice: trialPeriodDailyPrice,
            trialPeriodWeeklyPrice: trialPeriodWeeklyPrice,
            trialPeriodMonthlyPrice: trialPeriodMonthlyPrice,
            trialPeriodYearlyPrice: trialPeriodYearlyPrice,
            trialPeriodDays: trialPeriodDays,
            trialPeriodWeeks: trialPeriodWeeks,
            trialPeriodMonths: trialPeriodMonths,
            trialPeriodYears: trialPeriodYears,
            trialPeriodText: trialPeriodText,
            trialPeriodEndDate: trialPeriodEndDate
          )
        }
      }

      /// The identifier of the paywall.
      public let identifier: String

      /// The name of the placement.
      public let placementName: String

      /// The params of the placement.
      public let placementParams: [String: Any]

      /// The ID of the paywall variant.
      public let variantId: String

      /// The ID of the experiment that the paywall belongs to.
      public let experimentId: String

      /// The product identifier associated with the paywall.
      @available(*, deprecated, renamed: "product.identifier")
      public let productIdentifier: String?

      /// Product variables associated with the paywall.
      public let product: PaywallProduct?

      enum CodingKeys: String, CodingKey {
        case identifier
        case placementName
        case placementParams
        case variantId
        case experimentId
        case productIdentifier
        case product
      }

      public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try container.decode(String.self, forKey: .identifier)
        placementName = try container.decode(String.self, forKey: .placementName)
        variantId = try container.decode(String.self, forKey: .variantId)
        experimentId = try container.decode(String.self, forKey: .experimentId)
        productIdentifier = try container.decodeIfPresent(String.self, forKey: .productIdentifier)
        product = try container.decodeIfPresent(PaywallProduct.self, forKey: .product)

        let paramsJSON = try container.decode(JSON.self, forKey: .placementParams)
        placementParams = paramsJSON.dictionaryObject ?? [:]
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(placementName, forKey: .placementName)
        try container.encode(variantId, forKey: .variantId)
        try container.encode(experimentId, forKey: .experimentId)
        try container.encodeIfPresent(productIdentifier, forKey: .productIdentifier)
        try container.encodeIfPresent(product, forKey: .product)

        let jsonData = JSON(placementParams)
        try container.encode(jsonData, forKey: .placementParams)
      }

      func toObjc() -> RedemptionResultObjc.PaywallInfo {
        let objcProduct = product?.toObjc()
        return RedemptionResultObjc.PaywallInfo(
          identifier: identifier,
          placementName: placementName,
          placementParams: placementParams,
          variantId: variantId,
          experimentId: experimentId,
          productIdentifier: productIdentifier,
          product: objcProduct
        )
      }
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.ownership = try container.decode(Ownership.self, forKey: .ownership)
      self.purchaserInfo = try container.decode(PurchaserInfo.self, forKey: .purchaserInfo)
      self.paywallInfo = try container.decodeIfPresent(PaywallInfo.self, forKey: .paywallInfo)
      self.entitlements = try container.decode(Set<Entitlement>.self, forKey: .entitlements)
    }

    init(
      ownership: Ownership,
      purchaserInfo: PurchaserInfo,
      entitlements: Set<Entitlement>
    ) {
      self.ownership = ownership
      self.purchaserInfo = purchaserInfo
      self.entitlements = entitlements
      self.paywallInfo = nil
    }

    public func toObjc() -> RedemptionResultObjc.RedemptionInfo {
      let objcOwnership = ownership.toObjc()
      let objcPurchaserInfo = purchaserInfo.toObjc()
      let objcPaywallInfo = paywallInfo?.toObjc()
      return RedemptionResultObjc.RedemptionInfo(
        ownership: objcOwnership,
        purchaserInfo: objcPurchaserInfo,
        paywallInfo: objcPaywallInfo,
        entitlements: entitlements
      )
    }
  }

  private enum CodingKeys: String, CodingKey {
    case status
    case code
    case redemptionInfo
    case error
    case expired
  }

  enum CodeStatus: String, Codable {
    case success = "SUCCESS"
    case error = "ERROR"
    case codeExpired = "CODE_EXPIRED"
    case invalidCode = "INVALID_CODE"
    case expiredSubscription = "EXPIRED_SUBSCRIPTION"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let status = try container.decode(CodeStatus.self, forKey: .status)
    let code = try container.decode(String.self, forKey: .code)

    switch status {
    case .success:
      let redemptionInfo = try container.decode(RedemptionInfo.self, forKey: .redemptionInfo)
      self = .success(code: code, redemptionInfo: redemptionInfo)
    case .error:
      let code = try container.decode(String.self, forKey: .code)
      let error = try container.decode(ErrorInfo.self, forKey: .error)
      self = .error(code: code, error: error)
    case .codeExpired:
      let code = try container.decode(String.self, forKey: .code)
      let expiredInfo = try container.decode(ExpiredCodeInfo.self, forKey: .expired)
      self = .expiredCode(
        code: code,
        info: expiredInfo
      )
    case .invalidCode:
      self = .invalidCode(code: code)
    case .expiredSubscription:
      let redemptionInfo = try container.decode(RedemptionInfo.self, forKey: .redemptionInfo)
      self = .expiredSubscription(
        code: code,
        redemptionInfo: redemptionInfo
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case let .success(code, redemptionInfo):
      try container.encode(CodeStatus.success, forKey: .status)
      try container.encode(code, forKey: .code)
      try container.encode(redemptionInfo, forKey: .redemptionInfo)
    case let .error(code, error):
      try container.encode(CodeStatus.error, forKey: .status)
      try container.encode(code, forKey: .code)
      try container.encode(error, forKey: .error)
    case let .expiredCode(code, expired):
      try container.encode(CodeStatus.codeExpired, forKey: .status)
      try container.encode(code, forKey: .code)
      try container.encode(expired, forKey: .expired)
    case .invalidCode(let code):
      try container.encode(code, forKey: .code)
      try container.encode(CodeStatus.invalidCode, forKey: .status)
    case let .expiredSubscription(code, redemptionInfo):
      try container.encode(code, forKey: .code)
      try container.encode(CodeStatus.expiredSubscription, forKey: .status)
      try container.encode(redemptionInfo, forKey: .redemptionInfo)
    }
  }

  /// Converts a Swift RedemptionResult to its ObjC-compatible representation.
  func toObjc() -> RedemptionResultObjc {
    switch self {
    case let .success(code, redemptionInfo):
      return RedemptionResultObjc(
        code: code,
        type: .success,
        redemptionInfo: redemptionInfo.toObjc(),
        errorInfo: nil,
        expiredInfo: nil
      )
    case let .error(code, errorInfo):
      return RedemptionResultObjc(
        code: code,
        type: .error,
        redemptionInfo: nil,
        errorInfo: errorInfo.toObjc(),
        expiredInfo: nil
      )
    case let .expiredCode(code, info):
      return RedemptionResultObjc(
        code: code,
        type: .codeExpired,
        redemptionInfo: nil,
        errorInfo: nil,
        expiredInfo: info.toObjc()
      )
    case .invalidCode(let code):
      return RedemptionResultObjc(
        code: code,
        type: .invalidCode,
        redemptionInfo: nil,
        errorInfo: nil,
        expiredInfo: nil
      )
    case let .expiredSubscription(code, redemptionInfo):
      return RedemptionResultObjc(
        code: code,
        type: .expiredSubscription,
        redemptionInfo: redemptionInfo.toObjc(),
        errorInfo: nil,
        expiredInfo: nil
      )
    }
  }
}
