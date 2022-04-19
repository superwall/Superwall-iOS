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
    let purchasedProduct = payload.purchases.filter { $0.productIdentifier == productId }
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
