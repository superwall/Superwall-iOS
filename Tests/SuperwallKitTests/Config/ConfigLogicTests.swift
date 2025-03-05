//
//  File.swift
//
//
//  Created by Yusuf Tör on 16/08/2022.
//
// swiftlint:disable all

import XCTest

@testable import SuperwallKit

final class ConfigLogicTests: XCTestCase {
  // MARK: - Choose Variant
  func test_chooseVariant_noVariants() {
    do {
      let _ = try ConfigLogic.chooseVariant(from: [])
      XCTFail("Should have produced an error")
    } catch let error as ConfigLogic.TriggerAudienceError {
      XCTAssertEqual(error, ConfigLogic.TriggerAudienceError.noVariantsFound)
    } catch {
      XCTFail("Should have produced a no variant error")
    }
  }

  func test_chooseVariant_onlyOneVariant_zeroSum() {
    do {
      let options: [VariantOption] = [
        .stub()
          .setting(\.percentage, to: 0)
      ]
      let variant = try ConfigLogic.chooseVariant(from: options)
      XCTAssertEqual(options.first!.toExperimentVariant(), variant)
    } catch {
      XCTFail("Shouldn't fail")
    }
  }

  func test_chooseVariant_1PercentSum() {
    do {
      let options: [VariantOption] = [
        .stub()
          .setting(\.percentage, to: 1),
        .stub()
          .setting(\.percentage, to: 0),
        .stub()
          .setting(\.percentage, to: 0),
      ]
      let variant = try ConfigLogic.chooseVariant(from: options)
      XCTAssertEqual(options.first!.toExperimentVariant(), variant)
    } catch {
      XCTFail("Shouldn't fail")
    }
  }

  func test_chooseVariant_manyVariants_zeroSum() {
    do {
      let options: [VariantOption] = [
        .stub()
          .setting(\.percentage, to: 0),
        .stub()
          .setting(\.percentage, to: 0),
      ]
      let variant = try ConfigLogic.chooseVariant(
        from: options,
        randomiser: { range in
          // Force choosing the first variant
          return 0
        }
      )
    } catch {
      XCTFail("Shouldn't fail")
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
          .setting(\.percentage, to: 0),
      ]
      let variant = try ConfigLogic.chooseVariant(from: options)
      XCTAssertEqual(options.first!.toExperimentVariant(), variant)
    } catch {
      XCTFail("Shouldn't fail")
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
          .setting(\.percentage, to: 33),
      ]
      let variant = try ConfigLogic.chooseVariant(
        from: options,
        randomiser: { range in
          XCTAssertEqual(range, 0..<99)
          return 98
        }
      )
      XCTAssertEqual(options.last!.toExperimentVariant(), variant)
    } catch {
      XCTFail("Shouldn't fail")
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
          .setting(\.percentage, to: 33),
      ]
      let variant = try ConfigLogic.chooseVariant(
        from: options,
        randomiser: { range in
          XCTAssertEqual(range, 0..<99)
          return 65
        }
      )
      XCTAssertEqual(options[1].toExperimentVariant(), variant)
    } catch {
      XCTFail("Shouldn't fail")
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
          .setting(\.percentage, to: 33),
      ]
      let variant = try ConfigLogic.chooseVariant(
        from: options,
        randomiser: { range in
          XCTAssertEqual(range, 0..<99)
          return 0
        }
      )
      XCTAssertEqual(options.first!.toExperimentVariant(), variant)
    } catch {
      XCTFail("Shouldn't fail")
    }
  }

  func testChooseVariant_distribution() throws {
    // MARK: Given
    let variants: [VariantOption] = [
      .stub()
        .setting(\.id, to: "A")
        .setting(\.percentage, to: 85),
      .stub()
        .setting(\.id, to: "B")
        .setting(\.percentage, to: 5),
      .stub()
        .setting(\.id, to: "C")
        .setting(\.percentage, to: 5),
      .stub()
        .setting(\.id, to: "D")
        .setting(\.percentage, to: 5),
    ]

    // Initialize counters for each variant
    var selectionCounts: [String: Int] = ["A": 0, "B": 0, "C": 0, "D": 0]

    // Number of iterations
    let iterations = 100_000

    // MARK: When
    // Run chooseVariant multiple times and count selections
    for _ in 1...iterations {
      let selectedVariant = try ConfigLogic.chooseVariant(from: variants)
      selectionCounts[selectedVariant.id, default: 0] += 1
    }

    // MARK: Then
    // Calculate observed percentages
    let observedPercentages: [String: Double] = selectionCounts.mapValues {
      Double($0) / Double(iterations) * 100
    }

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

  // MARK: - getRulesPerTriggerGroup

  func test_getRulesPerTriggerGroup_noTriggers() {
    let rules = ConfigLogic.getAudienceFiltersPerCampaign(from: [])
    XCTAssertTrue(rules.isEmpty)
  }

  func test_getRulesPerTriggerGroup_noRules() {
    let rules = ConfigLogic.getAudienceFiltersPerCampaign(from: [
      .stub()
        .setting(\.audiences, to: [])
    ])
    XCTAssertTrue(rules.isEmpty)
  }

  func test_getRulesPerTriggerGroup_threeTriggersTwoWithSameGroupId() {
    let trigger1 = Trigger.stub()
      .setting(
        \.audiences,
        to: [
          .stub()
            .setting(\.experiment.groupId, to: "1")
        ])
    let trigger2 = Trigger.stub()
      .setting(
        \.audiences,
        to: [
          .stub()
            .setting(\.experiment.groupId, to: "1")
        ])
    let trigger3 = Trigger.stub()
      .setting(
        \.audiences,
        to: [
          .stub()
            .setting(\.experiment.groupId, to: "2")
        ])
    let rules = ConfigLogic.getAudienceFiltersPerCampaign(from: [
      trigger1, trigger2, trigger3,
    ])
    XCTAssertEqual(rules.count, 2)
    XCTAssertTrue(rules.contains(trigger3.audiences))
    XCTAssertTrue(rules.contains(trigger1.audiences))
  }

  // MARK: - Assign Variants
  func test_assignVariants_noTriggers() {
    // Given
    let confirmedAssignments = Set([
      Assignment(
        experimentId: "exp1",
        variant: Experiment.Variant(
          id: "1",
          type: .treatment,
          paywallId: "abc"
        ),
        isSentToServer: true
      )
    ])

    // When
    let assignments = ConfigLogic.chooseAssignments(
      fromTriggers: [],
      assignments: confirmedAssignments
    )

    // Then
    XCTAssertEqual(assignments, confirmedAssignments)
  }

  func test_chooseVariant_1Percent99Percent_choose1Percent() {
    do {
      let options: [VariantOption] = [
        .stub()
          .setting(\.percentage, to: 1),
        .stub()
          .setting(\.percentage, to: 99),
      ]
      let variant = try ConfigLogic.chooseVariant(
        from: options,
        randomiser: { range in
          XCTAssertEqual(range, 0..<100)
          return 0
        }
      )
      XCTAssertEqual(options.first!.toExperimentVariant(), variant)
    } catch {
      XCTFail("Should have produced a no variant error")
    }
  }

  func test_chooseAssignments_noRules() {
    // Given
    let confirmedAssignments = Set([
      Assignment(
        experimentId: "exp1",
        variant: Experiment.Variant(
          id: "1",
          type: .treatment,
          paywallId: "abc"
        ),
        isSentToServer: true
      )
    ])
    // When
    let variant = ConfigLogic.chooseAssignments(
      fromTriggers: [
        .stub()
          .setting(\.audiences, to: [])
      ],
      assignments: confirmedAssignments
    )

    // Then
    XCTAssertEqual(variant, confirmedAssignments)
  }

  func test_chooseAssignments_variantAsOfYetUnconfirmed() {
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
    let variant = ConfigLogic.chooseAssignments(
      fromTriggers: [
        .stub()
          .setting(
            \.audiences,
            to: [
              .stub()
                .setting(
                  \.experiment,
                  to: .stub()
                    .setting(\.id, to: experimentId)
                    .setting(\.groupId, to: experimentGroupId)
                    .setting(
                      \.variants,
                      to: [
                        variantOption
                      ])
                )
            ])
      ],
      assignments: []
    )

    // When
    XCTAssertEqual(variant.count, 1)
    XCTAssertEqual(variant.first!.variant, variantOption.toExperimentVariant())
  }

  func test_chooseAssignments_variantAlreadyConfirmed() {
    // Given
    let variantId = "abc"
    let paywallId = "edf"
    let experimentId = "3"
    let experimentGroupId = "13"
    let variantOption: VariantOption = .stub()
      .setting(\.id, to: variantId)
      .setting(\.paywallId, to: paywallId)
      .setting(\.type, to: .treatment)
    let confirmedAssignments = Set([
      Assignment(
        experimentId: experimentId,
        variant: variantOption.toExperimentVariant(),
        isSentToServer: true
      )
    ])

    // When
    let assignments = ConfigLogic.chooseAssignments(
      fromTriggers: [
        .stub()
          .setting(
            \.audiences,
            to: [
              .stub()
                .setting(
                  \.experiment,
                  to: .stub()
                    .setting(\.id, to: experimentId)
                    .setting(\.groupId, to: experimentGroupId)
                    .setting(
                      \.variants,
                      to: [
                        variantOption
                      ])
                )
            ])
      ],
      assignments: confirmedAssignments
    )

    // Then
    XCTAssertEqual(assignments.count, 1)
    XCTAssertEqual(assignments.first!.variant, variantOption.toExperimentVariant())
  }

  func test_chooseAssignments_variantAlreadyConfirmed_nowUnavailable() {
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
    let confirmedAssignments = Set([
      Assignment(
        experimentId: experimentId,
        variant: oldVariantOption.toExperimentVariant(),
        isSentToServer: true
      )
    ])

    // When
    let assignments = ConfigLogic.chooseAssignments(
      fromTriggers: [
        .stub()
          .setting(
            \.audiences,
            to: [
              .stub()
                .setting(
                  \.experiment,
                  to: .stub()
                    .setting(\.id, to: experimentId)
                    .setting(\.groupId, to: experimentGroupId)
                    .setting(
                      \.variants,
                      to: [
                        newVariantOption
                      ])
                )
            ])
      ],
      assignments: confirmedAssignments
    )

    // Then
    XCTAssertEqual(assignments.count, 1)
    XCTAssertEqual(assignments.first!.variant, newVariantOption.toExperimentVariant())
  }

  func test_chooseAssignments_variantAlreadyConfirmed_nowNoVariants() {
    // Given
    let paywallId = "edf"
    let experimentId = "3"
    let experimentGroupId = "13"
    let oldVariantOption: VariantOption = .stub()
      .setting(\.id, to: "oldVariantId")
      .setting(\.paywallId, to: paywallId)
      .setting(\.type, to: .treatment)
    let confirmedAssignments = Set([
      Assignment(
        experimentId: experimentId,
        variant: oldVariantOption.toExperimentVariant(),
        isSentToServer: true
      )
    ])

    // When
    let assignments = ConfigLogic.chooseAssignments(
      fromTriggers: [
        .stub()
          .setting(
            \.audiences,
            to: [
              .stub()
                .setting(
                  \.experiment,
                  to: .stub()
                    .setting(\.id, to: experimentId)
                    .setting(\.groupId, to: experimentGroupId)
                    .setting(\.variants, to: [])
                )
            ])
      ],
      assignments: confirmedAssignments
    )

    // Then
    XCTAssertTrue(assignments.isEmpty)
  }

  // MARK: - transferAssignmentsFromServerToDisk

  func test_transferAssignmentsFromServerToDisk_noAssignments() {
    let variant: Experiment.Variant = .init(id: "def", type: .treatment, paywallId: "ghi")
    let localAssignments = Set([
      Assignment(experimentId: "abc", variant: variant, isSentToServer: false)
    ])
    let result = ConfigLogic.transferAssignments(
      fromServer: [],
      toDisk: localAssignments,
      triggers: [.stub()]
    )
    XCTAssertEqual(result, localAssignments)
  }

  func test_transferAssignmentsFromServerToDisk_overwriteConfirmedAssignment() {
    let experimentId = "abc"
    let variantId = "def"

    let serverAssignments: [PostbackAssignment] = [
      PostbackAssignment(
        experimentId: experimentId,
        variantId: variantId
      )
    ]
    let oldVariantOption: VariantOption = .stub()
    let variantOption: VariantOption = .stub()
      .setting(\.id, to: variantId)
    let triggers: Set<Trigger> = [
      .stub()
        .setting(
          \.audiences,
          to: [
            .stub()
              .setting(
                \.experiment,
                to: .stub()
                  .setting(\.id, to: experimentId)
                  .setting(\.variants, to: [variantOption])
              )
          ])
    ]
    let unconfirmedVariant = Experiment.Variant(id: "mno", type: .treatment, paywallId: "pqr")
    let localAssignments = Set([
      Assignment(
        experimentId: experimentId,
        variant: oldVariantOption.toExperimentVariant(),
        isSentToServer: true
      ),
      Assignment(
        experimentId: "jkl",
        variant: unconfirmedVariant,
        isSentToServer: false
      )
    ])

    let assignments = ConfigLogic.transferAssignments(
      fromServer: serverAssignments,
      toDisk: localAssignments,
      triggers: triggers
    )

    XCTAssertEqual(assignments.count, 2, "Should be overriding the assignment by experiment ID, check the equality func")
    XCTAssertEqual(assignments.first(where: { $0.experimentId == experimentId })!.variant, variantOption.toExperimentVariant())
    XCTAssertEqual(assignments.first(where: { $0.experimentId == "jkl" })!.variant, unconfirmedVariant)
  }

  func test_transferAssignmentsFromServerToDisk_multipleAssignments() {
    let experimentId1 = "abc"
    let variantId1 = "def"

    let experimentId2 = "ghi"
    let variantId2 = "klm"

    let assignments: [PostbackAssignment] = [
      PostbackAssignment(
        experimentId: experimentId1,
        variantId: variantId1
      ),
      PostbackAssignment(
        experimentId: experimentId2,
        variantId: variantId2
      ),
    ]
    let unusedVariantOption1: VariantOption = .stub()
      .setting(\.id, to: "unusedOption1")
    let variantOption1: VariantOption = .stub()
      .setting(\.id, to: variantId1)
    let variantOption2: VariantOption = .stub()
      .setting(\.id, to: variantId2)
    let unusedVariantOption2: VariantOption = .stub()
      .setting(\.id, to: "unusedOption2")

    let triggers: Set<Trigger> = [
      .stub()
        .setting(
          \.audiences,
          to: [
            .stub()
              .setting(
                \.experiment,
                to: .stub()
                  .setting(\.id, to: experimentId1)
                  .setting(\.variants, to: [variantOption1, unusedVariantOption1])
              ),
            .stub()
              .setting(
                \.experiment,
                to: .stub()
                  .setting(\.id, to: experimentId2)
                  .setting(\.variants, to: [variantOption2, unusedVariantOption2])
              ),
          ])
    ]

    let unconfirmedVariant = Experiment.Variant(id: "mno", type: .treatment, paywallId: "pqr")
    let localAssignments = Set([
      Assignment(
        experimentId: "jkl",
        variant: unconfirmedVariant,
        isSentToServer: false
      )
    ])

    let result = ConfigLogic.transferAssignments(
      fromServer: assignments,
      toDisk: localAssignments,
      triggers: triggers
    )
    XCTAssertEqual(result.count, 3)
    XCTAssertEqual(result.first(where: { $0.experimentId == experimentId1 })?.variant, variantOption1.toExperimentVariant())
    XCTAssertEqual(result.first(where: { $0.experimentId == experimentId2 })?.variant, variantOption2.toExperimentVariant())
    XCTAssertEqual(result.first(where: { $0.experimentId == "jkl" })?.variant, unconfirmedVariant)
  }

  func test_transferAssignments_noMatchingTrigger() {
    let variant = Experiment.Variant(id: "v1", type: .treatment, paywallId: "p1")
    let local = Set([Assignment(experimentId: "exp1", variant: variant, isSentToServer: false)])

    let serverAssignment = PostbackAssignment(experimentId: "nonexistent", variantId: "v1")
    let triggers: Set<Trigger> = [.stub()] // Does not include experimentId "nonexistent"

    let result = ConfigLogic.transferAssignments(
      fromServer: [serverAssignment],
      toDisk: local,
      triggers: triggers
    )

    XCTAssertEqual(result, local)
  }

  /// Server assignment with no matching trigger is ignored
  func test_transferAssignments_noMatchingVariant() {
    let trigger = Trigger.stub()
      .setting(\.audiences, to: [
        .stub()
          .setting(
            \.experiment,
            to: .stub()
              .setting(\.id, to: "exp1")
              .setting(\.variants, to: [VariantOption.stub().setting(\.id, to: "v2")])
          )]
      )
    let local = Set<Assignment>()
    let serverAssignment = PostbackAssignment(experimentId: "exp1", variantId: "v1")

    let result = ConfigLogic.transferAssignments(
      fromServer: [serverAssignment],
      toDisk: local,
      triggers: [trigger]
    )

    XCTAssertEqual(result, local)
  }

  // MARK: - getStaticPaywall

  func test_getStaticPaywall_noPaywallId() {
    let response = ConfigLogic.getStaticPaywall(
      withId: nil,
      config: .stub(),
      deviceLocale: "en_GB"
    )
    XCTAssertNil(response)
  }

  func test_getStaticPaywall_noConfig() {
    let response = ConfigLogic.getStaticPaywall(
      withId: "abc",
      config: nil,
      deviceLocale: "en_GB"
    )
    XCTAssertNil(response)
  }

  func test_getStaticPaywall_deviceLocaleSpecifiedInConfig() {
    let locale = "en_GB"
    let dependencyContainer = DependencyContainer()
    let response = ConfigLogic.getStaticPaywall(
      withId: "abc",
      config: .stub()
        .setting(\.locales, to: [locale]),
      deviceLocale: locale
    )
    XCTAssertNil(response)
  }

  func test_getStaticPaywall_shortLocaleContainsEn() {
    let paywallId = "abc"
    let locale = "en_GB"
    let config: Config = .stub()
      .setting(\.locales, to: ["de_DE"])
      .setting(
        \.paywalls,
        to: [
          .stub(),
          .stub()
            .setting(\.identifier, to: paywallId),
        ])

    let response = ConfigLogic.getStaticPaywall(
      withId: paywallId,
      config: config,
      deviceLocale: locale
    )

    XCTAssertEqual(response, config.paywalls[1])
  }

  func test_getStaticPaywall_shortLocaleNotContainedInConfig() {
    let paywallId = "abc"
    let locale = "de_DE"
    let config: Config = .stub()
      .setting(\.locales, to: [])
      .setting(
        \.paywalls,
        to: [
          .stub(),
          .stub()
            .setting(\.identifier, to: paywallId),
        ])

    let response = ConfigLogic.getStaticPaywall(
      withId: paywallId,
      config: config,
      deviceLocale: locale
    )

    XCTAssertEqual(response, config.paywalls[1])
  }

  func test_getStaticPaywallResponse_shortLocaleContainedInConfig() {
    let paywallId = "abc"
    let locale = "de_DE"
    let config: Config = .stub()
      .setting(\.locales, to: ["de"])
      .setting(
        \.paywalls,
        to: [
          .stub(),
          .stub()
            .setting(\.identifier, to: paywallId),
        ])

    let response = ConfigLogic.getStaticPaywall(
      withId: paywallId,
      config: config,
      deviceLocale: locale
    )

    XCTAssertNil(response)
  }

  // MARK: - getAllActiveTreatmentPaywallIds
  func test_getAllActiveTreatmentPaywallIds_onlyConfirmedAssignments_treatment_alwaysPreload() async
  {
    let paywallId1 = "abc"
    let experiment1 = "def"

    let triggers: Set<Trigger> = [
      .stub()
        .setting(
          \.audiences,
          to: [
            .stub()
              .setting(
                \.experiment,
                to: .stub()
                  .setting(\.id, to: experiment1)
              )
              .setting(\.preload, to: .init(behavior: .always))
          ])
    ]
    let assignments = Set([
      Assignment(
        experimentId: experiment1,
        variant: .init(id: paywallId1, type: .treatment, paywallId: paywallId1),
        isSentToServer: true
      )
    ])

    let evaluator = ExpressionEvaluatorMock(outcome: .match(audience: .stub()))

    let ids = await ConfigLogic.getAllActiveTreatmentPaywallIds(
      fromTriggers: triggers,
      assignments: assignments,
      expressionEvaluator: evaluator
    )
    XCTAssertEqual(ids, [paywallId1])
  }

  func test_getAllActiveTreatmentPaywallIds_onlyConfirmedAssignments_treatment_neverPreload() async
  {
    let paywallId1 = "abc"
    let experiment1 = "def"

    let triggers: Set<Trigger> = [
      .stub()
        .setting(
          \.audiences,
          to: [
            .stub()
              .setting(
                \.experiment,
                to: .stub()
                  .setting(\.id, to: experiment1)
              )
              .setting(\.preload, to: .init(behavior: .never))
          ])
    ]
    let assignments = Set([
      Assignment(
        experimentId: experiment1,
        variant: .init(id: paywallId1, type: .treatment, paywallId: paywallId1),
        isSentToServer: true
      )
    ])

    let evaluator = ExpressionEvaluatorMock(outcome: .match(audience: .stub()))

    let ids = await ConfigLogic.getAllActiveTreatmentPaywallIds(
      fromTriggers: triggers,
      assignments: assignments,
      expressionEvaluator: evaluator
    )
    XCTAssertTrue(ids.isEmpty)
  }

  func
    test_getAllActiveTreatmentPaywallIds_onlyConfirmedAssignments_treatment_ifTrue_evaluatesFalse()
    async
  {
    let paywallId1 = "abc"
    let experiment1 = "def"

    let triggers: Set<Trigger> = [
      .stub()
        .setting(
          \.audiences,
          to: [
            .stub()
              .setting(
                \.experiment,
                to: .stub()
                  .setting(\.id, to: experiment1)
              )
              .setting(\.preload, to: .init(behavior: .ifTrue))
          ])
    ]

    let assignments = Set([
      Assignment(
        experimentId: experiment1,
        variant: .init(id: paywallId1, type: .treatment, paywallId: paywallId1),
        isSentToServer: true
      )
    ])

    let evaluator = ExpressionEvaluatorMock(outcome: .noMatch(.stub()))

    let ids = await ConfigLogic.getAllActiveTreatmentPaywallIds(
      fromTriggers: triggers,
      assignments: assignments,
      expressionEvaluator: evaluator
    )
    XCTAssertTrue(ids.isEmpty)
  }

  func
    test_getAllActiveTreatmentPaywallIds_onlyConfirmedAssignments_treatment_ifTrue_evaluatesTrue()
    async
  {
    let paywallId1 = "abc"
    let experiment1 = "def"

    let triggers: Set<Trigger> = [
      .stub()
        .setting(
          \.audiences,
          to: [
            .stub()
              .setting(
                \.experiment,
                to: .stub()
                  .setting(\.id, to: experiment1)
              )
              .setting(\.preload, to: .init(behavior: .ifTrue))
          ])
    ]
    let assignments = Set([
      Assignment(
        experimentId: experiment1,
        variant: .init(id: paywallId1, type: .treatment, paywallId: paywallId1),
        isSentToServer: true
      )
    ])

    let evaluator = ExpressionEvaluatorMock(outcome: .match(.stub()))

    
    let ids = await ConfigLogic.getAllActiveTreatmentPaywallIds(
      fromTriggers: triggers,
      assignments: assignments,
      expressionEvaluator: evaluator
    )
    XCTAssertEqual(ids, [paywallId1])
  }

  func
    test_getAllActiveTreatmentPaywallIds_onlyConfirmedAssignments_treatment_multipleTriggerSameGroupId()
    async
  {
    let paywallId1 = "abc"
    let experiment1 = "def"

    let triggers: Set<Trigger> = [
      .stub()
        .setting(
          \.audiences,
          to: [
            .stub()
              .setting(
                \.experiment,
                to: .stub()
                  .setting(\.id, to: experiment1)
              )
          ]),
      .stub()
        .setting(
          \.audiences,
          to: [
            .stub()
              .setting(
                \.experiment,
                to: .stub()
                  .setting(\.id, to: experiment1)
              )
          ]),
    ]
    let assignments = Set([
      Assignment(
        experimentId: experiment1,
        variant: .init(id: paywallId1, type: .treatment, paywallId: paywallId1),
        isSentToServer: true
      )
    ])

    let evaluator = ExpressionEvaluatorMock(outcome: .match(audience: .stub()))

    let ids = await ConfigLogic.getAllActiveTreatmentPaywallIds(
      fromTriggers: triggers,
      assignments: assignments,
      expressionEvaluator: evaluator
    )
    XCTAssertEqual(ids, [paywallId1])
  }

  func test_getAllActiveTreatmentPaywallIds_onlyConfirmedAssignments_holdout() async {
    let experiment1 = "def"

    let triggers: Set<Trigger> = [
      .stub()
        .setting(
          \.audiences,
          to: [
            .stub()
              .setting(
                \.experiment,
                to: .stub()
                  .setting(\.id, to: experiment1)
              )
          ])
    ]
    let assignments = Set([
      Assignment(
        experimentId: experiment1,
        variant: .init(id: "variantId1", type: .holdout, paywallId: nil),
        isSentToServer: true
      )
    ])
    let evaluator = ExpressionEvaluatorMock(outcome: .match(audience: .stub()))

    let ids = await ConfigLogic.getAllActiveTreatmentPaywallIds(
      fromTriggers: triggers,
      assignments: assignments,
      expressionEvaluator: evaluator
    )
    XCTAssertTrue(ids.isEmpty)
  }

  func test_getAllActiveTreatmentPaywallIds_onlyConfirmedAssignments_filterOldOnes() async {
    let paywallId1 = "abc"
    let experiment1 = "def"
    let paywallId2 = "efg"
    let experiment2 = "ghi"

    let triggers: Set<Trigger> = [
      .stub()
        .setting(
          \.audiences,
          to: [
            .stub()
              .setting(
                \.experiment,
                to: .stub()
                  .setting(\.id, to: experiment1)
              )
          ])
    ]

    let assignments = Set([
      Assignment(
        experimentId: experiment1,
        variant: .init(id: "variantId1", type: .treatment, paywallId: paywallId1),
        isSentToServer: true
      ),
      Assignment(
        experimentId: experiment2,
        variant: .init(id: "variantId2", type: .treatment, paywallId: paywallId2),
        isSentToServer: true
      )
    ])

    let evaluator = ExpressionEvaluatorMock(outcome: .match(audience: .stub()))

    let ids = await ConfigLogic.getAllActiveTreatmentPaywallIds(
      fromTriggers: triggers,
      assignments: assignments,
      expressionEvaluator: evaluator
    )
    XCTAssertEqual(ids, [paywallId1])
  }

  func test_getAllActiveTreatmentPaywallIds_confirmedAndUnconfirmedAssignments_filterOldOnes() async
  {
    let paywallId1 = "abc"
    let experiment1 = "def"
    let paywallId2 = "efg"
    let experiment2 = "ghi"
    let paywallId3 = "jik"
    let experiment3 = "klo"

    let triggers: Set<Trigger> = [
      .stub()
        .setting(
          \.audiences,
          to: [
            .stub()
              .setting(
                \.experiment,
                to: .stub()
                  .setting(\.groupId, to: "a")
                  .setting(\.id, to: experiment1)
              )
          ]),
      .stub()
        .setting(
          \.audiences,
          to: [
            .stub()
              .setting(
                \.experiment,
                to: .stub()
                  .setting(\.groupId, to: "b")
                  .setting(\.id, to: experiment3)
              )
          ]),
    ]
    let assignments = Set([
      Assignment(
        experimentId: experiment1,
        variant: .init(id: "variantId1", type: .treatment, paywallId: paywallId1),
        isSentToServer: true
      ),
      Assignment(
        experimentId: experiment2,
        variant: .init(id: "variantId2", type: .treatment, paywallId: paywallId2),
        isSentToServer: true
      ),
      Assignment(
        experimentId: experiment3,
        variant: .init(id: "variantId3", type: .treatment, paywallId: paywallId3),
        isSentToServer: false
      )
    ])

    let evaluator = ExpressionEvaluatorMock(outcome: .match(audience: .stub()))

    let ids = await ConfigLogic.getAllActiveTreatmentPaywallIds(
      fromTriggers: triggers,
      assignments: assignments,
      expressionEvaluator: evaluator
    )
    XCTAssertEqual(ids, [paywallId1, paywallId3])
  }

  // MARK: - getActiveTreatmentPaywallIds
  func test_getActiveTreatmentPaywallIds() {
    let paywallId1 = "abc"
    let experiment1 = "def"
    let experiment2 = "sdf"
    let paywallId2 = "wer"

    let triggers: Set<Trigger> = [
      .stub()
        .setting(
          \.audiences,
          to: [
            .stub()
              .setting(
                \.experiment,
                to: .stub()
                  .setting(\.id, to: experiment1)
              )
          ])
    ]
    let assignments = Set([
      Assignment(
        experimentId: experiment1,
        variant: .init(id: "variantId1", type: .treatment, paywallId: paywallId1),
        isSentToServer: true
      ),
      Assignment(
        experimentId: experiment2,
        variant: .init(id: "variantId2", type: .treatment, paywallId: paywallId2),
        isSentToServer: true
      )
    ])
    let ids = ConfigLogic.getActiveTreatmentPaywallIds(
      forTriggers: triggers,
      assignments: assignments
    )
    XCTAssertEqual(ids, [paywallId1])
  }

  func test_getActiveTreatmentPaywallIds_holdout() {
    let paywallId1 = "abc"
    let experiment1 = "def"
    let experiment2 = "sdf"
    let paywallId2 = "wer"

    let triggers: Set<Trigger> = [
      .stub()
        .setting(
          \.audiences,
          to: [
            .stub()
              .setting(
                \.experiment,
                to: .stub()
                  .setting(\.id, to: experiment1)
              )
          ])
    ]
    let assignments = Set([
      Assignment(
        experimentId: experiment1,
        variant: .init(id: "variantId1", type: .holdout, paywallId: paywallId1),
        isSentToServer: true
      ),
      Assignment(
        experimentId: experiment2,
        variant: .init(id: "variantId2", type: .treatment, paywallId: paywallId2),
        isSentToServer: true
      )
    ])
    let ids = ConfigLogic.getActiveTreatmentPaywallIds(
      forTriggers: triggers,
      assignments: assignments
    )
    XCTAssertTrue(ids.isEmpty)
  }

  func test_getActiveTreatmentPaywallIds_confirmedAndUnconfirmedAssignments() {
    let paywallId1 = "abc"
    let experiment1 = "def"
    let experiment2 = "sdf"
    let paywallId2 = "wer"

    let triggers: Set<Trigger> = [
      .stub()
        .setting(
          \.audiences,
          to: [
            .stub()
              .setting(
                \.experiment,
                to: .stub()
                  .setting(\.id, to: experiment1)
              )
          ])
    ]
    let assignments = Set([
      Assignment(
        experimentId: experiment1,
        variant: .init(id: "variantId1", type: .treatment, paywallId: paywallId1),
        isSentToServer: true
      ),
      Assignment(
        experimentId: experiment2,
        variant: .init(id: "variantId2", type: .treatment, paywallId: paywallId2),
        isSentToServer: false
      )
    ])
    let ids = ConfigLogic.getActiveTreatmentPaywallIds(
      forTriggers: triggers,
      assignments: assignments
    )
    XCTAssertEqual(ids, [paywallId1])
  }

  func test_getActiveTreatmentPaywallIds_confirmedAndUnconfirmedAssignments_removeDuplicateRules() {
    let paywallId1 = "abc"
    let experiment1 = "def"
    let experiment2 = "sdf"
    let paywallId2 = "wer"

    let triggers: Set<Trigger> = [
      .stub()
        .setting(
          \.audiences,
          to: [
            .stub()
              .setting(
                \.experiment,
                to: .stub()
                  .setting(\.groupId, to: "abc")
                  .setting(\.id, to: experiment1)
              )
          ]),
      .stub()
        .setting(
          \.audiences,
          to: [
            .stub()
              .setting(
                \.experiment,
                to: .stub()
                  .setting(\.groupId, to: "abc")
                  .setting(\.id, to: experiment1)
              )
          ]),
    ]
    let assignments = Set([
      Assignment(
        experimentId: experiment1,
        variant: .init(id: "variantId1", type: .treatment, paywallId: paywallId1),
        isSentToServer: true
      ),
      Assignment(
        experimentId: experiment2,
        variant: .init(id: "variantId2", type: .treatment, paywallId: paywallId2),
        isSentToServer: true
      )
    ])
    let ids = ConfigLogic.getActiveTreatmentPaywallIds(
      forTriggers: triggers,
      assignments: assignments
    )
    XCTAssertEqual(ids, [paywallId1])
  }

  func test_getTriggerDictionary() {
    let firstTrigger: Trigger = .stub()
      .setting(\.placementName, to: "abc")

    let secondTrigger: Trigger = .stub()
      .setting(\.placementName, to: "def")

    let triggers: Set<Trigger> = [
      firstTrigger, secondTrigger,
    ]
    let dictionary = ConfigLogic.getTriggersByPlacementName(from: triggers)
    XCTAssertEqual(dictionary["abc"], firstTrigger)
    XCTAssertEqual(dictionary["def"], secondTrigger)
  }
  // MARK: - Filter Triggers

  func test_filterTriggers_noTriggers() {
    let disabled = PreloadingDisabled(
      all: true,
      triggers: ["app_open"]
    )
    let triggers = ConfigLogic.filterTriggers(
      [],
      removing: disabled
    )
    XCTAssertTrue(triggers.isEmpty)
  }

  func test_filterTriggers_disableAll() {
    let disabled = PreloadingDisabled(
      all: true,
      triggers: []
    )
    let triggers: Set<Trigger> = [
      Trigger(placementName: "app_open", audiences: []),
      Trigger(placementName: "campaign_trigger", audiences: [.stub()]),
    ]
    let filteredTriggers = ConfigLogic.filterTriggers(
      triggers,
      removing: disabled
    )
    XCTAssertTrue(filteredTriggers.isEmpty)
  }

  func test_filterTriggers_disableSome() {
    let disabled = PreloadingDisabled(
      all: false,
      triggers: ["app_open"]
    )
    let triggers: Set<Trigger> = [
      Trigger(placementName: "app_open", audiences: []),
      Trigger(placementName: "campaign_trigger", audiences: [.stub()]),
    ]
    let filteredTriggers = ConfigLogic.filterTriggers(
      triggers,
      removing: disabled
    )
    XCTAssertEqual(filteredTriggers.count, 1)
    XCTAssertEqual(filteredTriggers.first!.placementName, "campaign_trigger")
  }

  func test_filterTriggers_disableNone() {
    let disabled = PreloadingDisabled(
      all: false,
      triggers: []
    )
    let triggers: Set<Trigger> = [
      Trigger(placementName: "app_open", audiences: []),
      Trigger(placementName: "campaign_trigger", audiences: [.stub()]),
    ]
    let filteredTriggers = ConfigLogic.filterTriggers(
      triggers,
      removing: disabled
    )
    XCTAssertEqual(filteredTriggers.count, 2)
  }

  // MARK: - getRemovedOrChangedPaywalls

  func test_getRemovedOrChangedPaywallIds_allPaywallsRemoved() {
    let paywall = Paywall.stub()
    let oldConfig = Config.stub()
      .setting(\.paywalls, to: [paywall])
    let newConfig = Config.stub()
      .setting(\.paywalls, to: [])

    let result = ConfigLogic.getRemovedOrChangedPaywallIds(
      oldConfig: oldConfig,
      newConfig: newConfig
    )

    XCTAssertEqual(result, Set([paywall.identifier]))
  }

  func test_getRemovedOrChangedPaywallIds_noPaywallsRemoved() {
    let oldConfig = Config.stub()
    let newConfig = Config.stub()

    let result = ConfigLogic.getRemovedOrChangedPaywallIds(
      oldConfig: oldConfig,
      newConfig: newConfig
    )

    XCTAssertTrue(result.isEmpty)
  }

  func test_getRemovedOrChangedPaywallIds_cacheKeyChanged() {
    let oldPaywall = Paywall.stub()
    let newPaywall = Paywall.stub()
      .setting(\.cacheKey, to: "444")

    let oldConfig = Config.stub()
      .setting(\.paywalls, to: [oldPaywall])
    let newConfig = Config.stub()
      .setting(\.paywalls, to: [newPaywall])

    let result = ConfigLogic.getRemovedOrChangedPaywallIds(
      oldConfig: oldConfig,
      newConfig: newConfig
    )

    XCTAssertEqual(result, Set([oldPaywall.identifier]))
  }

  func test_getRemovedOrChangedPaywallIds_cacheKeyChanged_andOneRemoved() {
    let removedPaywall = Paywall.stub()
      .setting(\.identifier, to: "3368")
    let oldPaywall = Paywall.stub()
    let newPaywall = Paywall.stub()
      .setting(\.cacheKey, to: "444")

    let oldConfig = Config.stub()
      .setting(\.paywalls, to: [removedPaywall, oldPaywall])
    let newConfig = Config.stub()
      .setting(\.paywalls, to: [newPaywall])

    let result = ConfigLogic.getRemovedOrChangedPaywallIds(
      oldConfig: oldConfig,
      newConfig: newConfig
    )

    XCTAssertEqual(result, Set([oldPaywall.identifier, removedPaywall.identifier]))
  }

  // MARK: - extractEntitlements

  func test_extractEntitlements_noEntitlements() {
    let productId = "123"
    let entitlement = Entitlement.stub()
    let config = Config(
      buildId: "poWduJZYQbCA8QbWLrjJC",
      triggers: [.stub()],
      paywalls: [.stub()],
      logLevel: 0,
      locales: [],
      appSessionTimeout: 3_600_000,
      featureFlags: .stub(),
      preloadingDisabled: .stub(),
      attribution: .init(appleSearchAds: .init(enabled: true)),
      products: [
        .init(
          name: "test",
          type: .appStore(.init(id: productId)),
          entitlements: [entitlement]
        )
      ]
    )
    let entitlements = ConfigLogic.extractEntitlements(from: config)

    XCTAssertEqual(entitlements[productId], [entitlement])
  }
}
