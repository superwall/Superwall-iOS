//
//  PrivateSuperwallEvent.swift
//  SuperwallKit
//
//  Created by Jake Mor on 23/10/2026.
//

import Foundation

/// An event the SDK sends to Superwall only.
///
/// Unlike a ``TrackableSuperwallEvent``, it has no public ``SuperwallEvent`` case,
/// never reaches `SuperwallDelegate.handleSuperwallEvent(withInfo:)` and can't
/// trigger a paywall. Apps often forward every delegate event to their own
/// analytics, so anything that's only useful to Superwall goes here.
protocol TrackablePrivateEvent: Trackable {}

extension TrackablePrivateEvent {
  var canImplicitlyTriggerPaywall: Bool {
    return false
  }
}

enum PrivateSuperwallEvent {
  /// The third-party SDKs linked into the app, sent on app open when they've
  /// changed. See ``SDKEnvironmentInfo``.
  struct SDKEnvironment: TrackablePrivateEvent {
    let rawName = "sdk_environment"
    let info: SDKEnvironmentInfo
    var audienceFilterParams: [String: Any] = [:]

    func getSuperwallParameters() async -> [String: Any] {
      return info.toDictionary()
    }
  }
}
