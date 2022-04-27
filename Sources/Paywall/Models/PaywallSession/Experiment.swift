//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

extension PaywallSession {
  struct Experiment: Encodable {
    /// The experiment id
    let id: String

    struct Variant: Encodable {
      /// The variant id
      let id: String
      /// Whether the user is assigned to a holdout variant
      let isHoldout: Bool
    }
    /// The variant of the paywall within the experiment
    let variant: Variant
  }
}
