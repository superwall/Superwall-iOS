//
//  File.swift
//  
//
//  Created by Yusuf Tör on 07/11/2022.
//

import Foundation

/// The internally tracked superwall event result.
public struct SuperwallEventResult {
  /// The event that was tracked.
  public let event: SuperwallEvent

  /// A dictionary of params associated with the event.
  public let params: [String: Any]
}
