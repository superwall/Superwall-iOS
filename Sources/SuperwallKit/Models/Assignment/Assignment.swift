//
//  File.swift
//  
//
//  Created by Yusuf Tör on 09/09/2024.
//

import Foundation

/// An assignment for a paywall or holdout.
public typealias ConfirmedAssignment = Assignment

/// An assignment to a paywall or holdout variant for a given experiment.
@objc(SWKConfirmedAssignment)
@objcMembers
public final class Assignment: NSObject, Codable {
  /// The id of the experiment.
  public let experimentId: Experiment.ID

  /// Information about the experiment variant.
  public let variant: Experiment.Variant

  /// A boolean that indicates whether the assignment has been posted back to the server.
  public private(set) var isSentToServer: Bool

  init(
    experimentId: Experiment.ID,
    variant: Experiment.Variant,
    isSentToServer: Bool
  ) {
    self.experimentId = experimentId
    self.variant = variant
    self.isSentToServer = isSentToServer
  }

  // MARK: - Codable

  // Define the keys used for encoding and decoding.
  enum CodingKeys: String, CodingKey {
    case experimentId
    case variant
    case isSentToServer
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    // Assuming experimentId and variant can be represented as Strings.
    try container.encode(experimentId, forKey: .experimentId)
    try container.encode(variant, forKey: .variant)
    try container.encode(isSentToServer, forKey: .isSentToServer)
  }

  public required convenience init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let experimentId = try container.decode(String.self, forKey: .experimentId)
    let variant = try container.decode(Experiment.Variant.self, forKey: .variant)
    let isSentToServer = try container.decode(Bool.self, forKey: .isSentToServer)
    self.init(
      experimentId: experimentId,
      variant: variant,
      isSentToServer: isSentToServer
    )
  }
  public func isFullyEqual(to other: Assignment) -> Bool {
    return self.experimentId == other.experimentId &&
      self.variant == other.variant &&
      self.isSentToServer == other.isSentToServer
  }

  public override func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? Assignment else {
      return false
    }
    // Only check the experiment ID so we can update the variants of a set.
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

// MARK: - Fully Equal
extension Set where Element == Assignment {
  /// Compares two sets for full equality, considering all properties of each Assignment.
  ///
  /// The default equality check of two Assignments only checks the experiment ID.
  /// Use this function if you need a full equality check.
  func isFullyEqual(to other: Set<Assignment>) -> Bool {
    // First check that both sets have the same count.
    guard count == other.count else {
      return false
    }

    // For each assignment in self, find the corresponding assignment in other and check full equality.
    for assignment in self {
      // Look up an assignment in the other set with the same experimentId.
      if let otherAssignment = other.first(where: { $0.experimentId == assignment.experimentId }) {
        if !assignment.isFullyEqual(to: otherAssignment) {
          return false
        }
      } else {
        return false
      }
    }

    return true
  }
}
