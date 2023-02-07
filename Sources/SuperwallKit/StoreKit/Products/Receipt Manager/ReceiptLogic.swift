//
//  File.swift
//  
//
//  Created by Yusuf Tör on 04/10/2022.
//

import Foundation

enum ReceiptLogic {
  /// Gets the on-device receipt payload from the App Store Receipt URL.
  static func getPayload(
    using getReceiptData: () -> Data?
  ) -> InAppReceiptPayload? {
    guard let data = getReceiptData() else {
      return nil
    }

    let asn1decoder = ASN1Decoder()

    guard let pkcs7container = try? asn1decoder.decode(
      PKCS7Container.self,
      from: data
    ) else {
      return nil
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

    return payload
  }

  static func getReceiptData() -> Data? {
    guard
      let receiptUrl = Bundle.main.appStoreReceiptURL,
      FileManager.default.fileExists(atPath: receiptUrl.path)
    else {
      return nil
    }

    return try? Data(contentsOf: receiptUrl)
  }
}
