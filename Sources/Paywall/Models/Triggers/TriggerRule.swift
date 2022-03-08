//
//  TriggerRule.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct TriggerRule: Decodable, Hashable {
  var experimentId: String
  var expression: String?
  var assigned: Bool
  var variant: Variant
  var variantId: String

  enum Keys: String, CodingKey {
    case experimentId
    case expression
    case assigned
    case variant
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: TriggerRule.Keys.self)
    experimentId = try values.decode(String.self, forKey: .experimentId)
    expression = try values.decodeIfPresent(String.self, forKey: .expression)
    assigned = try values.decode(Bool.self, forKey: .assigned)
    variant = try values.decode(Variant.self, forKey: .variant)

    switch variant {
    case .holdout(let holdout):
      variantId = holdout.variantId
    case .treatment(let treatment):
      variantId = treatment.variantId
    }
  }
}
