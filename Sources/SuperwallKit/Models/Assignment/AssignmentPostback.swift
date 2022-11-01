//
//  ConfirmableAssignments.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct AssignmentPostback: Codable, Equatable {
  var assignments: [Assignment]

  static func create(from confirmableAssignment: ConfirmableAssignment) -> AssignmentPostback {
    return AssignmentPostback(
      assignments: [
        Assignment(
          experimentId: confirmableAssignment.experimentId,
          variantId: confirmableAssignment.variant.id
        )
      ]
    )
  }
}
