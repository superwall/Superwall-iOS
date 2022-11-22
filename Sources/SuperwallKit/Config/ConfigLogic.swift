//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/07/2022.
//
// swiftlint:disable array_constructor

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

    // Calculate the total sum of variant percentages.
    let variantSum = variants.reduce(0) { partialResult, variant in
      partialResult + variant.percentage
    }

    // Choose a random percentage e.g. 21
    let randomPercentage = randomiser(0..<variantSum)

    // Normalise the percentage e.g. 21/99 = 0.212
    let normRandomPercentage = Double(randomPercentage) / Double(variantSum)

    var totalNormVariantPercentage = 0.0

    // Loop through all variants
    for variant in variants {
      // Calculate the normalised variant percentage, e.g. 20 -> 0.2
      let normVariantPercentage = Double(variant.percentage) / Double(variantSum)

      // Add to total variant percentage
      totalNormVariantPercentage += normVariantPercentage

      // See if selected is less than total. If it is then break .
      // e.g. Loop 1: 0.212 < (0 + 0.2) = nope, Loop 2: 0.212 < (0.2 + 0.3) = match
      if normRandomPercentage < totalNormVariantPercentage {
        return .init(
          id: variant.id,
          type: variant.type,
          paywallId: variant.paywallId
        )
      }
    }

    throw TriggerRuleError.invalidState
  }

  static func getRulesPerTriggerGroup(
    from triggers: Set<Trigger>
  ) -> Set<[TriggerRule]> {
    var groupIds: Set<String> = []
    var groupedTriggerRules: Set<[TriggerRule]> = []
    for trigger in triggers {
      guard let firstRule = trigger.rules.first else {
        continue
      }
      let groupId = firstRule.experiment.groupId

      if groupIds.contains(groupId) {
        continue
      }

      groupIds.insert(groupId)
      groupedTriggerRules.insert(trigger.rules)
    }
    return groupedTriggerRules
  }

  static func chooseAssignments(
    fromTriggers triggers: Set<Trigger>,
    confirmedAssignments: [Experiment.ID: Experiment.Variant]
  ) -> AssignmentOutcome {
    var confirmedAssignments = confirmedAssignments
    var unconfirmedAssignments: [Experiment.ID: Experiment.Variant] = [:]

    let groupedTriggerRules = getRulesPerTriggerGroup(from: triggers)

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
    deviceHelper: DeviceHelper = .shared
  ) -> Paywall? {
    guard let paywallId = paywallId else {
      return nil
    }
    guard let config = config else {
      return nil
    }

    // If the available locales contains the exact device locale, load the response the old way.
    if config.locales.contains(deviceHelper.locale) {
      return nil
    } else {
      guard let shortLocaleElement = deviceHelper.locale.split(separator: "_").first else {
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
    unconfirmedAssignments: [Experiment.ID: Experiment.Variant]
  ) -> Set<String> {
    var confirmedAssignments = confirmedAssignments

    // Don't preload any experiment IDs that are on disk but no longer in static config.
    // This could happen when a campaign has been archived.
    let confirmedExperimentIds = Set(confirmedAssignments.keys)
    let groupedTriggerRules = getRulesPerTriggerGroup(from: triggers)
    let triggerExperimentIds = groupedTriggerRules.flatMap { $0.map { $0.experiment.id } }
    let oldExperimentIds = confirmedExperimentIds.subtracting(triggerExperimentIds)
    for id in oldExperimentIds {
      confirmedAssignments[id] = nil
    }

    let confirmedVariants = [Experiment.Variant](confirmedAssignments.values)
    let unconfirmedVariants = [Experiment.Variant](unconfirmedAssignments.values)
    let mergedVariants = confirmedVariants + unconfirmedVariants
    var identifiers = Set<String>()

    for variant in mergedVariants {
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
    let groupedTriggerRules = getRulesPerTriggerGroup(from: triggers)
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
}
