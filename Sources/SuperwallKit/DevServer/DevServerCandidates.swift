//
//  DevServerCandidates.swift
//  SuperwallKit
//
//  Where dev mode looks for a running `superwall dev` server.
//

import Foundation

enum DevServerCandidates {
  static let defaultPorts = 6100...6104

  /// The bases dev mode tries, in order: an explicit URL wins, otherwise
  /// localhost across the default port range `superwall dev` walks when
  /// its preferred port is taken.
  static func bases(devServerURL: URL?) -> [URL] {
    if let devServerURL = devServerURL {
      return [devServerURL]
    }
    return defaultPorts.compactMap { URL(string: "http://localhost:\($0)") }
  }
}
