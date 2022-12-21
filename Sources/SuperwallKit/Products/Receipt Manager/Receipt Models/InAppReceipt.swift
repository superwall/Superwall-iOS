//
//  File 2.swift
//  
//
//  Created by Yusuf Tör on 14/12/2022.
//

import Foundation
import ASN1Swift

struct InAppReceiptField {
  static let environment: Int32 = 0 // Sandbox, Production, ProductionSandbox
  static let bundleIdentifier: Int32 = 2
  static let appVersion: Int32 = 3
  static let opaqueValue: Int32 = 4
  static let receiptHash: Int32 = 5 // SHA-1 Hash
  static let ageRating: Int32 = 10 // SHA-1 Hash
  static let receiptCreationDate: Int32 = 12
  static let inAppPurchaseReceipt: Int32 = 17 // The receipt for an in-app purchase.
  static let originalAppVersion: Int32 = 19
  static let expirationDate: Int32 = 21

  static let quantity: Int32 = 1701
  static let productIdentifier: Int32 = 1702
  static let transactionIdentifier: Int32 = 1703
  static let purchaseDate: Int32 = 1704
  static let originalTransactionIdentifier: Int32 = 1705
  static let originalPurchaseDate: Int32 = 1706
  static let productType: Int32 = 1707
  static let subscriptionExpirationDate: Int32 = 1708
  static let webOrderLineItemID: Int32 = 1711
  static let cancellationDate: Int32 = 1712
  static let subscriptionTrialPeriod: Int32 = 1713
  static let subscriptionIntroductoryPricePeriod: Int32 = 1719
  static let promotionalOfferIdentifier: Int32 = 1721
}

final class InAppReceipt {
  /// PKCS7 container
  var receipt: _InAppReceipt

    /// Payload of the receipt.
    /// Payload object contains all meta information.
  var payload: InAppReceiptPayload { receipt.payload }

  /// root certificate path, used to check signature
  /// added for testing purpose , as unit test can't read main bundle
  var rootCertificatePath: String?

  /// Raw data
  private var rawData: Data

  /// Initialize a `InAppReceipt` using local receipt
  convenience init() throws {
    guard let data = ReceiptLogic.getReceiptData() else {
      throw IARError.initializationFailed(reason: .appStoreReceiptNotFound)
    }
    try self.init(receiptData: data)
  }

  ///
  ///
  /// Initialize a `InAppReceipt` with asn1 payload
  ///
  /// - parameter receiptData: `Data` object that represents receipt
  init(receiptData: Data, rootCertPath: String? = nil) throws {
    self.receipt = try _InAppReceipt(rawData: receiptData)
    self.rawData = receiptData

    #if DEBUG
    let certificateName = "StoreKitTestCertificate"
    #else
    let certificateName = "AppleIncRootCertificate"
    #endif

    self.rootCertificatePath = rootCertPath ?? Bundle.module.path(forResource: certificateName, ofType: "cer")
  }
}

extension InAppReceipt {
  /// The app’s bundle identifier
  var bundleIdentifier: String {
    payload.bundleIdentifier
  }

  /// The app’s version number
  var appVersion: String {
    payload.appVersion
  }

  /// The date that the app receipt expires
  var expirationDate: Date? {
    payload.expirationDate
  }

  /// Used to validate the receipt
  var bundleIdentifierData: Data {
    payload.bundleIdentifierData
  }

  /// An opaque value used, with other data, to compute the SHA-1 hash during validation.
  var opaqueValue: Data {
    payload.opaqueValue
  }

  /// A SHA-1 hash, used to validate the receipt.
  var receiptHash: Data {
    payload.receiptHash
  }

  /// signature for validation
  var signature: Data?
  {
    return receipt.signatureData
  }

  var worldwideDeveloperCertificateData: Data?
  {
    return receipt.worldwideDeveloperCertificateData
  }

  var iTunesCertificateData: Data?
  {
    return receipt.iTunesCertificateData
  }

  var iTunesPublicKeyData: Data?
  {
    return receipt.iTunesPublicKeyData
  }

  var payloadRawData: Data
  {
    return payload.rawData
  }
}
