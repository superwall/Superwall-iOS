//
//  CheckoutStatusResponse.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 18/07/2025.
//

struct CheckoutStatusResponse: Decodable {
  struct AbandonedCheckout: Decodable {
    let productIdentifier: String?
    let paywallIdentifier: String?
    let experimentVariantId: String?
    let presentedByEventName: String?
  }

  enum CheckoutStatus: Decodable {
    case pending
    case completed(redemptionCodes: [String])
    case abandoned(AbandonedCheckout)
    
    private enum CodingKeys: String, CodingKey {
      case type
      case redemptionCodes
      case productIdentifier
      case paywallIdentifier
      case experimentVariantId
      case presentedByEventName
    }
    
    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let type = try container.decode(String.self, forKey: .type)
      
      switch type {
      case "pending":
        self = .pending
      case "completed":
        let redemptionCodes = try container.decode([String].self, forKey: .redemptionCodes)
        self = .completed(redemptionCodes: redemptionCodes)
      case "abandoned":
        let abandonedCheckout = AbandonedCheckout(
          productIdentifier: try container.decode(String.self, forKey: .productIdentifier),
          paywallIdentifier: try container.decode(String.self, forKey: .paywallIdentifier),
          experimentVariantId: try container.decode(String.self, forKey: .experimentVariantId),
          presentedByEventName: try container.decode(String.self, forKey: .presentedByEventName)
        )
        self = .abandoned(abandonedCheckout)
      default:
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription: "Unknown checkout status type: \(type)"
          )
        )
      }
    }
  }

  let status: CheckoutStatus

  private enum CodingKeys: String, CodingKey {
    case status
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.status = try container.decode(CheckoutStatus.self, forKey: .status)
  }
}
