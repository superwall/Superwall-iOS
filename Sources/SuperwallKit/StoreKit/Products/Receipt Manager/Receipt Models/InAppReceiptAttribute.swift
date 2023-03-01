//
//  File.swift
//  
//
//  Created by Yusuf Tör on 24/03/2022.
//

import Foundation

struct InAppReceiptAttribute: ASN1Decodable {
  static var template: ASN1Template {
    return ASN1Template.universal(ASN1Identifier.Tag.sequence).constructed()
  }

  var type: Int
  var version: Int
  var value: Data

  enum CodingKeys: ASN1CodingKey {
    case type
    case version
    case value

    var template: ASN1Template {
      switch self {
      case .type:
        return .universal(ASN1Identifier.Tag.integer)
      case .version:
        return .universal(ASN1Identifier.Tag.integer)
      case .value:
        return .universal(ASN1Identifier.Tag.octetString)
      }
    }
  }
}
