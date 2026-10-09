//
//  AdConsent.swift
//
//
//  Created by Yusuf Tör on 08/10/2026.
//

import Foundation

/// Whether a user has granted or denied consent for an advertising purpose.
@objc(SWKConsentStatus)
public enum AdConsentStatus: Int, CustomStringConvertible, Sendable {
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
/// Superwall passes this on with the conversions it uploads to Google Ads and Meta.
/// Both values default to ``AdConsentStatus/granted``.
///
/// It's immutable: to change consent, assign a new `AdConsent`.
@objc(SWKAdConsent)
@objcMembers
public final class AdConsent: NSObject {
  /// Consent to send user data to ad networks for advertising.
  public let adUserData: AdConsentStatus

  /// Consent for them to use that data for personalized advertising.
  public let adPersonalization: AdConsentStatus

  public init(
    adUserData: AdConsentStatus = .granted,
    adPersonalization: AdConsentStatus = .granted
  ) {
    self.adUserData = adUserData
    self.adPersonalization = adPersonalization
    super.init()
  }

  public override convenience init() {
    self.init(adUserData: .granted, adPersonalization: .granted)
  }

  /// The consent to report. Both purposes are denied while `eventTrackingBehavior`
  /// is ``EventTrackingBehavior/none``, and personalization is denied when the user
  /// hasn't allowed tracking (`attStatus` is restricted or denied). An undetermined
  /// or missing ATT status leaves the values in place. Pass `nil` for consent the app
  /// set itself, which the ATT rule doesn't override.
  func reported(
    for eventTrackingBehavior: EventTrackingBehavior,
    attStatus: Int?
  ) -> AdConsent {
    if eventTrackingBehavior == .none {
      return AdConsent(adUserData: .denied, adPersonalization: .denied)
    }
    switch attStatus.flatMap(FakeTrackingAuthorizationStatus.init(rawValue:)) {
    case .restricted, .denied:
      return AdConsent(adUserData: adUserData, adPersonalization: .denied)
    case .notDetermined, .authorized, nil:
      return self
    }
  }
}
