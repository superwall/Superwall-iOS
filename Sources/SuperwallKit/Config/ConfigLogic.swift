//
//  File.swift
//
//
//  Created by Yusuf Tör on 21/07/2022.
//
// swiftlint:disable array_constructor type_body_length

import Foundation

enum ConfigLogic {
  enum TriggerAudienceError: Error {
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
      throw TriggerAudienceError.noVariantsFound
    }

    // If there's only one variant, return it.
    if variants.count == 1,
      let variant = variants.first {
      return variant.toExperimentVariant()
    }

    // Calculate the total sum of variant percentages.
    let variantSum = variants.reduce(0) { $0 + $1.percentage }

    // If all variants have 0% set, choose a random one.
    if variantSum == 0 {
      let randomIndex = randomiser(0..<variants.count)
      return variants[randomIndex].toExperimentVariant()
    }

    // Choose a random threshold within the total sum.
    let randomThreshold = randomiser(0..<variantSum)
    var cumulativeSum = 0

    // Iterate through variants and return the first that crosses the threshold.
    for variant in variants {
      cumulativeSum += variant.percentage
      if randomThreshold < cumulativeSum {
        return variant.toExperimentVariant()
      }
    }

    throw TriggerAudienceError.invalidState
  }

  /// Gets the audiences per unique experiment group. If any trigger belongs to an experiment whose audience has
  /// already been retrieved, it gets skipped.
  ///
  /// - Parameters:
  ///   - triggers: A set of triggers
  ///
  /// - Returns: A `Set` of `TriggerRule` arrays.
  static func getAudienceFiltersPerCampaign(
    from triggers: Set<Trigger>
  ) -> Set<[TriggerRule]> {
    var campaignIds: Set<String> = []
    var uniqueTriggerAudiences: Set<[TriggerRule]> = []
    for trigger in triggers {
      guard let firstAudience = trigger.audiences.first else {
        continue
      }
      let campaignId = firstAudience.experiment.groupId

      if campaignIds.contains(campaignId) {
        continue
      }

      campaignIds.insert(campaignId)
      uniqueTriggerAudiences.insert(trigger.audiences)
    }
    return uniqueTriggerAudiences
  }

  static func chooseAssignments(
    fromTriggers triggers: Set<Trigger>,
    confirmedAssignments: Set<Assignment>
  ) -> Set<Assignment> {
    var confirmedAssignments = confirmedAssignments

    let groupedTriggerAudiences = getAudienceFiltersPerCampaign(from: triggers)

    // Loop through each trigger and each of its audiences.
    for audienceGroup in groupedTriggerAudiences {
      for audience in audienceGroup {
        let availableVariantIds = Set(audience.experiment.variants.map { $0.id })

        // Check whether we have already chosen a variant for the experiment on disk.
        if let index = confirmedAssignments.firstIndex(
          where: { $0.experimentId == audience.experiment.id }
        ) {
          let confirmedVariant = confirmedAssignments[index].variant
          // If the variant doesn't exist anymore, remove and choose a new one.
          if !availableVariantIds.contains(confirmedVariant.id) {
            confirmedAssignments.remove(at: index)

            // If we couldn't choose a variant, because of an invalid state, such as no variants available, continue.
            guard let newVariant = try? Self.chooseVariant(from: audience.experiment.variants) else {
              continue
            }
            confirmedAssignments.insert(
              Assignment(
                experimentId: audience.experiment.id,
                variant: newVariant,
                isSentToServer: false
              )
            )
          }
        } else {
          // No variant found on disk so dice roll to choose a variant and store in memory
          guard let newVariant = try? Self.chooseVariant(from: audience.experiment.variants) else {
            continue
          }
          confirmedAssignments.insert(
            Assignment(
              experimentId: audience.experiment.id,
              variant: newVariant,
              isSentToServer: false
            )
          )
        }
      }
    }

    return confirmedAssignments
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
      !preloadingDisabled.triggers.contains($0.placementName)
    }
  }

  /// Loops through assignments retrieved from the server to get variants by id.
  /// Returns updated confirmed/unconfirmed assignments to save.
  static func transferAssignmentsFromServerToDisk(
    serverAssignments: [PostbackAssignment],
    triggers: Set<Trigger>,
    localAssignments: Set<Assignment>
  ) -> Set<Assignment> {
    var localAssignments = localAssignments

    for serverAssignment in serverAssignments {
      // Get the trigger with the matching experiment ID
      guard
        let trigger = triggers.first(
          where: { $0.audiences.contains(where: { $0.experiment.id == serverAssignment.experimentId }) }
        )
      else {
        continue
      }
      // Get the variant with the matching variant ID
      guard
        let variantOption = trigger.audiences.compactMap({
          $0.experiment.variants.first { $0.id == serverAssignment.variantId }
        }).first
      else {
        continue
      }

      localAssignments.update(with:
        Assignment(
          experimentId: serverAssignment.experimentId,
          variant: variantOption.toExperimentVariant(),
          isSentToServer: true
        )
      )
    }

    return localAssignments
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
    assignments: Set<Assignment>,
    expressionEvaluator: ExpressionEvaluating
  ) async -> Set<String> {
    var assignments = assignments

    let audienceFilters = getAudienceFiltersPerCampaign(from: triggers).flatMap { $0 }

    // Collect all experiment IDs and determine which ones should be skipped.
    var allExperimentIds = Set<String>()
    var skippedExperimentIds = Set<String>()

    for audienceFilter in audienceFilters {
      let experimentId = audienceFilter.experiment.id
      allExperimentIds.insert(experimentId)

      switch audienceFilter.preload.behavior {
      case .ifTrue:
        let outcome = await expressionEvaluator.evaluateExpression(
          fromAudienceFilter: audienceFilter,
          placementData: nil
        )
        if case .noMatch = outcome {
          skippedExperimentIds.insert(experimentId)
        }
      case .never:
        skippedExperimentIds.insert(experimentId)
      case .always:
        break
      }
    }

    // Keep only assignments whose experiment IDs are in the active set and not marked as skipped.
    assignments = Set(assignments.filter { assignment in
      allExperimentIds.contains(assignment.experimentId) &&
      !skippedExperimentIds.contains(assignment.experimentId)
    })

    // Extract and return paywall IDs from treatment variants.
    let identifiers = Set(assignments.compactMap { assignment in
      if assignment.variant.type == .treatment,
        let paywallId = assignment.variant.paywallId {
        return paywallId
      }
      return nil
    })

    return identifiers
  }

  static func getActiveTreatmentPaywallIds(
    forTriggers triggers: Set<Trigger>,
    assignments: Set<Assignment>
  ) -> Set<String> {
    let groupedTriggerAudiences = getAudienceFiltersPerCampaign(from: triggers)
    let triggerExperimentIds = groupedTriggerAudiences.flatMap { $0.map { $0.experiment.id } }

    var identifiers = Set<String>()
    for experimentId in triggerExperimentIds {
      guard let variant = assignments.first(where: { $0.experimentId == experimentId })?.variant else {
        continue
      }
      if variant.type == .treatment,
        let paywallId = variant.paywallId {
        identifiers.insert(paywallId)
      }
    }

    return identifiers
  }

  static func getTriggersByPlacementName(from triggers: Set<Trigger>) -> [String: Trigger] {
    let triggersDictionary = triggers.reduce([String: Trigger]()) { result, trigger in
      var result = result
      result[trigger.placementName] = trigger
      return result
    }
    return triggersDictionary
  }

  /// Gets the paywall IDs that no longer exist in the newly retrieved config.
  static func getRemovedOrChangedPaywallIds(
    oldConfig: Config,
    newConfig: Config
  ) -> Set<String> {
    let oldPaywalls = oldConfig.paywalls
    let newPaywalls = newConfig.paywalls

    let oldPaywallIds = Set(oldPaywalls.map { $0.identifier })
    let newPaywallIds = Set(newPaywalls.map { $0.identifier })

    // Create dictionary for quick lookup of cacheKeys
    let oldPaywallCacheKeys = Dictionary(
      uniqueKeysWithValues: oldPaywalls.map { ($0.identifier, $0.cacheKey) })

    let removedPaywallIds = oldPaywallIds.subtracting(newPaywallIds)

    // Find identifiers that are no longer in the new configuration or whose cacheKey has changed
    let removedOrChangedPaywallIds =
      removedPaywallIds
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

  /// Returns the entitlements mapped to a product ID.
  static func extractEntitlements(
    from config: Config
  ) -> [String: Set<Entitlement>] {
    return Dictionary(
      uniqueKeysWithValues: config.products.map { ($0.id, $0.entitlements) }
    )
  }
}
