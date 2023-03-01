//
//  File.swift
//  
//
//  Created by Yusuf Tör on 24/03/2022.
//

import Foundation

struct InAppReceiptPayloadContainer: ASN1Decodable {
  var payload: InAppReceiptPayload

  static var template: ASN1Template {
    return ASN1Template
      .contextSpecific(0)
      .constructed()
      .explicit(tag: ASN1Identifier.Tag.octetString)
      .constructed()
  }

  enum CodingKeys: ASN1CodingKey {
    case payload

    var template: ASN1Template {
      switch self {
      case .payload:
        return InAppReceiptPayload.template
      }
    }
  }
}

struct LegacyInAppReceiptPayloadContainer: ASN1Decodable {
  var payload: InAppReceiptPayload

  static var template: ASN1Template {
    return ASN1Template
      .contextSpecific(0)
      .constructed()
  }

  enum CodingKeys: ASN1CodingKey {
    case payload

    var template: ASN1Template {
      switch self {
      case .payload:
        return InAppReceiptPayload.template
      }
    }
  }
}
