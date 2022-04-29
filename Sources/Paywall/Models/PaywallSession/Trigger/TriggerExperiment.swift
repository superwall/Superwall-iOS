//
//  File.swift
//  
//
//  Created by Yusuf Tör on 28/04/2022.
//

import Foundation

extension PaywallSession.Trigger {
  struct Experiment: Encodable {
    /// The ID of the experiment in the database.
    let id: String

    /// The expression of the experiment, e.g. `device.os == test`
    let expression: String

    /// The database ID of the group the trigger is in
    let groupId: String

    struct Variant: Encodable {
      /// The variant id
      let id: String
      /// Whether the user is assigned to a holdout variant
      let isHoldout: Bool
    }
    /// The variant of the paywall within the experiment.
    let variant: Variant

    enum CodingKeys: String, CodingKey {
      case id = "experiment_id"
      case expression = "trigger_experiment_expression"
      case groupId = "trigger_experiment_group_id"
      case variantId = "variant_id"
      case isHoldout = "is_holdout"
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(id, forKey: .id)
      try container.encode(expression, forKey: .expression)
      try container.encode(groupId, forKey: .groupId)
      try container.encode(variant.id, forKey: .variantId)
      try container.encode(variant.isHoldout, forKey: .isHoldout)
    }
  }
}
