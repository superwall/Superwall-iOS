//
//  TriggerRule.swift
//  Paywall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct TriggerRule: Decodable, Hashable {
  var experiment: RawExperiment
  var expression: String?
  var expressionJs: String?
  var occurrence: TriggerRuleOccurrence?

  enum CodingKeys: String, CodingKey {
    case experimentGroupId
    case experimentId
    case expression
    case variants
    case expressionJs
    case occurrence
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    let experimentId = try values.decode(String.self, forKey: .experimentId)
    let experimentGroupId = try values.decode(String.self, forKey: .experimentGroupId)
    let variants = try values.decode([VariantOption].self, forKey: .variants)

    experiment = RawExperiment(
      id: experimentId,
      groupId: experimentGroupId,
      variants: variants
    )

    expression = try values.decodeIfPresent(String.self, forKey: .expression)
    expressionJs = try values.decodeIfPresent(String.self, forKey: .expressionJs)
    occurrence = try values.decodeIfPresent(TriggerRuleOccurrence.self, forKey: .occurrence)
  }

  init(
    experiment: RawExperiment,
    expression: String?,
    expressionJs: String?,
    occurrence: TriggerRuleOccurrence? = nil
  ) {
    self.experiment = experiment
    self.expression = expression
    self.expressionJs = expressionJs
    self.occurrence = occurrence
  }
}

extension TriggerRule: Stubbable {
  static func stub() -> TriggerRule {
    return TriggerRule(
      experiment: RawExperiment(
        id: "1",
        groupId: "2",
        variants: [
          .init(
          type: .holdout,
          id: "3",
          percentage: 20,
          paywallId: nil
          )
        ]
      ),
      expression: nil,
      expressionJs: nil,
      occurrence: nil
    )
  }
}
