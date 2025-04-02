//
//  RedemptionResult.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 14/03/2025.
//
// swiftlint:disable type_body_length

import Foundation

/// The result of redeeming a code via web checkout.
public enum RedemptionResult: Codable {
  /// The redemption succeeded.
  case success(code: String, redemptionInfo: RedemptionInfo)

  /// The redemption failed.
  case error(code: String, error: ErrorInfo)

  /// The code has expired.
  case codeExpired(code: String, expiredInfo: ExpiredInfo)

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
      let .codeExpired(code, _),
      let .invalidCode(code),
      let .expiredSubscription(code, _):
      return code
    }
  }

  /// The error info.
  public struct ErrorInfo: Codable {
    /// The message of the error.
    public let message: String
  }

  /// Info about the expired code.
  public struct ExpiredInfo: Codable {
    /// A boolean indicating whether the redemption email has been resent.
    public let resent: Bool

    /// An optional `String` indicated the obfuscated email address that the
    /// redemption email was sent to.
    public let obfuscatedEmail: String?
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

        /// The subscription was purchased from an unknown store type.
        case unknown(store: String, additionalInfo: [String: Any])

        private enum CodingKeys: String, CodingKey, CaseIterable {
          case store
          case stripeCustomerId
          case stripeSubscriptionIds
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
      }
    }

    /// Info about the paywall the purchase was made from.
    public struct PaywallInfo: Codable {
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

      enum CodingKeys: String, CodingKey {
        case identifier
        case placementName
        case placementParams
        case variantId
        case experimentId
      }

      public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try container.decode(String.self, forKey: .identifier)
        placementName = try container.decode(String.self, forKey: .placementName)
        variantId = try container.decode(String.self, forKey: .variantId)
        experimentId = try container.decode(String.self, forKey: .experimentId)

        let paramsJSON = try container.decode(JSON.self, forKey: .placementParams)
        placementParams = paramsJSON.dictionaryObject ?? [:]
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(placementName, forKey: .placementName)
        try container.encode(variantId, forKey: .variantId)
        try container.encode(experimentId, forKey: .experimentId)

        let jsonData = JSON(placementParams)
        try container.encode(jsonData, forKey: .placementParams)
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
  }

  private enum CodingKeys: String, CodingKey {
    case status
    case code
    case redemptionInfo
    case error
    case expired
    case resent
    case obfuscatedEmail
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
      let resent = try container.decode(Bool.self, forKey: .resent)
      let obfuscatedEmail = try container.decodeIfPresent(String.self, forKey: .obfuscatedEmail)
      self = .codeExpired(
        code: code,
        expiredInfo: ExpiredInfo(
          resent: resent,
          obfuscatedEmail: obfuscatedEmail
        )
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
    case let .codeExpired(code, expired):
      try container.encode(CodeStatus.codeExpired, forKey: .status)
      try container.encode(code, forKey: .code)
      try container.encode(expired.resent, forKey: .resent)
      try container.encodeIfPresent(expired.obfuscatedEmail, forKey: .obfuscatedEmail)
    case .invalidCode(let code):
      try container.encode(code, forKey: .code)
      try container.encode(CodeStatus.invalidCode, forKey: .status)
    case let .expiredSubscription(code, redemptionInfo):
      try container.encode(code, forKey: .code)
      try container.encode(CodeStatus.expiredSubscription, forKey: .status)
      try container.encode(redemptionInfo, forKey: .redemptionInfo)
    }
  }
}
