//
//  File.swift
//  
//
//  Created by Yusuf Tör on 24/03/2022.
//

import Foundation
import ASN1Swift

struct InAppReceiptPayload: ASN1Decodable  {
  /// In-app purchase's receipts
  let purchases: [InAppPurchase]
  static let inAppPurchaseReceipt: Int32 = 17
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
    var purchases = [InAppPurchase]()

    let firstContainer = try decoder.container(keyedBy: CodingKeys.self)
    var secondContainer = try firstContainer.nestedUnkeyedContainer(forKey: .set) as! ASN1UnkeyedDecodingContainerProtocol

    while !secondContainer.isAtEnd {
      do {
        var attributeContainer = try secondContainer.nestedUnkeyedContainer(for: InAppReceiptAttribute.template) as! ASN1UnkeyedDecodingContainerProtocol
        let type: Int32 = try attributeContainer.decode(Int32.self)
        let _ = try attributeContainer.skip(template: .universal(ASN1Identifier.Tag.integer))
        var valueContainer = try attributeContainer.nestedUnkeyedContainer(for: .universal(ASN1Identifier.Tag.octetString)) as! ASN1UnkeyedDecodingContainerProtocol

        switch type {
        case InAppReceiptPayload.inAppPurchaseReceipt:
          purchases.append(try valueContainer.decode(InAppPurchase.self))
        default:
          break
        }
      }catch{
        assertionFailure("Something wrong here")
      }
    }
    
    self.purchases = purchases
  }
}
