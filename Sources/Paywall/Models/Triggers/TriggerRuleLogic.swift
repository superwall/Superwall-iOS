//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/07/2022.
//

import Foundation

enum TriggerRuleLogic {
  enum TriggerRuleError: Error {
    case noVariantsFound
    case invalidState
  }

  static func chooseVariant(from variants: [VariantOption]) throws -> Experiment.Variant {
    if variants.isEmpty {
      throw TriggerRuleError.noVariantsFound
    }
    let variantSum = variants.reduce(0, { partialResult, variant in
      partialResult + variant.percentage
    })

    if variantSum == 0 {
      let firstVariant = variants.first!
      return .init(
        id: firstVariant.id,
        type: firstVariant.type,
        paywallId: firstVariant.paywallId
      )
    }

    // Choose a random percentage e.g. 21
    let randomPercentage = Int.random(in: 0..<variantSum)

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
}
