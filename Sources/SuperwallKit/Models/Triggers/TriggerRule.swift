//
//  TriggerRule.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct UnmatchedAudience: Equatable {
  enum Source: String {
    case expression = "EXPRESSION"
    case occurrence = "OCCURRENCE"
  }
  let source: Source
  let experimentId: String
}

extension UnmatchedAudience: Stubbable {
  static func stub() -> UnmatchedAudience {
    return UnmatchedAudience(
      source: .expression,
      experimentId: "1"
    )
  }
}

struct MatchedItem {
  let audience: TriggerRule
  let unsavedOccurrence: TriggerAudienceOccurrence?
}

extension MatchedItem: Stubbable {
  static func stub() -> MatchedItem {
    return MatchedItem(
      audience: .stub(),
      unsavedOccurrence: nil
    )
  }
}

enum TriggerAudienceOutcome: Equatable {
  static func == (lhs: TriggerAudienceOutcome, rhs: TriggerAudienceOutcome) -> Bool {
    switch (lhs, rhs) {
    case let (.match(item1), .match(item2)):
      return item1.audience == item2.audience
        && item1.unsavedOccurrence == item2.unsavedOccurrence
    case let (.noMatch(unmatchedAudience1), .noMatch(unmatchedAudience2)):
      return unmatchedAudience1.source == unmatchedAudience2.source
        && unmatchedAudience1.experimentId == unmatchedAudience2.experimentId
    default:
      return false
    }
  }

  case noMatch(UnmatchedAudience)
  case match(MatchedItem)

  static func noMatch(
    source: UnmatchedAudience.Source,
    experimentId: String
  ) -> TriggerAudienceOutcome {
    return .noMatch(.init(source: source, experimentId: experimentId))
  }

  static func match(
    audience: TriggerRule,
    unsavedOccurrence: TriggerAudienceOccurrence? = nil
  ) -> TriggerAudienceOutcome {
    return .match(.init(audience: audience, unsavedOccurrence: unsavedOccurrence))
  }
}

struct TriggerRule: Decodable, Hashable {
  var experiment: RawExperiment
  var expression: String?
  var expressionJs: String?
  var occurrence: TriggerAudienceOccurrence?
  let computedPropertyRequests: [ComputedPropertyRequest]
  var preload: TriggerPreload

  struct TriggerPreload: Decodable, Hashable {
    enum TriggerPreloadBehavior: String, Decodable {
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
    occurrence = try values.decodeIfPresent(TriggerAudienceOccurrence.self, forKey: .occurrence)
    preload = try values.decode(TriggerPreload.self, forKey: .preload)

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
    occurrence: TriggerAudienceOccurrence? = nil,
    computedPropertyRequests: [ComputedPropertyRequest],
    preload: TriggerPreload
  ) {
    self.experiment = experiment
    self.expression = expression
    self.expressionJs = expressionJs
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
      occurrence: nil,
      computedPropertyRequests: [],
      preload: .init(behavior: .always)
    )
  }
}
