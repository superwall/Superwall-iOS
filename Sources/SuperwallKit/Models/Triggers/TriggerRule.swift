//
//  TriggerRule.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct UnmatchedRule: Equatable {
  enum Source: String {
    case expression = "EXPRESSION"
    case occurrence = "OCCURRENCE"
  }
  let source: Source
  let experimentId: String
}

struct MatchedItem {
  let rule: TriggerRule
  let unsavedOccurrence: TriggerRuleOccurrence?
}

enum TriggerRuleOutcome: Equatable {
  static func == (lhs: TriggerRuleOutcome, rhs: TriggerRuleOutcome) -> Bool {
    switch (lhs, rhs) {
    case let (.match(item1), .match(item2)):
      return item1.rule == item2.rule
        && item1.unsavedOccurrence == item2.unsavedOccurrence
    case let (.noMatch(unmatchedRule1), .noMatch(unmatchedRule2)):
      return unmatchedRule1.source == unmatchedRule2.source
        && unmatchedRule1.experimentId == unmatchedRule2.experimentId
    default:
      return false
    }
  }

  case noMatch(UnmatchedRule)
  case match(MatchedItem)

  static func noMatch(
    source: UnmatchedRule.Source,
    experimentId: String
  ) -> TriggerRuleOutcome {
    return .noMatch(.init(source: source, experimentId: experimentId))
  }

  static func match(
    rule: TriggerRule,
    unsavedOccurrence: TriggerRuleOccurrence? = nil
  ) -> TriggerRuleOutcome {
    return .match(.init(rule: rule, unsavedOccurrence: unsavedOccurrence))
  }
}

struct TriggerRule: Decodable, Hashable {
  var experiment: RawExperiment
  var expression: String?
  var expressionJs: String?
  var occurrence: TriggerRuleOccurrence?
  let computedPropertyRequests: [ComputedPropertyRequest]

  enum CodingKeys: String, CodingKey {
    case experimentGroupId
    case experimentId
    case expression
    case variants
    case expressionJs
    case occurrence
    case computedPropertyRequests = "computedProperties"
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

    let throwableComputedProperties = try values.decodeIfPresent(
      [Throwable<ComputedPropertyRequest>].self,
      forKey: .computedPropertyRequests
    ) ?? []
    computedPropertyRequests = throwableComputedProperties.compactMap { try? $0.result.get() }
  }

  init(
    experiment: RawExperiment,
    expression: String?,
    expressionJs: String?,
    occurrence: TriggerRuleOccurrence? = nil,
    computedPropertyRequests: [ComputedPropertyRequest]
  ) {
    self.experiment = experiment
    self.expression = expression
    self.expressionJs = expressionJs
    self.occurrence = occurrence
    self.computedPropertyRequests = computedPropertyRequests
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
      occurrence: nil,
      computedPropertyRequests: []
    )
  }
}
