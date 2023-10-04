//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/07/2022.
//

import Foundation

/// An experiment without a confirmed variant assignment.
struct RawExperiment: Decodable, Hashable {
  /// The ID of the experiment
  var id: String

  /// The campaign ID.
  var groupId: String

  /// The variants associated with the experiment.
  var variants: [VariantOption]
}

extension RawExperiment: Stubbable {
  static func stub() -> RawExperiment {
    return RawExperiment(
      id: "abc",
      groupId: "def",
      variants: [.stub()]
    )
  }
}
