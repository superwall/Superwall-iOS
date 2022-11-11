//
//  File.swift
//  
//
//  Created by Yusuf Tör on 07/11/2022.
//

import Foundation

/// The internally tracked superwall event result.
@objc(SWKSuperwallEventResult)
@objcMembers
public class SuperwallEventResult: NSObject {
  /// The event that was tracked.
  public let event: SuperwallEvent

  /// Objective-C compatible ``SuperwallEvent``.
  @available(swift, obsoleted: 1.0)
  @objc(event)
  public lazy var eventObjc: SuperwallEventObjc = {
    return SuperwallEventObjc(event: event)
  }()

  /// A dictionary of params associated with the event.
  public let params: [String: Any]

  /// Initializes an instance of the the internally tracked superwall event result.
  /// - Parameters:
  ///   - event: The event that was tracked.
  ///   - params: A dictionary of params associated with the event.
  public init(event: SuperwallEvent, params: [String: Any]) {
    self.event = event
    self.params = params
  }
}
