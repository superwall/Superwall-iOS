//
//  TriggerRule.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct TriggerRule: Decodable, Hashable {
  var experiment: Experiment
  var expression: String?
  var isAssigned: Bool

  enum CodingKeys: String, CodingKey {
    case experimentGroupId
    case experimentId
    case expression
    case isAssigned = "assigned"
    case variant
  }

  enum VariantKeys: String, CodingKey {
    case variantType
    case variantId
    case paywallIdentifier
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    
    let experimentId = try values.decode(String.self, forKey: .experimentId)
    let experimentGroupId = try values.decode(String.self, forKey: .experimentGroupId)

    let variant = try values.nestedContainer(keyedBy: VariantKeys.self, forKey: .variant)
    let variantId = try variant.decode(String.self, forKey: .variantId)
    let paywallIdentifier = try variant.decodeIfPresent(String.self, forKey: .paywallIdentifier)
    let variantType = try variant.decode(Experiment.Variant.VariantType.self, forKey: .variantType)

    experiment = Experiment(
      id: experimentId,
      groupId: experimentGroupId,
      variant: .init(
        id: variantId,
        type: variantType,
        paywallId: paywallIdentifier
      )
    )

    expression = try values.decodeIfPresent(String.self, forKey: .expression)
    isAssigned = try values.decode(Bool.self, forKey: .isAssigned)
  }

  init(
    experiment: Experiment,
    expression: String?,
    isAssigned: Bool
  ) {
    self.experiment = experiment
    self.expression = expression
    self.isAssigned = isAssigned
  }
}

extension TriggerRule: Stubbable {
  static func stub() -> TriggerRule {
    return TriggerRule(
      experiment: Experiment(
        id: "1",
        groupId: "2",
        variant: .init(
          id: "3",
          type: .holdout,
          paywallId: nil
        )
      ),
      expression: "name == jake",
      isAssigned: false
    )
  }
}
