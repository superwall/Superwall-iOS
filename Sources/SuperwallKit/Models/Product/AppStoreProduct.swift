//
//  AppStoreProduct.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 23/07/2025.
//

import Foundation

/// An Apple App Store product.
@objc(SWKAppStoreProduct)
@objcMembers
public final class AppStoreProduct: NSObject, Codable, Sendable {
  /// The billing plan an App Store auto-renewing subscription product was
  /// configured to use in the Superwall dashboard.
  ///
  /// Two Superwall Products that share the same Apple `productIdentifier` but
  /// configure different billing plans (e.g. annual up-front and
  /// monthly-commitment annual) are merchandised as distinct entries on a
  /// paywall. Available on iOS 26.4+ subscription products with multiple
  /// billing plans configured in App Store Connect.
  @objc(SWKBillingPlanType)
  public enum BillingPlanType: Int, Sendable {
    case upFront
    case monthly

    enum StringValue: String, Codable {
      case upFront = "UP_FRONT"
      case monthly = "MONTHLY"
    }
  }

  /// The product identifier.
  public let id: String

  /// The product's store.
  private let store: String

  /// The billing plan configured on this Superwall Product. `nil` when the
  /// Product doesn't opt into a specific billing plan; in that case purchases
  /// proceed with whatever Apple's default plan is for the product.
  public let billingPlanType: BillingPlanType?

  enum CodingKeys: String, CodingKey {
    case id = "productIdentifier"
    case store
    case billingPlanType
  }

  init(
    id: String,
    store: String = "APP_STORE",
    billingPlanType: BillingPlanType? = nil
  ) {
    self.id = id
    self.store = store
    self.billingPlanType = billingPlanType
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(store, forKey: .store)
    if let billingPlanType = billingPlanType {
      let raw: BillingPlanType.StringValue
      switch billingPlanType {
      case .upFront: raw = .upFront
      case .monthly: raw = .monthly
      }
      try container.encode(raw, forKey: .billingPlanType)
    }
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    store = try container.decode(String.self, forKey: .store)
    if store != "APP_STORE" {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Not an App Store product \(store)"
        )
      )
    }
    if let raw = try container.decodeIfPresent(
      BillingPlanType.StringValue.self,
      forKey: .billingPlanType
    ) {
      switch raw {
      case .upFront: billingPlanType = .upFront
      case .monthly: billingPlanType = .monthly
      }
    } else {
      billingPlanType = nil
    }
    super.init()
  }

  public override func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? AppStoreProduct else {
      return false
    }
    return id == other.id
      && store == other.store
      && billingPlanType == other.billingPlanType
  }

  public override var hash: Int {
    var hasher = Hasher()
    hasher.combine(id)
    hasher.combine(store)
    hasher.combine(billingPlanType)
    return hasher.finalize()
  }
}
