//
//  File.swift
//  
//
//  Created by Yusuf Tör on 24/03/2022.
//
// swiftlint:disable function_body_length

import Foundation

struct InAppPurchase: ASN1Decodable, Hashable {
  static var template: ASN1Template {
    return ASN1Template
      .universal(ASN1Identifier.Tag.set)
      .constructed()
  }

  /// Check whether the subscription is active for a specific date
  ///
  /// - Parameter date: The date in which the auto-renewable subscription should be active.
  /// - Returns: true if the latest auto-renewable subscription is active for the given date, false otherwise.
  var isActive: Bool {
    // If has no expiration date, assume it's a lifetime purchase.
    // It might not be - it could be another non-consumable OR a
    // consumable. But for those use cases they should handle the logic
    // themselves.
    if subscriptionExpirationDate == nil {
      return true
    }
    if cancellationDate != nil {
      return false
    }
    guard let expirationDate = subscriptionExpirationDate else {
      return false
    }

    let date = Date()
    return date >= purchaseDate && date < expirationDate
  }

  /// The product identifier which purchase related to
  var productIdentifier: String

  /// Subscription Expiration Date. Returns `nil` if the purchase has been expired (in some cases)
  var subscriptionExpirationDate: Date?

  /// Cancellation Date. Returns `nil` if the purchase is not a renewable subscription
  var cancellationDate: Date?

  /// Purchase Date
  var purchaseDate: Date

  init(from decoder: Decoder) throws {
    guard var container = try decoder.unkeyedContainer() as? ASN1UnkeyedDecodingContainerProtocol else {
      throw DecodingError.valueNotFound(
        ASN1UnkeyedDecodingContainerProtocol.self,
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Unkeyed container doesn't exist."
        )
      )
    }

    var productIdentifier = ""
    var purchaseDate: Date?

    while !container.isAtEnd {
      do {
        guard var attributeContainer = try container.nestedUnkeyedContainer(
          for: InAppReceiptAttribute.template
        ) as? ASN1UnkeyedDecodingContainerProtocol else {
          throw DecodingError.valueNotFound(
            ASN1UnkeyedDecodingContainerProtocol.self,
            DecodingError.Context(
              codingPath: decoder.codingPath,
              debugDescription: "InAppReceiptAttribute template nested unkeyed container doesn't exist."
            )
          )
        }
        let type: Int32 = try attributeContainer.decode(Int32.self)
        _ = try attributeContainer.skip(template: .universal(ASN1Identifier.Tag.integer))

        guard var valueContainer = try attributeContainer.nestedUnkeyedContainer(
          for: .universal(ASN1Identifier.Tag.octetString)
        ) as? ASN1UnkeyedDecodingContainerProtocol else {
          throw DecodingError.valueNotFound(
            ASN1UnkeyedDecodingContainerProtocol.self,
            DecodingError.Context(
              codingPath: decoder.codingPath,
              debugDescription: "Value container doesn't exist."
            )
          )
        }

        switch type {
        case InAppReceiptField.productIdentifier:
          productIdentifier = try valueContainer.decode(String.self)
        case InAppReceiptField.purchaseDate:
          let purchaseDateString = try valueContainer.decode(
            String.self,
            template: .universal(ASN1Identifier.Tag.ia5String)
          )
          purchaseDate = purchaseDateString.rfc3339date()
        case InAppReceiptField.subscriptionExpirationDate:
          let str = try valueContainer.decode(String.self, template: .universal(ASN1Identifier.Tag.ia5String))
          let subscriptionExpirationDateString = str.isEmpty ? nil : str
          subscriptionExpirationDate = subscriptionExpirationDateString?.rfc3339date()
        case InAppReceiptField.cancellationDate:
          let str = try valueContainer.decode(String.self, template: .universal(ASN1Identifier.Tag.ia5String))
          let cancellationDateString = str.isEmpty ? nil : str
          cancellationDate = cancellationDateString?.rfc3339date()
        default:
          break
        }
      }
    }

    self.productIdentifier = productIdentifier

    if let purchaseDate = purchaseDate {
      self.purchaseDate = purchaseDate
    } else {
      throw DecodingError.valueNotFound(
        Date.self,
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Unkeyed container is at end."
        )
      )
    }
  }
}
