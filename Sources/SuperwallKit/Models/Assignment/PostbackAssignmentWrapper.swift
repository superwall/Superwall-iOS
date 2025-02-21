//
//  PostbackAssignmentWrapper.swift
//  Superwall
//
//  Created by Yusuf Tör on 02/03/2022.
//

import Foundation

struct PostbackAssignmentWrapper: Codable, Equatable {
  var assignments: [PostbackAssignment]

  static func create(from assignment: Assignment) -> PostbackAssignmentWrapper {
    return PostbackAssignmentWrapper(
      assignments: [
        PostbackAssignment(
          experimentId: assignment.experimentId,
          variantId: assignment.variant.id
        )
      ]
    )
  }
}
