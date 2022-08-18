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

  func test_getRulesPerTriggerGroup_noRules() {
    let rules = ConfigLogic.getRulesPerTriggerGroup(from: [
      .stub()
      .setting(\.rules, to: [])
    ])
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

    // When
    let variant = ConfigLogic.assignVariants(
      fromTriggers: [],
      confirmedAssignments: confirmedAssignments
    )

    // Then
    XCTAssertTrue(variant.unconfirmedAssignments.isEmpty)
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
    // When
    let variant = ConfigLogic.assignVariants(
      fromTriggers: [
        .stub()
        .setting(\.rules, to: [])
      ],
      confirmedAssignments: confirmedAssignments
    )

    // Then
    XCTAssertTrue(variant.unconfirmedAssignments.isEmpty)
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
      confirmedAssignments: [:]
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
      confirmedAssignments: [experimentId: variantOption.toVariant()]
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
      confirmedAssignments: [experimentId: oldVariantOption.toVariant()]
    )

    // Then
    XCTAssertEqual(variant.unconfirmedAssignments.count, 1)
    XCTAssertEqual(variant.unconfirmedAssignments[experimentId], newVariantOption.toVariant())
    XCTAssertTrue(variant.confirmedAssignments.isEmpty)
  }

  // MARK: - processAssignmentsFromServer

  func test_processAssignmentsFromServer_noAssignments() {
    let confirmedVariant: Experiment.Variant = .init(id: "def", type: .treatment, paywallId: "ghi")
    let unconfirmedVariant: Experiment.Variant = .init(id: "mno", type: .treatment, paywallId: "pqr")
    let result = ConfigLogic.transferAssignmentsFromServerToDisk(
      assignments: [],
      triggers: [.stub()],
      confirmedAssignments: ["abc": .init(id: "def", type: .treatment, paywallId: "ghi")],
      unconfirmedAssignments: ["jkl": .init(id: "mno", type: .treatment, paywallId: "pqr")]
    )
    XCTAssertEqual(result.confirmedAssignments["abc"], confirmedVariant)
    XCTAssertEqual(result.unconfirmedAssignments["jkl"], unconfirmedVariant)
  }

  func test_processAssignmentsFromServer_overwriteConfirmedAssignment() {
    let experimentId = "abc"
    let variantId = "def"

    let assignments: [Assignment] = [
      Assignment(
        experimentId: experimentId,
        variantId: variantId
      )
    ]
    let oldVariantOption: VariantOption = .stub()
    let variantOption: VariantOption = .stub()
      .setting(\.id, to: variantId)
    let triggers: Set<Trigger> = [
      .stub()
      .setting(\.rules, to: [
        .stub()
        .setting(
          \.experiment,
           to: .stub()
            .setting(\.id, to: experimentId)
            .setting(\.variants, to: [variantOption])
        )
      ])
    ]

    let unconfirmedVariant: Experiment.Variant = .init(id: "mno", type: .treatment, paywallId: "pqr")
    let result = ConfigLogic.transferAssignmentsFromServerToDisk(
      assignments: assignments,
      triggers: triggers,
      confirmedAssignments: [experimentId: oldVariantOption.toVariant()],
      unconfirmedAssignments: ["jkl": .init(id: "mno", type: .treatment, paywallId: "pqr")]
    )

    XCTAssertEqual(result.confirmedAssignments[experimentId], variantOption.toVariant())
    XCTAssertEqual(result.unconfirmedAssignments["jkl"], unconfirmedVariant)
  }

  func test_processAssignmentsFromServer_multipleAssignments() {
    let experimentId1 = "abc"
    let variantId1 = "def"

    let experimentId2 = "ghi"
    let variantId2 = "klm"

    let assignments: [Assignment] = [
      Assignment(
        experimentId: experimentId1,
        variantId: variantId1
      ),
      Assignment(
        experimentId: experimentId2,
        variantId: variantId2
      )
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
      .setting(\.rules, to: [
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
        )
      ])
    ]

    let unconfirmedVariant: Experiment.Variant = .init(id: "mno", type: .treatment, paywallId: "pqr")
    let result = ConfigLogic.transferAssignmentsFromServerToDisk(
      assignments: assignments,
      triggers: triggers,
      confirmedAssignments: [:],
      unconfirmedAssignments: ["jkl": .init(id: "mno", type: .treatment, paywallId: "pqr")]
    )
    XCTAssertEqual(result.confirmedAssignments.count, 2)
    XCTAssertEqual(result.confirmedAssignments[experimentId1], variantOption1.toVariant())
    XCTAssertEqual(result.confirmedAssignments[experimentId2], variantOption2.toVariant())
    XCTAssertEqual(result.unconfirmedAssignments["jkl"], unconfirmedVariant)
  }

  // MARK: - getStaticPaywallResponse

  func test_getStaticPaywallResponse_noPaywallId() {
    let response = ConfigLogic.getStaticPaywallResponse(
      fromPaywallId: nil,
      config: .stub(),
      deviceHelper: .shared
    )
    XCTAssertNil(response)
  }

  func test_getStaticPaywallResponse_noConfig() {
    let response = ConfigLogic.getStaticPaywallResponse(
      fromPaywallId: "abc",
      config: nil,
      deviceHelper: .shared
    )
    XCTAssertNil(response)
  }

  func test_getStaticPaywallResponse_deviceLocaleSpecifiedInConfig() {
    let locale = "en_GB"
    let deviceHelper = DeviceHelperMock()
    deviceHelper.internalLocale = locale

    let response = ConfigLogic.getStaticPaywallResponse(
      fromPaywallId: "abc",
      config: .stub()
        .setting(\.locales, to: [locale]),
      deviceHelper: deviceHelper
    )
    XCTAssertNil(response)
  }

  func test_getStaticPaywallResponse_shortLocaleContainsEn() {
    let paywallId = "abc"
    let deviceHelper = DeviceHelperMock()
    deviceHelper.internalLocale = "en_GB"
    let config: Config = .stub()
      .setting(\.locales, to: ["de_DE"])
      .setting(\.paywallResponses, to: [
        .stub(),
        .stub()
        .setting(\.identifier, to: paywallId)
      ])

    let response = ConfigLogic.getStaticPaywallResponse(
      fromPaywallId: paywallId,
      config: config,
      deviceHelper: deviceHelper
    )

    XCTAssertEqual(response, config.paywallResponses[1])
  }

  func test_getStaticPaywallResponse_shortLocaleNotContainedInConfig() {
    let paywallId = "abc"
    let deviceHelper = DeviceHelperMock()
    deviceHelper.internalLocale = "de_DE"
    let config: Config = .stub()
      .setting(\.locales, to: [])
      .setting(\.paywallResponses, to: [
        .stub(),
        .stub()
        .setting(\.identifier, to: paywallId)
      ])

    let response = ConfigLogic.getStaticPaywallResponse(
      fromPaywallId: paywallId,
      config: config,
      deviceHelper: deviceHelper
    )

    XCTAssertEqual(response, config.paywallResponses[1])
  }

  func test_getStaticPaywallResponse_shortLocaleContainedInConfig() {
    let paywallId = "abc"
    let deviceHelper = DeviceHelperMock()
    deviceHelper.internalLocale = "de_DE"
    let config: Config = .stub()
      .setting(\.locales, to: ["de"])
      .setting(\.paywallResponses, to: [
        .stub(),
        .stub()
        .setting(\.identifier, to: paywallId)
      ])

    let response = ConfigLogic.getStaticPaywallResponse(
      fromPaywallId: paywallId,
      config: config,
      deviceHelper: deviceHelper
    )

    XCTAssertNil(response)
  }

  // MARK: - getAllActiveTreatmentPaywallIds

  func test_getAllActiveTreatmentPaywallIds_hi() {
    
  }
}
