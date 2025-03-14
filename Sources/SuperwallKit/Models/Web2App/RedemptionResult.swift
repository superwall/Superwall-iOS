//
//  RedemptionResult.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 14/03/2025.
//

public enum RedemptionResult: Codable {
  case success(code: String, redemptionInfo: RedemptionInfo)
  case error(code: String, error: ErrorInfo)
  case codeExpired(code: String, expired: ExpiredInfo)
  case invalidCode(code: String)
  case expiredSubscription(code: String, redemptionInfo: RedemptionInfo)

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

  public struct ErrorInfo: Codable {
    public let message: String
  }

  public struct ExpiredInfo: Codable {
    public let resent: Bool
    public let obfuscatedEmail: String?
  }

  public struct RedemptionInfo: Codable {
    public let ownership: Ownership
    public let purchaserInfo: PurchaserInfo
    public let paywallInfo: PaywallInfo

    public enum Ownership: Codable {
      case appUser(appUserId: String)
      case device(deviceId: String)

      private enum CodingKeys: String, CodingKey {
        case type
        case appUserId
        case deviceId
      }

      enum OwnershipType: String, Codable {
        case appUser
        case device
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

    public struct PurchaserInfo: Codable {
      public let appUserId: String
      public let email: String?
      public let storeIdentifiers: StoreIdentifiers

      public enum StoreIdentifiers: Codable {
        case stripe(stripeSubscriptionId: String)
        case unknown(store: String, additionalInfo: [String: Any])

        private enum CodingKeys: String, CodingKey, CaseIterable {
          case store
          case stripeSubscriptionId
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
            let stripeSubscriptionId = try container.decode(String.self, forKey: .stripeSubscriptionId)
            self = .stripe(stripeSubscriptionId: stripeSubscriptionId)
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
          case .stripe(let stripeSubscriptionId):
            try container.encode("STRIPE", forKey: .store)
            try container.encode(stripeSubscriptionId, forKey: .stripeSubscriptionId)

          case .unknown(let store, let additionalInfo):
            try container.encode(store, forKey: .store)

            // Create a dynamic coding container to encode arbitrary keys and values
            var dynamicContainer = encoder.container(keyedBy: DynamicCodingKey.self)

            // Iterate over each key-value pair in the additional JSON info
            for (key, value) in JSON(additionalInfo).dictionaryValue {
              // Skip keys that are already explicitly defined in `CodingKeys`
              guard !CodingKeys.allCases.map({ $0.rawValue }).contains(key) else { continue }

              // Create a dynamic coding key from the current key string
              let dynamicKey = DynamicCodingKey(stringValue: key)!

              // Encode the JSON value associated with the dynamic key
              try dynamicContainer.encode(value, forKey: dynamicKey)
            }
          }
        }
      }
    }

    public struct PaywallInfo: Codable {
      public let identifier: String
      public let placementName: String
      public let placementParams: [String: String]
      public let variantId: String
      public let experimentId: String
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
        expired: ExpiredInfo(
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
    case .success(let code, let redemptionInfo):
      try container.encode(CodeStatus.success, forKey: .status)
      try container.encode(code, forKey: .code)
      try container.encode(redemptionInfo, forKey: .redemptionInfo)
    case .error(let code, let error):
      try container.encode(CodeStatus.error, forKey: .status)
      try container.encode(code, forKey: .code)
      try container.encode(error, forKey: .error)
    case .codeExpired(let code, let expired):
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
