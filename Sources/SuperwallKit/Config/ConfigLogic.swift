//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/07/2022.
//
// swiftlint:disable array_constructor type_body_length

import Foundation

enum ConfigLogic {
  enum TriggerRuleError: Error {
    case noVariantsFound
    case invalidState
  }

  struct AssignmentOutcome {
    let confirmed: [Experiment.ID: Experiment.Variant]
    let unconfirmed: [Experiment.ID: Experiment.Variant]
  }

  static func chooseVariant(
    from variants: [VariantOption],
    randomiser: (Range<Int>) -> Int = Int.random(in:)
  ) throws -> Experiment.Variant {
    if variants.isEmpty {
      throw TriggerRuleError.noVariantsFound
    }

    // If there's only one variant, return it.
    // This could have a zero percentage.
    if variants.count == 1,
       let variant = variants.first {
      return .init(
        id: variant.id,
        type: variant.type,
        paywallId: variant.paywallId
      )
    }

    let validVariants = variants.filter { $0.percentage > 0 }

    // if there is only 1 variant with weight > 0, return it
    if validVariants.count == 1,
      let variant = validVariants.first {
      return .init(
        id: variant.id,
        type: variant.type,
        paywallId: variant.paywallId
      )
    }

    // if there are no variants with weight > 0, choose a random one.
    if validVariants.isEmpty {
      let randomVariantIndex = randomiser(0..<variants.count)
      let variant = variants[randomVariantIndex]
      return .init(
        id: variant.id,
        type: variant.type,
        paywallId: variant.paywallId
      )
    }

    // create an array of variantIds, each repeated by its percentage.
    var validVariantIds: [String] = []
    for variant in validVariants {
      for _ in 0..<variant.percentage {
        validVariantIds.append(variant.id)
      }
    }

    // choose a random variant id from the array.
    let randomVariantIndex = randomiser(0..<validVariantIds.count)
    let variantId = validVariantIds[randomVariantIndex]
    if let variant = variants.first(where: { $0.id == variantId }) {
      return .init(
        id: variant.id,
        type: variant.type,
        paywallId: variant.paywallId
      )
    }

    throw TriggerRuleError.invalidState
  }

  /// Gets the rules per unique experiment group. If any trigger belongs to an experiment whose rule has
  /// already been retrieved, it gets skipped.
  ///
  /// - Parameters:
  ///   - triggers: A set of triggers
  ///
  /// - Returns: A `Set` of `TriggerRule` arrays.
  static func getRulesPerCampaign(
    from triggers: Set<Trigger>
  ) -> Set<[TriggerRule]> {
    var campaignIds: Set<String> = []
    var uniqueTriggerRules: Set<[TriggerRule]> = []
    for trigger in triggers {
      guard let firstRule = trigger.rules.first else {
        continue
      }
      let campaignId = firstRule.experiment.groupId

      if campaignIds.contains(campaignId) {
        continue
      }

      campaignIds.insert(campaignId)
      uniqueTriggerRules.insert(trigger.rules)
    }
    return uniqueTriggerRules
  }

  static func chooseAssignments(
    fromTriggers triggers: Set<Trigger>,
    confirmedAssignments: [Experiment.ID: Experiment.Variant]
  ) -> AssignmentOutcome {
    var confirmedAssignments = confirmedAssignments
    var unconfirmedAssignments: [Experiment.ID: Experiment.Variant] = [:]

    let groupedTriggerRules = getRulesPerCampaign(from: triggers)

    // Loop through each trigger and each of its rules.
    for ruleGroup in groupedTriggerRules {
      for rule in ruleGroup {
        let availableVariantIds = Set(rule.experiment.variants.map { $0.id })

        // Check whether we have already chosen a variant for the experiment on disk.
        if let confirmedVariant = confirmedAssignments[rule.experiment.id] {
          // If one exists, check it's still in the available variants of the experiment's rules, otherwise reroll.
          if !availableVariantIds.contains(confirmedVariant.id) {
            // If we couldn't choose a variant, because of an invalid state, such as no variants available, delete the confirmed assignment.
            guard let variant = try? Self.chooseVariant(from: rule.experiment.variants) else {
              confirmedAssignments[rule.experiment.id] = nil
              continue
            }
            unconfirmedAssignments[rule.experiment.id] = variant
            confirmedAssignments[rule.experiment.id] = nil
          }
        } else {
          // No variant found on disk so dice roll to choose a variant and store in memory as an unconfirmed assignment.
          guard let variant = try? Self.chooseVariant(from: rule.experiment.variants) else {
            continue
          }
          unconfirmedAssignments[rule.experiment.id] = variant
        }
      }
    }

    return AssignmentOutcome(
      confirmed: confirmedAssignments,
      unconfirmed: unconfirmedAssignments
    )
  }

  static func move(
    _ newAssignment: ConfirmableAssignment,
    from unconfirmedAssignments: [Experiment.ID: Experiment.Variant],
    to confirmedAssignments: [Experiment.ID: Experiment.Variant]
  ) -> AssignmentOutcome {
    var confirmedAssignments = confirmedAssignments
    confirmedAssignments[newAssignment.experimentId] = newAssignment.variant

    var unconfirmedAssignments = unconfirmedAssignments
    unconfirmedAssignments[newAssignment.experimentId] = nil

    return ConfigLogic.AssignmentOutcome(
      confirmed: confirmedAssignments,
      unconfirmed: unconfirmedAssignments
    )
  }

  /// Removes any triggers whose preloading has been remotely disabled.
  static func filterTriggers(
    _ triggers: Set<Trigger>,
    removing preloadingDisabled: PreloadingDisabled
  ) -> Set<Trigger> {
    if preloadingDisabled.all {
      return []
    }

    return triggers.filter {
      !preloadingDisabled.triggers.contains($0.eventName)
    }
  }

  /// Loops through assignments retrieved from the server to get variants by id.
  /// Returns updated confirmed/unconfirmed assignments to save.
  static func transferAssignmentsFromServerToDisk(
    assignments: [Assignment],
    triggers: Set<Trigger>,
    confirmedAssignments: [Experiment.ID: Experiment.Variant],
    unconfirmedAssignments: [Experiment.ID: Experiment.Variant]
  ) -> AssignmentOutcome {
    var confirmedAssignments = confirmedAssignments
    var unconfirmedAssignments = unconfirmedAssignments

    for assignment in assignments {
      // Get the trigger with the matching experiment ID
      guard let trigger = triggers.first(
        where: { $0.rules.contains(where: { $0.experiment.id == assignment.experimentId }) }
      ) else {
        continue
      }
      // Get the variant with the matching variant ID
      guard let variantOption = trigger.rules.compactMap({
        $0.experiment.variants.first { $0.id == assignment.variantId }
      }).first else {
        continue
      }

      // Save this to disk, remove any unconfirmed assignments with the same experiment ID.
      confirmedAssignments[assignment.experimentId] = variantOption.toVariant()
      unconfirmedAssignments[assignment.experimentId] = nil
    }

    return .init(
      confirmed: confirmedAssignments,
      unconfirmed: unconfirmedAssignments
    )
  }

  static func getStaticPaywall(
    withId paywallId: String?,
    config: Config?,
    deviceLocale: String
  ) -> Paywall? {
    guard let paywallId = paywallId else {
      return nil
    }
    guard let config = config else {
      return nil
    }

    // If the available locales contains the exact device locale, load the response the old way.
    if config.locales.contains(deviceLocale) {
      return nil
    } else {
      guard let shortLocaleElement = deviceLocale.split(separator: "_").first else {
        return nil
      }
      let shortLocale = String(shortLocaleElement)

      // Otherwise, if the shortened locale contains "en", load the paywall responses from static config.
      // Same if we can't find any matching locale in available locales.
      if shortLocale == "en" || !config.locales.contains(shortLocale) {
        return config.paywalls.first { $0.identifier == paywallId }
      } else {
        return nil
      }
    }
  }

  static func getAllActiveTreatmentPaywallIds(
    fromTriggers triggers: Set<Trigger>,
    confirmedAssignments: [Experiment.ID: Experiment.Variant],
    unconfirmedAssignments: [Experiment.ID: Experiment.Variant],
    expressionEvaluator: ExpressionEvaluating
  ) async -> Set<String> {
    var confirmedAssignments = confirmedAssignments

    let confirmedExperimentIds = Set(confirmedAssignments.keys)
    let triggerRulesPerCampaign = getRulesPerCampaign(from: triggers)

    // Loop through all the rules and check their preloading behaviour.
    // If they should never preload or set to ifTrue but don't match,
    // skip the experiment.
    var allExperimentIds: Set<String> = []
    var skippedExperimentIds: Set<String> = []

    for campaignRules in triggerRulesPerCampaign {
      for rule in campaignRules {
        allExperimentIds.insert(rule.experiment.id)

        switch rule.preload.behavior {
        case .ifTrue:
          let outcome = await expressionEvaluator.evaluateExpression(
            fromRule: rule,
            eventData: nil
          )
          switch outcome {
          case .noMatch:
            skippedExperimentIds.insert(rule.experiment.id)
          case .match:
            continue
          }
        case .always:
          continue
        case .never:
          skippedExperimentIds.insert(rule.experiment.id)
        }
      }
    }

    // Remove any confirmed experiment IDs that are no
    // longer part of a trigger. This could happen when a campaign
    // has been archived.
    let unusedExperimentIds = confirmedExperimentIds.subtracting(allExperimentIds)
    for id in unusedExperimentIds {
      confirmedAssignments.removeValue(forKey: id)
    }

    // Remove any assignments whose variants we don't want to preload.
    var mergedAssignments = confirmedAssignments + unconfirmedAssignments
    for id in skippedExperimentIds {
      mergedAssignments.removeValue(forKey: id)
    }
    let preloadableVariants = mergedAssignments.values

    // Only select the variants that will result in a paywall rather
    // than a holdout.
    var identifiers = Set<String>()

    for variant in preloadableVariants {
      if variant.type == .treatment,
        let paywallId = variant.paywallId {
        identifiers.insert(paywallId)
      }
    }

    return identifiers
  }

  static func getActiveTreatmentPaywallIds(
    forTriggers triggers: Set<Trigger>,
    confirmedAssignments: [Experiment.ID: Experiment.Variant],
    unconfirmedAssignments: [Experiment.ID: Experiment.Variant]
  ) -> Set<String> {
    let mergedAssignments = confirmedAssignments.merging(unconfirmedAssignments)
    let groupedTriggerRules = getRulesPerCampaign(from: triggers)
    let triggerExperimentIds = groupedTriggerRules.flatMap { $0.map { $0.experiment.id } }

    var identifiers = Set<String>()
    for experimentId in triggerExperimentIds {
      guard let variant = mergedAssignments[experimentId] else {
        continue
      }
      if variant.type == .treatment,
        let paywallId = variant.paywallId {
        identifiers.insert(paywallId)
      }
    }

    return identifiers
  }

  static func getTriggersByEventName(from triggers: Set<Trigger>) -> [String: Trigger] {
    let triggersDictionary = triggers.reduce([String: Trigger]()) { result, trigger in
      var result = result
      result[trigger.eventName] = trigger
      return result
    }
    return triggersDictionary
  }

  /// Gets the paywall IDs that no longer exist in the newly retrieved config, minus
  /// any presenting paywall.
  static func getRemovedOrChangedPaywallIds(
    oldConfig: Config,
    newConfig: Config
  ) -> Set<String> {
    let oldPaywalls = oldConfig.paywalls
    let newPaywalls = newConfig.paywalls

    let oldPaywallIds = Set(oldPaywalls.map { $0.identifier })
    let newPaywallIds = Set(newPaywalls.map { $0.identifier })

    // Create dictionary for quick lookup of cacheKeys
    let oldPaywallCacheKeys = Dictionary(uniqueKeysWithValues: oldPaywalls.map { ($0.identifier, $0.cacheKey) })

    let removedPaywallIds = oldPaywallIds.subtracting(newPaywallIds)

    // Find identifiers that are no longer in the new configuration or whose cacheKey has changed
    let removedOrChangedPaywallIds = removedPaywallIds
      .union(
        newPaywalls.filter { paywall in
          let cacheKeyExists = oldPaywallCacheKeys[paywall.identifier] != nil
          let cacheKeyChanged = oldPaywallCacheKeys[paywall.identifier] != paywall.cacheKey
          return cacheKeyExists && cacheKeyChanged
        }
        .map { $0.identifier }
      )

    return removedOrChangedPaywallIds
  }
}
