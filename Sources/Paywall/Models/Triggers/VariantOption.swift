//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/07/2022.
//

import Foundation

struct VariantOption: Decodable, Hashable {
  let type: Experiment.Variant.VariantType
  let id: String
  let percentage: Int
  let paywallId: String?

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
}
