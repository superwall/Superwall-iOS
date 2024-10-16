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

extension UnmatchedRule: Stubbable {
  static func stub() -> UnmatchedRule {
    return UnmatchedRule(
      source: .expression,
      experimentId: "1"
    )
  }
}

struct MatchedItem {
  let rule: TriggerRule
  let unsavedOccurrence: TriggerRuleOccurrence?
}

extension MatchedItem: Stubbable {
  static func stub() -> MatchedItem {
    return MatchedItem(
      rule: .stub(),
      unsavedOccurrence: nil
    )
  }
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

struct TriggerRule: Codable, Hashable, Equatable {
  var experiment: RawExperiment
  var expression: String?
  var expressionJs: String?
  var expressionCel: String?
  var occurrence: TriggerRuleOccurrence?
  let computedPropertyRequests: [ComputedPropertyRequest]
  var preload: TriggerPreload

  struct TriggerPreload: Codable, Hashable {
    enum TriggerPreloadBehavior: String, Codable {
      case ifTrue = "IF_TRUE"
      case always = "ALWAYS"
      case never = "NEVER"
    }
    let behavior: TriggerPreloadBehavior

    enum CodingKeys: String, CodingKey {
      case behavior
      case requiresReEvaluation
    }

    init(from decoder: Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)

      let behavior = try values.decode(TriggerPreloadBehavior.self, forKey: .behavior)
      let requiresReevaluation = try values.decodeIfPresent(Bool.self, forKey: .requiresReEvaluation) ?? false
      if requiresReevaluation {
        self.behavior = .always
      } else {
        self.behavior = behavior
      }
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)

      try container.encode(behavior, forKey: .behavior)
      try container.encode(behavior == .always, forKey: .requiresReEvaluation)
    }

    init(behavior: TriggerPreloadBehavior) {
      self.behavior = behavior
    }
  }

  enum CodingKeys: String, CodingKey {
    case experimentGroupId
    case experimentId
    case expression
    case variants
    case expressionJs
    case expressionCel
    case occurrence
    case computedPropertyRequests = "computedProperties"
    case preload
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
    expressionCel = try values.decodeIfPresent(String.self, forKey: .expressionCel)
    occurrence = try values.decodeIfPresent(TriggerRuleOccurrence.self, forKey: .occurrence)
    preload = try values.decode(TriggerPreload.self, forKey: .preload)

    let throwableComputedProperties = try values.decodeIfPresent(
      [Throwable<ComputedPropertyRequest>].self,
      forKey: .computedPropertyRequests
    ) ?? []
    computedPropertyRequests = throwableComputedProperties.compactMap { try? $0.result.get() }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(experiment.id, forKey: .experimentId)
    try container.encode(experiment.groupId, forKey: .experimentGroupId)
    try container.encode(experiment.variants, forKey: .variants)
    try container.encodeIfPresent(expression, forKey: .expression)
    try container.encodeIfPresent(expressionJs, forKey: .expressionJs)
    try container.encodeIfPresent(expressionCel, forKey: .expressionCel)
    try container.encodeIfPresent(occurrence, forKey: .occurrence)
    try container.encode(preload, forKey: .preload)

    if !computedPropertyRequests.isEmpty {
      try container.encode(computedPropertyRequests, forKey: .computedPropertyRequests)
    }
  }

  init(
    experiment: RawExperiment,
    expression: String?,
    expressionJs: String?,
    expressionCel: String?,
    occurrence: TriggerRuleOccurrence? = nil,
    computedPropertyRequests: [ComputedPropertyRequest],
    preload: TriggerPreload
  ) {
    self.experiment = experiment
    self.expression = expression
    self.expressionJs = expressionJs
    self.expressionCel = expressionCel
    self.occurrence = occurrence
    self.computedPropertyRequests = computedPropertyRequests
    self.preload = preload
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
      expressionCel: nil,
      occurrence: nil,
      computedPropertyRequests: [],
      preload: .init(behavior: .always)
    )
  }
}
