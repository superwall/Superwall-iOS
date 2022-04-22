//
//  File.swift
//  
//
//  Created by Yusuf Tör on 20/04/2022.
//

import Foundation

/// A protocol that defines an event that is trackable.
protocol Trackable {
  var rawName: String { get }
  var superwallParameters: [String: Any]? { get }
  var canTriggerPaywall: Bool { get }
}

// The default Trackable implementation
extension Trackable {
  var superwallParameters: [String: Any]? {
    return nil
  }

  var canTriggerPaywall: Bool {
    return true
  }
}
