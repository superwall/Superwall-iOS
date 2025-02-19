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
public final class Assignment: NSObject {
  /// The id of the experiment.
  public let experimentId: Experiment.ID

  /// Information about the experiment variant.
  public let variant: Experiment.Variant

  /// A boolean that indicates whether the assignment has been posted back to the server.
  public var isSentToServer: Bool

  init(
    experimentId: Experiment.ID,
    variant: Experiment.Variant,
    isSentToServer: Bool
  ) {
    self.experimentId = experimentId
    self.variant = variant
    self.isSentToServer = isSentToServer
  }

  public override func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? Assignment else {
      return false
    }
    // Only take into account experimentId so that we can
    // replace the variant assigned to when in a set.
    return self.experimentId == other.experimentId
  }

  // Override hash to compute the hash value using only the experimentId.
  public override var hash: Int {
    return experimentId.hashValue
  }

  func markAsSent() {
    isSentToServer = true
  }
}
