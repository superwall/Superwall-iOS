//
//  File.swift
//  
//
//  Created by Yusuf Tör on 24/03/2022.
//

import Foundation
import ASN1Swift

final class InAppReceipt {
  let getReceiptData: () -> Data?

  init(getReceiptData: @escaping () -> Data? = getInAppReceiptData) {
    self.getReceiptData = getReceiptData
  }

  /// This checks to see whether a product has been purchased by looking through receipts on device.
  /// If the receipt has expired/is invalid but contains the productID it'll still say it has been purchased
  /// However, it's okay use this method when checking whether to display a free trial or not
  func hasPurchased(productId: String) -> Bool {
    guard let data = getReceiptData() else {
      return false
    }

    let asn1decoder = ASN1Decoder()

    guard let pkcs7container = try? asn1decoder.decode(
      PKCS7Container.self,
      from: data
    ) else {
      return false
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
      return false
    }

    if #available(iOS 12.0, *) {
      if let product = StoreKitManager.shared.productsById[productId],
        let subscriptionGroupIdentifier = product.subscriptionGroupIdentifier {
        // Load all purchased products' subscriptionGroupIdentifiers.
        var subscriptionGroupIdentifiers: Set<String> = []
        for purchase in payload.purchases {
          guard let product = StoreKitManager.shared.productsById[purchase.productIdentifier] else {
            continue
          }
          guard let subscriptionGroupIdentifier = product.subscriptionGroupIdentifier else {
            continue
          }
          subscriptionGroupIdentifiers.insert(subscriptionGroupIdentifier)
        }

        return subscriptionGroupIdentifiers.contains(subscriptionGroupIdentifier)
      } else {
        // A non automatically renewing subscription may have been purchased.
        // Fallback to just checking if the product has been purchased before.
        return purchasesHasProductId(productId, purchases: payload.purchases)
      }
    } else {
      // In iOS 11, fallback to just checking if the product has been purchased before.
      return purchasesHasProductId(productId, purchases: payload.purchases)
    }
  }

  private func purchasesHasProductId(
    _ productId: String,
    purchases: [InAppPurchase]
  ) -> Bool {
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
