//
//  File.swift
//  
//
//  Created by Yusuf Tör on 20/04/2022.
//

import Foundation

/// A protocol that defines an event that is trackable.
protocol Trackable {
  var name: String { get }
  var parameters: [String: Any]? { get }
  var canTriggerPaywall: Bool { get }
}

// The default Trackable implementation
extension Trackable {
  var parameters: [String: Any]? {
    return nil
  }

  var canTriggerPaywall: Bool {
    return true
  }
}
