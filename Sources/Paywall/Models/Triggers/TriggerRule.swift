//
//  TriggerRule.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct TriggerRule: Decodable, Hashable {
  var experimentGroupId: String
  var experimentId: String
  var expression: String?
  var isAssigned: Bool
  var variant: Variant
  var variantId: String

  enum Keys: String, CodingKey {
    case experimentGroupId
    case experimentId
    case expression
    case isAssigned = "assigned"
    case variant
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: TriggerRule.Keys.self)
    
    experimentId = try values.decode(String.self, forKey: .experimentId)
    expression = try values.decodeIfPresent(String.self, forKey: .expression)
    isAssigned = try values.decode(Bool.self, forKey: .isAssigned)
    variant = try values.decode(Variant.self, forKey: .variant)
    experimentGroupId = try values.decode(String.self, forKey: .experimentGroupId)

    switch variant {
    case .holdout(let holdout):
      variantId = holdout.variantId
    case .treatment(let treatment):
      variantId = treatment.variantId
    }
  }

  init(
    experimentGroupId: String,
    experimentId: String,
    expression: String?,
    isAssigned: Bool,
    variant: Variant,
    variantId: String
  ) {
    self.experimentGroupId = experimentGroupId
    self.experimentId = experimentId
    self.expression = expression
    self.isAssigned = isAssigned
    self.variant = variant
    self.variantId = variantId
  }
}

extension TriggerRule: Stubbable {
  static func stub() -> TriggerRule {
    let variant: Variant = .stub()
    let variantId: String
    switch variant {
    case .holdout(let holdout):
      variantId = holdout.variantId
    case .treatment(let treatment):
      variantId = treatment.variantId
    }

    return TriggerRule(
      experimentGroupId: "1",
      experimentId: "2",
      expression: "name == jake",
      isAssigned: false,
      variant: variant,
      variantId: variantId
    )
  }
}
