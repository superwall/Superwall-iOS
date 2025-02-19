//
//  ConfirmableAssignments.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct AssignmentPostback: Codable, Equatable {
  var assignments: [PostbackAssignment]

  static func create(from confirmedAssignment: Assignment) -> AssignmentPostback {
    return AssignmentPostback(
      assignments: [
        PostbackAssignment(
          experimentId: confirmedAssignment.experimentId,
          variantId: confirmedAssignment.variant.id
        )
      ]
    )
  }
}
