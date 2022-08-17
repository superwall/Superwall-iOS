//
//  File.swift
//  
//
//  Created by Yusuf Tör on 16/08/2022.
//

@testable import Paywall
import XCTest

final class ConfigLogicTests: XCTestCase {
  // MARK: - Choose Variant
  func test_chooseVariant_noVariants() {
    do {
      let _ = try ConfigLogic.chooseVariant(from: [])
      XCTFail("Should have produced an error")
    } catch let error as ConfigLogic.TriggerRuleError {
      XCTAssertEqual(error, ConfigLogic.TriggerRuleError.noVariantsFound)
    } catch {
      XCTFail("Should have produced a no variant error")
    }
  }

  func test_chooseVariant_zeroPercentageSumVariants() {
    do {
      let _ = try ConfigLogic.chooseVariant(from: [
        .stub()
        .setting(\.percentage, to: 0)
      ])
      XCTFail("Should have produced an error")
    } catch let error as ConfigLogic.TriggerRuleError {
      XCTAssertEqual(error, ConfigLogic.TriggerRuleError.invalidState)
    } catch {
      XCTFail("Should have produced a no variant error")
    }
  }

  func test_chooseVariant_oneActiveVariant_chooseFirst() {
    do {
      let options: [VariantOption] = [
        .stub()
        .setting(\.percentage, to: 100),
        .stub()
        .setting(\.percentage, to: 0),
        .stub()
        .setting(\.percentage, to: 0)
      ]
      let variant = try ConfigLogic.chooseVariant(from: options)
      XCTAssertEqual(options.first!.toVariant(), variant)
    } catch {
      XCTFail("Should have produced a no variant error")
    }
  }

  func test_chooseVariant_99PercentSumVariants_chooseLast() {
    do {
      let options: [VariantOption] = [
        .stub()
        .setting(\.percentage, to: 33),
        .stub()
        .setting(\.percentage, to: 33),
        .stub()
        .setting(\.percentage, to: 33)
      ]
      let variant = try ConfigLogic.chooseVariant(
        from: options,
        randomiser: { range in
          XCTAssertEqual(range, 0..<99)
          return 98
        }
      )
      XCTAssertEqual(options.last!.toVariant(), variant)
    } catch {
      XCTFail("Should have produced a no variant error")
    }
  }

  func test_chooseVariant_99PercentSumVariants_chooseMiddle() {
    do {
      let options: [VariantOption] = [
        .stub()
        .setting(\.percentage, to: 33),
        .stub()
        .setting(\.percentage, to: 33),
        .stub()
        .setting(\.percentage, to: 33)
      ]
      let variant = try ConfigLogic.chooseVariant(
        from: options,
        randomiser: { range in
          XCTAssertEqual(range, 0..<99)
          return 65
        }
      )
      XCTAssertEqual(options[1].toVariant(), variant)
    } catch {
      XCTFail("Should have produced a no variant error")
    }
  }

  func test_chooseVariant_99PercentSumVariants_chooseFirst() {
    do {
      let options: [VariantOption] = [
        .stub()
        .setting(\.percentage, to: 33),
        .stub()
        .setting(\.percentage, to: 33),
        .stub()
        .setting(\.percentage, to: 33)
      ]
      let variant = try ConfigLogic.chooseVariant(
        from: options,
        randomiser: { range in
          XCTAssertEqual(range, 0..<99)
          return 0
        }
      )
      XCTAssertEqual(options.first!.toVariant(), variant)
    } catch {
      XCTFail("Should have produced a no variant error")
    }
  }

  // MARK: - getRulesPerTriggerGroup

  func test_getRulesPerTriggerGroup_noTriggers() {
    let rules = ConfigLogic.getRulesPerTriggerGroup(from: [])
    XCTAssertTrue(rules.isEmpty)
  }

  func test_getRulesPerTriggerGroup_threeTriggersTwoWithSameGroupId() {
    let trigger1 = Trigger.stub()
      .setting(\.rules, to: [
        .stub()
        .setting(\.experiment.groupId, to: "1")
      ])
    let trigger2 = Trigger.stub()
      .setting(\.rules, to: [
        .stub()
        .setting(\.experiment.groupId, to: "1")
      ])
    let trigger3 = Trigger.stub()
      .setting(\.rules, to: [
        .stub()
        .setting(\.experiment.groupId, to: "2")
      ])
    let rules = ConfigLogic.getRulesPerTriggerGroup(from: [
      trigger1, trigger2, trigger3
    ])
    XCTAssertEqual(rules.count, 2)
    XCTAssertTrue(rules.contains(trigger3.rules))
    XCTAssertTrue(rules.contains(trigger1.rules))
  }

  // MARK: - Assign Variants
  func test_assignVariants_noTriggers() {
    // Given
    let confirmedAssignments = [
      "exp1": Experiment.Variant(
        id: "1",
        type: .treatment,
        paywallId: "abc"
      )
    ]
    let unconfirmedAssignments = [
      "exp2": Experiment.Variant(
        id: "3",
        type: .holdout,
        paywallId: "def"
      )
    ]

    // When
    let variant = ConfigLogic.assignVariants(
      fromTriggers: [],
      confirmedAssignments: confirmedAssignments,
      unconfirmedAssignments: unconfirmedAssignments
    )

    // Then
    XCTAssertEqual(variant.unconfirmedAssignments, unconfirmedAssignments)
    XCTAssertEqual(variant.confirmedAssignments, confirmedAssignments)
  }

  func test_assignVariants_noRules() {
    // Given
    let confirmedAssignments = [
      "exp1": Experiment.Variant(
        id: "1",
        type: .treatment,
        paywallId: "abc"
      )
    ]
    let unconfirmedAssignments = [
      "exp2": Experiment.Variant(
        id: "3",
        type: .holdout,
        paywallId: "def"
      )
    ]

    // When
    let variant = ConfigLogic.assignVariants(
      fromTriggers: [
        .stub()
        .setting(\.rules, to: [])
      ],
      confirmedAssignments: confirmedAssignments,
      unconfirmedAssignments: unconfirmedAssignments
    )

    // Then
    XCTAssertEqual(variant.unconfirmedAssignments, unconfirmedAssignments)
    XCTAssertEqual(variant.confirmedAssignments, confirmedAssignments)
  }

  func test_assignVariants_variantAsOfYetUnconfirmed() {
    // Given
    let variantId = "abc"
    let paywallId = "edf"
    let experimentId = "3"
    let experimentGroupId = "13"
    let variantOption: VariantOption = .stub()
      .setting(\.id, to: variantId)
      .setting(\.paywallId, to: paywallId)
      .setting(\.type, to: .treatment)

    // When
    let variant = ConfigLogic.assignVariants(
      fromTriggers: [
        .stub()
        .setting(\.rules, to: [
          .stub()
          .setting(\.experiment, to: .stub()
            .setting(\.id, to: experimentId)
            .setting(\.groupId, to: experimentGroupId)
            .setting(\.variants, to: [
              variantOption
            ])
          )
        ])
      ],
      confirmedAssignments: [:],
      unconfirmedAssignments: [:]
    )

    // When
    XCTAssertEqual(variant.unconfirmedAssignments.count, 1)
    XCTAssertEqual(variant.unconfirmedAssignments[experimentId], variantOption.toVariant())
    XCTAssertTrue(variant.confirmedAssignments.isEmpty)
  }

  func test_assignVariants_variantAlreadyConfirmed() {
    // Given
    let variantId = "abc"
    let paywallId = "edf"
    let experimentId = "3"
    let experimentGroupId = "13"
    let variantOption: VariantOption = .stub()
      .setting(\.id, to: variantId)
      .setting(\.paywallId, to: paywallId)
      .setting(\.type, to: .treatment)

    // When
    let variant = ConfigLogic.assignVariants(
      fromTriggers: [
        .stub()
        .setting(\.rules, to: [
          .stub()
          .setting(\.experiment, to: .stub()
            .setting(\.id, to: experimentId)
            .setting(\.groupId, to: experimentGroupId)
            .setting(\.variants, to: [
              variantOption
            ])
          )
        ])
      ],
      confirmedAssignments: [experimentId: variantOption.toVariant()],
      unconfirmedAssignments: [:]
    )

    // Then
    XCTAssertEqual(variant.confirmedAssignments.count, 1)
    XCTAssertEqual(variant.confirmedAssignments[experimentId], variantOption.toVariant())
    XCTAssertTrue(variant.unconfirmedAssignments.isEmpty)
  }

  func test_assignVariants_variantAlreadyConfirmed_nowUnavailable() {
    // Given
    let paywallId = "edf"
    let experimentId = "3"
    let experimentGroupId = "13"
    let newVariantOption: VariantOption = .stub()
      .setting(\.id, to: "newVariantId")
      .setting(\.paywallId, to: paywallId)
      .setting(\.type, to: .treatment)
    let oldVariantOption: VariantOption = .stub()
      .setting(\.id, to: "oldVariantId")
      .setting(\.paywallId, to: paywallId)
      .setting(\.type, to: .treatment)

    // When
    let variant = ConfigLogic.assignVariants(
      fromTriggers: [
        .stub()
        .setting(\.rules, to: [
          .stub()
          .setting(\.experiment, to: .stub()
            .setting(\.id, to: experimentId)
            .setting(\.groupId, to: experimentGroupId)
            .setting(\.variants, to: [
              newVariantOption
            ])
          )
        ])
      ],
      confirmedAssignments: [experimentId: oldVariantOption.toVariant()],
      unconfirmedAssignments: [:]
    )

    // Then
    XCTAssertEqual(variant.unconfirmedAssignments.count, 1)
    XCTAssertEqual(variant.unconfirmedAssignments[experimentId], newVariantOption.toVariant())
    XCTAssertTrue(variant.confirmedAssignments.isEmpty)
  }
}
