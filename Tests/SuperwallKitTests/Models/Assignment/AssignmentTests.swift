//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 19/02/2025.
//

import Testing
@testable import SuperwallKit

class AssignmentTests {
  @Test("Sets with identical assignments are fully equal")
  func testFullyEqualSets() {
    let variant1 = Experiment.Variant(id: "1", type: .treatment, paywallId: "2")
    let variant2 = Experiment.Variant(id: "2", type: .treatment, paywallId: "3")
    let assignment1 = Assignment(experimentId: "exp1", variant: variant1, isSentToServer: false)
    let assignment2 = Assignment(experimentId: "exp2", variant: variant2, isSentToServer: true)

    let set1: Set<Assignment> = [assignment1, assignment2]
    let set2: Set<Assignment> = [assignment1, assignment2]

    #expect(set1.isFullyEqual(to: set2))
  }

  @Test("Sets with different counts are not fully equal")
  func testDifferentCounts() {
    let variant = Experiment.Variant(id: "1", type: .treatment, paywallId: "2")

    let assignment1 = Assignment(experimentId: "exp1", variant: variant, isSentToServer: false)
    let assignment2 = Assignment(experimentId: "exp2", variant: variant, isSentToServer: true)

    let set1: Set<Assignment> = [assignment1]
    let set2: Set<Assignment> = [assignment1, assignment2]

    #expect(!set1.isFullyEqual(to: set2))
    #expect(!set2.isFullyEqual(to: set1))
  }

  @Test("Assignments with mismatched properties are not fully equal")
  func testMismatchedAssignmentProperties() {
    let variant1 = Experiment.Variant(id: "1", type: .treatment, paywallId: "2")
    let variant2 = Experiment.Variant(id: "2", type: .treatment, paywallId: "3")

    let assignment1 = Assignment(experimentId: "exp1", variant: variant1, isSentToServer: false)
    // Same experimentId as assignment1 but with a different variant.
    let assignment1Modified = Assignment(experimentId: "exp1", variant: variant2, isSentToServer: false)

    let set1: Set<Assignment> = [assignment1]
    let set2: Set<Assignment> = [assignment1Modified]

    #expect(!set1.isFullyEqual(to: set2))
  }

  @Test("Missing corresponding assignment causes full equality check to fail")
  func testMissingAssignment() {
    let variant = Experiment.Variant(id: "1", type: .treatment, paywallId: "2")

    let assignment1 = Assignment(experimentId: "exp1", variant: variant, isSentToServer: false)
    let assignment2 = Assignment(experimentId: "exp2", variant: variant, isSentToServer: true)

    let set1: Set<Assignment> = [assignment1, assignment2]
    let set2: Set<Assignment> = [assignment1]

    #expect(!set1.isFullyEqual(to: set2))
  }
}
