//
//  File.swift
//  
//
//  Created by Yusuf Tör on 24/03/2022.
//

import Foundation
import ASN1Swift

struct InAppPurchase: ASN1Decodable {
  /// The product identifier which purchase related to
  var productIdentifier: String
  static let productIdentifierType: Int32 = 1702

  init(from decoder: Decoder) throws {
    var container = try decoder.unkeyedContainer() as! ASN1UnkeyedDecodingContainerProtocol

    var productIdentifier = ""

    while !container.isAtEnd {
      do {
        var attributeContainer = try container.nestedUnkeyedContainer(for: InAppReceiptAttribute.template) as! ASN1UnkeyedDecodingContainerProtocol
        let type: Int32 = try attributeContainer.decode(Int32.self)
        let _ = try attributeContainer.skip(template: .universal(ASN1Identifier.Tag.integer))
        var valueContainer = try attributeContainer.nestedUnkeyedContainer(for: .universal(ASN1Identifier.Tag.octetString)) as! ASN1UnkeyedDecodingContainerProtocol

        switch type {
        case InAppPurchase.productIdentifierType:
          productIdentifier = try valueContainer.decode(String.self)
        default:
          break
        }
      }
    }

    self.productIdentifier = productIdentifier
  }

  static var template: ASN1Template {
    return ASN1Template
      .universal(ASN1Identifier.Tag.set)
      .constructed()
  }
}
