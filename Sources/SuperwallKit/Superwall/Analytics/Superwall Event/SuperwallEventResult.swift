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
  let event: SuperwallEvent

  /// A dictionary of params associated with the event.
  let rawParams: [String: Any]
}
