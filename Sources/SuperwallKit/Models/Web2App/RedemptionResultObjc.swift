//
//  SWKRedemptionResult.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 07/04/2025.
//

import Foundation

/// The result of redeeming a code via web checkout.
@objc(SWKRedemptionResultType)
public enum RedemptionResultType: Int {
  /// The redemption succeeded.
  case success

  /// The redemption failed.
  case error

  /// The code has expired.
  case codeExpired

  /// The code is invalid.
  case invalidCode

  /// The subscription that the code redeems has expired.
  case expiredSubscription
}

/// @objc‑compatible version of RedemptionResult.
@objc(SWKRedemptionResult)
@objcMembers
public class RedemptionResultObjc: NSObject {
  /// The code that was redeemed.
  public let code: String

  /// The type of redemption result.
  public let type: RedemptionResultType

  /// Information about a redemption.
  ///
  /// This is non-nil when the `type` is `success` or `expiredSubscription`.
  public let redemptionInfo: RedemptionInfo?

  /// Information about an error during redemption.
  ///
  /// This is non-nil when the `type` is `error`.
  public let errorInfo: ErrorInfo?

  /// Information about an expired code.
  ///
  /// This is non-nil when the `type` is `codeExpired`
  public let expiredInfo: ExpiredCodeInfo?

  /// Designated initializer.
  public init(
    code: String,
    type: RedemptionResultType,
    redemptionInfo: RedemptionInfo? = nil,
    errorInfo: ErrorInfo? = nil,
    expiredInfo: ExpiredCodeInfo? = nil
  ) {
    self.code = code
    self.type = type
    self.redemptionInfo = redemptionInfo
    self.errorInfo = errorInfo
    self.expiredInfo = expiredInfo
    super.init()
  }

  /// Convenience variable to get the stripe subscription IDs.
  public var stripeSubscriptionIds: [String]? {
    if type == .success,
      let info = redemptionInfo {
      return info.purchaserInfo.storeIdentifiers.stripeSubscriptionIds
    }
    return nil
  }

  /// The error info.
  @objc(SWKErrorInfo)
  @objcMembers
  public class ErrorInfo: NSObject {
    /// The message of the error.
    public let message: String

    public init(message: String) {
      self.message = message
      super.init()
    }
  }

  /// Info about the expired code.
  @objc(SWKExpiredCodeInfo)
  @objcMembers
  public class ExpiredCodeInfo: NSObject {
    /// A boolean indicating whether the redemption email has been resent.
    public let resent: Bool

    /// An optional String indicating the obfuscated email address that the redemption
    /// email was sent to.
    public let obfuscatedEmail: String?

    public init(
      resent: Bool,
      obfuscatedEmail: String?
    ) {
      self.resent = resent
      self.obfuscatedEmail = obfuscatedEmail
      super.init()
    }
  }

  /// Information about the redemption.
  @objc(SWKRedemptionInfo)
  @objcMembers
  public class RedemptionInfo: NSObject {
    /// The ownership of the code.
    public let ownership: Ownership

    /// Info about the purchaser.
    public let purchaserInfo: PurchaserInfo

    /// Info about the paywall the purchase was made from.
    public let paywallInfo: PaywallInfo?

    /// The entitlements array.
    public let entitlements: Set<Entitlement>

    public init(
      ownership: Ownership,
      purchaserInfo: PurchaserInfo,
      paywallInfo: PaywallInfo?,
      entitlements: Set<Entitlement>
    ) {
      self.ownership = ownership
      self.purchaserInfo = purchaserInfo
      self.paywallInfo = paywallInfo
      self.entitlements = entitlements
      super.init()
    }
  }

  /// Enum specifying code ownership.
  @objc(SWKOwnershipType)
  public enum OwnershipType: Int {
    case appUser
    case device
  }

  /// Represents code ownership.
  @objc(SWKOwnership)
  @objcMembers
  public class Ownership: NSObject {
    /// The type of ownership.
    public let type: OwnershipType
    /// The identifier of the owner (appUserId or deviceId).
    public let identifier: String

    /// The code belongs to the identified user.
    public init(appUserId: String) {
      self.type = .appUser
      self.identifier = appUserId
      super.init()
    }

    /// The code belongs to the device.
    public init(deviceId: String) {
      self.type = .device
      self.identifier = deviceId
      super.init()
    }
  }

  /// Info about the purchaser.
  @objc(SWKPurchaserInfo)
  @objcMembers
  public class PurchaserInfo: NSObject {
    /// The app user ID of the purchaser.
    public let appUserId: String

    /// The email address of the purchaser.
    public let email: String?

    /// The identifiers of the store that was purchased from.
    public let storeIdentifiers: StoreIdentifiers

    public init(appUserId: String, email: String?, storeIdentifiers: StoreIdentifiers) {
      self.appUserId = appUserId
      self.email = email
      self.storeIdentifiers = storeIdentifiers
      super.init()
    }
  }

  /// Identifiers of the store that was purchased from.
  @objc(SWKStoreIdentifierType)
  public enum StoreIdentifierType: Int {
    case stripe
    case paddle
    case unknown
  }

  /// Represents store identifiers.
  @objc(SWKStoreIdentifiers)
  @objcMembers
  public class StoreIdentifiers: NSObject {
    /// The type of store identifier.
    public let type: StoreIdentifierType

    /// The customer ID if purchased via Stripe.
    public let customerId: String?

    /// The subscription IDs if purchased via Stripe.
    public let subscriptionIds: [String]?

    /// The store name if unknown.
    public let store: String?

    /// Additional info for an unknown store.
    public let additionalInfo: [String: Any]?

    /// Initializer for Stripe store identifiers.
    public init(
      stripeWithCustomerId customerId: String,
      subscriptionIds: [String]
    ) {
      self.type = .stripe
      self.customerId = customerId
      self.subscriptionIds = subscriptionIds
      self.store = nil
      self.additionalInfo = nil
      super.init()
    }
    
    public init(
        paddleWithCustomerId customerId: String,
        subscriptionIds: [String]
    ) {
        self.type = .paddle
        self.customerId = customerId
        self.subscriptionIds = subscriptionIds
        self.store = nil
        self.additionalInfo = nil
        super.init()
    }

    /// Initializer for unknown store identifiers.
    public init(
      unknownStore store: String,
      additionalInfo: [String: Any]
    ) {
      self.type = .unknown
      self.store = store
      self.additionalInfo = additionalInfo
      self.customerId = nil
      self.subscriptionIds = nil
      super.init()
    }

    /// Convenience variable to get the stripe subscription IDs.
    public var stripeSubscriptionIds: [String]? {
      if type == .stripe {
        return subscriptionIds
      }
      return nil
    }
  }

  /// Info about the paywall the purchase was made from.
  @objc(SWKRedemptionPaywallInfo)
  @objcMembers
  public class PaywallInfo: NSObject {
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
    public let productIdentifier: String?

    public init(
      identifier: String,
      placementName: String,
      placementParams: [String: Any],
      variantId: String,
      experimentId: String,
      productIdentifier: String? = nil
    ) {
      self.identifier = identifier
      self.placementName = placementName
      self.placementParams = placementParams
      self.variantId = variantId
      self.experimentId = experimentId
      self.productIdentifier = productIdentifier
      super.init()
    }
  }
}
