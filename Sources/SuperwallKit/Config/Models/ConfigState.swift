//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/06/2023.
//

import Foundation

enum ConfigState: Equatable {
  static func == (lhs: ConfigState, rhs: ConfigState) -> Bool {
    switch (lhs, rhs) {
    case (.failed, .failed),
      (.retrieving, .retrieving),
      (.retrying, .retrying):
      return true
    case let (.retrieved(config1), .retrieved(config2)):
      return config1.requestId == config2.requestId
    default:
      return false
    }
  }

  case retrieving
  case retrying
  case retrieved(Config)
  /// The config couldn't be fetched. `configState` sends this, then completes
  /// with the error.
  case failed(Error)

  /// Why the config couldn't be fetched, if it couldn't.
  var failure: Error? {
    if case .failed(let error) = self {
      return error
    }
    return nil
  }

  func getConfig() -> Config? {
    switch self {
    case .retrieved(let config):
      return config
    default:
      return nil
    }
  }
}
