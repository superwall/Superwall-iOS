//
//  File.swift
//  
//
//  Created by Yusuf Tör on 09/09/2024.
//

import Foundation

/// A confirmed assignment.
@objc(SWKConfirmedAssignment)
@objcMembers
public final class ConfirmedAssignment: NSObject {
  /// The id of the experiment.
  public let experimentId: Experiment.ID

  /// Information about the experiment variant.
  public let variant: Experiment.Variant

  init(
    experimentId: Experiment.ID,
    variant: Experiment.Variant
  ) {
    self.experimentId = experimentId
    self.variant = variant
  }
}
