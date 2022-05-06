//
//  File.swift
//  
//
//  Created by Yusuf Tör on 28/04/2022.
//

import Foundation

extension TriggerSession.Trigger {
  struct Experiment: Encodable {
    /// The ID of the experiment in the database.
    var id: String

    /// The database ID of the group the trigger is in
    let groupId: String

    struct Variant: Encodable {
      /// The variant id
      let id: String

      enum VariantType: String, Encodable {
        case holdout = "HOLDOUT"
        case treatment = "TREATMENT"
      }
      /// Whether the user is assigned to a holdout variant
      let type: VariantType
    }
    /// The variant of the paywall within the experiment.
    let variant: Variant

    enum CodingKeys: String, CodingKey {
      case id = "experiment_id"
      case groupId = "trigger_experiment_group_id"
      case variantId = "variant_id"
      case variantType = "variant_type"
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(id, forKey: .id)
      try container.encode(groupId, forKey: .groupId)
      try container.encode(variant.id, forKey: .variantId)
      try container.encode(variant.type, forKey: .variantType)
    }
  }
}
