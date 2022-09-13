//
//  File.swift
//  
//
//  Created by Yusuf Tör on 24/03/2022.
//

import Foundation
import ASN1Swift

final class InAppReceipt {
  static let shared = InAppReceipt()
  let purchasedProductIds: Set<String>
  private let purchases: [InAppPurchase]
  private var purchasedSubscriptionGroupIds: Set<String> = []
  private var failedToLoadSubscriptionGroupIds = false

  init(getReceiptData: @escaping () -> Data? = getInAppReceiptData) {
    purchases = Self.getPurchases(using: getReceiptData)
    purchasedProductIds = Set(purchases.map { $0.productIdentifier })

  }

  /// Returns the decoded purchases of on-device receipts.
  static func getPurchases(
    using getReceiptData: () -> Data?
  ) -> [InAppPurchase] {
    guard let data = getReceiptData() else {
      return []
    }

    let asn1decoder = ASN1Decoder()

    guard let pkcs7container = try? asn1decoder.decode(
      PKCS7Container.self,
      from: data
    ) else {
      return []
    }

    let payload: InAppReceiptPayload?

    do {
      payload = try asn1decoder.decode(
        InAppReceiptPayloadContainer.self,
        from: pkcs7container.signedData.contentInfo.payload.rawData
      ).payload
    } catch {
      payload = try? asn1decoder.decode(
        LegacyInAppReceiptPayloadContainer.self,
        from: pkcs7container.signedData.contentInfo.payload.rawData
      ).payload
    }

    guard let payload = payload else {
      return []
    }

    return payload.purchases
  }

  /// Loads all purchased products' subscriptionGroupIdentifiers.
  ///
  /// Call this after loading products into the `StoreKitManager`.
  func loadSubscriptionGroupIds() {
    guard #available(iOS 12.0, *) else {
      return
    }

    for purchase in purchases {
      guard let product = StoreKitManager.shared.productsById[purchase.productIdentifier] else {
        continue
      }
      guard let subscriptionGroupIdentifier = product.subscriptionGroupIdentifier else {
        continue
      }
      purchasedSubscriptionGroupIds.insert(subscriptionGroupIdentifier)
    }
  }

  func failedToLoadPurchasedProducts() {
    failedToLoadSubscriptionGroupIds = true
  }

  /// Checks to see whether a different product has already been purchased within the subscription
  /// group of the supplied product
  ///
  /// If the user is on iOS 11 or the product isn't an autorenewable subscription, it just checks whether
  /// the product has been purchased before.
  func hasPurchasedInSubscriptionGroupOfProduct(withId productId: String) -> Bool {
    if failedToLoadSubscriptionGroupIds {
      return hasPurchasedProduct(withId: productId)
    }
    guard #available(iOS 12.0, *) else {
      return hasPurchasedProduct(withId: productId)
    }

    if let product = StoreKitManager.shared.productsById[productId],
      let subscriptionGroupIdentifier = product.subscriptionGroupIdentifier {
      return purchasedSubscriptionGroupIds.contains(subscriptionGroupIdentifier)
    } else {
      // A non automatically renewing subscription may have been purchased.
      // Fallback to just checking if the product has been purchased before.
      return hasPurchasedProduct(withId: productId)
    }
  }

  private func hasPurchasedProduct(withId productId: String) -> Bool {
    let purchasedProduct = purchases.filter { $0.productIdentifier == productId }
    return purchasedProduct.first != nil
  }

  private static func getInAppReceiptData() -> Data? {
    guard
      let receiptUrl = Bundle.main.appStoreReceiptURL,
      FileManager.default.fileExists(atPath: receiptUrl.path)
    else {
      return nil
    }

    do {
      return try Data(contentsOf: receiptUrl)
    } catch {
      return nil
    }
  }
}
