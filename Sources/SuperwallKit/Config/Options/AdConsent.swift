//
//  AdConsent.swift
//
//
//  Created by Yusuf Tör on 08/10/2026.
//

import Foundation

/// Whether a user has granted or denied consent for an advertising purpose.
@objc(SWKConsentStatus)
public enum ConsentStatus: Int, CustomStringConvertible, Sendable {
  /// The user has granted consent. This is the default.
  case granted = 0

  /// The user has denied consent.
  case denied = 1

  public var description: String {
    switch self {
    case .granted: return "granted"
    case .denied: return "denied"
    }
  }
}

/// A user's consent for how their data is used for advertising.
///
/// Superwall passes this on to ad networks, such as Google Ads, when it reports
/// conversions for your app. Both values default to ``ConsentStatus/granted``.
///
/// It's immutable: to change consent, assign a new `AdConsent`.
@objc(SWKAdConsent)
@objcMembers
public final class AdConsent: NSObject {
  /// Consent to send the user's data to ad networks for advertising.
  public let adUserData: ConsentStatus

  /// Consent to use the user's data for personalized advertising.
  public let adPersonalization: ConsentStatus

  public init(
    adUserData: ConsentStatus = .granted,
    adPersonalization: ConsentStatus = .granted
  ) {
    self.adUserData = adUserData
    self.adPersonalization = adPersonalization
    super.init()
  }

  public override convenience init() {
    self.init(adUserData: .granted, adPersonalization: .granted)
  }

  /// The consent to report, which is denied for both purposes while
  /// `eventTrackingBehavior` is ``EventTrackingBehavior/none``.
  func reported(for eventTrackingBehavior: EventTrackingBehavior) -> AdConsent {
    if eventTrackingBehavior == .none {
      return AdConsent(adUserData: .denied, adPersonalization: .denied)
    }
    return self
  }
}
