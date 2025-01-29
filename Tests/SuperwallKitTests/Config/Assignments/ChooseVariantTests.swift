//
//  ChooseVariantTests.swift
//  SuperwallKit
//
//  Created by Jake Mor on 1/29/25.
//

import XCTest
@testable import SuperwallKit

@available(iOS 14, *)
class ChooseVariantTests: XCTestCase {


  // MARK: - New Test for chooseVariant Distribution

  func testChooseVariant_distribution() throws {
    // MARK: Given
    // Define the variants with specified percentages
    let variants: [VariantOption] = [
      VariantOption(
        type: .treatment,
        id: "A",
        percentage: 85,
        paywallId: nil
      ),

      VariantOption(
        type: .treatment,
        id: "C",
        percentage: 5,
        paywallId: nil
      ),
      VariantOption(
        type: .treatment,
        id: "D",
        percentage: 5,
        paywallId: nil
      ),
      VariantOption(
        type: .treatment,
        id: "B",
        percentage: 5,
        paywallId: nil
      ),
    ]

    // Initialize counters for each variant
    var selectionCounts: [String: Int] = ["A": 0, "B": 0, "C": 0, "D": 0]

    // Number of iterations
    let iterations = 1_000_000

    // MARK: When
    // Run chooseVariant multiple times and count selections
    for _ in 1...iterations {
      let selectedVariant = try Self.chooseVariant(from: variants)
      selectionCounts[selectedVariant.id, default: 0] += 1
    }

    // MARK: Then
    // Calculate observed percentages
    let observedPercentages: [String: Double] = selectionCounts.mapValues { Double($0) / Double(iterations) * 100 }

    // Define expected percentages
    let expectedPercentages: [String: Double] = ["A": 85.0, "B": 5.0, "C": 5.0, "D": 5.0]

    // Define acceptable margin of error (e.g., ±1%)
    let marginOfError = 1.0

    // Assert that each observed percentage is within the acceptable range
    for (variantID, expectedPercentage) in expectedPercentages {
      guard let observedPercentage = observedPercentages[variantID] else {
        XCTFail("Variant \(variantID) was not selected at all.")
        continue
      }
      XCTAssertEqual(
        observedPercentage,
        expectedPercentage,
        accuracy: marginOfError,
        "Variant \(variantID) selection percentage \(observedPercentage)% is not within \(marginOfError)% of expected \(expectedPercentage)%."
      )
    }

    // Optional: Print the results for debugging purposes
    print("Variant Selection Distribution after \(iterations) iterations:")
    for (variantID, count) in selectionCounts {
      let percentage = observedPercentages[variantID] ?? 0.0
      print("Variant \(variantID): \(count) selections (\(String(format: "%.2f", percentage))%)")
    }
  }

  // MARK: - Helper Method for chooseVariant

  /// Helper method to access the chooseVariant function.
  /// Adjust the access level based on where chooseVariant is defined.
  static func chooseVariant(
    from variants: [VariantOption]
  ) throws -> Experiment.Variant {
    return try ConfigLogic.chooseVariant(from: variants)
  }

  // Replace `YourVariantChooser` with the actual type or namespace where `chooseVariant` is defined.
  // If `chooseVariant` is defined globally, you can call it directly without wrapping.
}
