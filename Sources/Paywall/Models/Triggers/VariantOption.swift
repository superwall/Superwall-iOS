//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/07/2022.
//

import Foundation

struct VariantOption: Decodable, Hashable {
  var type: Experiment.Variant.VariantType
  var id: String
  var percentage: Int
  var paywallId: String?

  enum CodingKeys: String, CodingKey {
    case variantType
    case variantId
    case percentage
    case paywallIdentifier
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    type = try values.decode(Experiment.Variant.VariantType.self, forKey: .variantType)
    id = try values.decode(String.self, forKey: .variantId)
    percentage = try values.decode(Int.self, forKey: .percentage)
    paywallId = try values.decodeIfPresent(String.self, forKey: .paywallIdentifier)
  }

  init(
    type: Experiment.Variant.VariantType,
    id: String,
    percentage: Int,
    paywallId: String?
  ) {
    self.type = type
    self.id = id
    self.percentage = percentage
    self.paywallId = paywallId
  }

  func toVariant() -> Experiment.Variant {
    return Experiment.Variant(
      id: id,
      type: type,
      paywallId: paywallId
    )
  }
}

extension VariantOption: Stubbable {
  static func stub() -> VariantOption {
    return VariantOption(
      type: .treatment,
      id: UUID().uuidString,
      percentage: 100,
      paywallId: UUID().uuidString
    )
  }
}
