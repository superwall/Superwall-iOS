//
//  File.swift
//  
//
//  Created by Yusuf Tör on 07/11/2022.
//

import Foundation

/// Contains information about the internally tracked superwall placement.
@available(*, deprecated, renamed: "SuperwallEventInfo")
public typealias SuperwallPlacementInfo = SuperwallEventInfo

/// Contains information about the internally tracked superwall event.
@objc(SWKSuperwallEventInfo)
@objcMembers
public final class SuperwallEventInfo: NSObject {
  /// The event that was tracked.
  @available(*, deprecated, renamed: "event")
  public var placement: SuperwallEvent {
    return event
  }

  /// The event that was tracked.
  public let event: SuperwallEvent

  /// Objective-C compatible ``SuperwallEvent``.
  @objc(event)
  public lazy var objcEvent: SuperwallEventObjc = {
    return SuperwallEventObjc(event: event)
  }()

  /// A dictionary of params associated with the event.
  public let params: [String: Any]

  /// Initializes an instance of the the internally tracked superwall event result.
  /// - Parameters:
  ///   - event: The event that was tracked.
  ///   - params: A dictionary of params associated with the placement.
  public init(event: SuperwallEvent, params: [String: Any]) {
    self.event = event
    self.params = params
  }
}
