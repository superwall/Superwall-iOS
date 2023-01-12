//
//  File.swift
//  
//
//  Created by Yusuf Tör on 24/03/2022.
//

import Foundation
import ASN1Swift

struct InAppReceiptPayload: ASN1Decodable {
  /// In-app purchase's receipts
  let purchases: Set<InAppPurchase>

  /// The app’s bundle identifier
  let bundleIdentifier: String

  /// The app’s bundle identifier
  let bundleIdentifierData: Data

  /// An opaque value used, with other data, to compute the SHA-1 hash during validation.
  let opaqueValue: Data

  /// A SHA-1 hash, used to validate the receipt.
  let receiptHash: Data

  /// Raw payload data
  let rawData: Data

  /// The app’s version number
    let appVersion: String

  /// The date that the app receipt expires
  let expirationDate: Date?

  static var template: ASN1Template {
    return ASN1Template.universal(ASN1Identifier.Tag.octetString)
  }

  enum CodingKeys: ASN1CodingKey {
    case set

    var template: ASN1Template {
      return ASN1Template.universal(ASN1Identifier.Tag.set).constructed()
    }
  }

  init(from decoder: Decoder) throws {
    // swiftlint:disable force_cast
    let asn1d = decoder as! ASN1DecoderProtocol
    // swiftlint:enable force_cast
    let rawData: Data = try asn1d.extractValueData()
    var bundleIdentifier = ""
    var appVersion = ""
    var purchases: Set<InAppPurchase> = []
    var opaqueValue = Data()
    var receiptHash = Data()
    var expirationDate: Date?
    var bundleIdentifierData = Data()

    let firstContainer = try decoder.container(keyedBy: CodingKeys.self)
    // swiftlint:disable:next force_cast line_length
    var secondContainer = try firstContainer.nestedUnkeyedContainer(forKey: .set) as! ASN1UnkeyedDecodingContainerProtocol

    while !secondContainer.isAtEnd {
      do {
        // swiftlint:disable:next force_cast line_length
        var attributeContainer = try secondContainer.nestedUnkeyedContainer(for: InAppReceiptAttribute.template) as! ASN1UnkeyedDecodingContainerProtocol
        let type: Int32 = try attributeContainer.decode(Int32.self)
        _ = try attributeContainer.skip(template: .universal(ASN1Identifier.Tag.integer))
        // swiftlint:disable:next force_cast line_length
        var valueContainer = try attributeContainer.nestedUnkeyedContainer(for: .universal(ASN1Identifier.Tag.octetString)) as! ASN1UnkeyedDecodingContainerProtocol

        switch type {
        case InAppReceiptField.inAppPurchaseReceipt:
          purchases.insert(try valueContainer.decode(InAppPurchase.self))
        case InAppReceiptField.bundleIdentifier:
          bundleIdentifier = try valueContainer.decode(String.self)
          bundleIdentifierData = valueContainer.valueData
        case InAppReceiptField.appVersion:
          appVersion = try valueContainer.decode(String.self)
        case InAppReceiptField.opaqueValue:
          opaqueValue = valueContainer.valueData
        case InAppReceiptField.receiptHash:
          receiptHash = valueContainer.valueData
        case InAppReceiptField.expirationDate:
          let expirationDateString = try valueContainer.decode(
            String.self,
            template: .universal(ASN1Identifier.Tag.ia5String)
          )
          expirationDate = expirationDateString.rfc3339date()
        default:
          break
        }
      } catch {
        assertionFailure("Something wrong here \(error.localizedDescription)")
      }
    }

    self.purchases = purchases
    self.bundleIdentifier = bundleIdentifier
    self.bundleIdentifierData = bundleIdentifierData
    self.opaqueValue = opaqueValue
    self.receiptHash = receiptHash
    self.rawData = rawData
    self.expirationDate = expirationDate
    self.appVersion = appVersion
  }
}
