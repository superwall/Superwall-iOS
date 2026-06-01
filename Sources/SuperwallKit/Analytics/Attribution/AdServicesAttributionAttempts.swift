//
//  AdServicesAttributionAttempts.swift
//  SuperwallKit
//

import Foundation

struct AdServicesAttributionAttempts: Codable, Equatable {
  /// Total attempts that have completed (either at Apple's SDK call or the
  /// backend post).
  var count: Int
  /// When we first tried for this install. Used to bound how long we keep
  /// retrying — Apple's attribution data is only useful within ~24h of install.
  var firstAttemptDate: Date
  var lastAttemptDate: Date
}
