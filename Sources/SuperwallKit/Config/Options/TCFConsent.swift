//
//  TCFConsent.swift
//
//
//  Created by Yusuf Tör on 09/10/2026.
//

import Foundation

/// Where the reported ad consent came from, before the `.none` and ATT rules apply.
enum AdConsentSource: String {
  /// The app set ``SuperwallOptions/adConsent`` or ``Superwall/adConsent``.
  case developer
  /// An IAB TCF consent banner stored it in `UserDefaults`.
  case tcf
  /// Nothing set it, so both purposes are granted.
  case `default`
}

/// The ad consent device attributes report, as their string values.
struct ReportedAdConsent: Equatable {
  let adUserData: String
  let adPersonalization: String
  let source: String

  init(adUserData: String, adPersonalization: String, source: String) {
    self.adUserData = adUserData
    self.adPersonalization = adPersonalization
    self.source = source
  }

  /// Reads them back from device attributes.
  init?(attributes: [String: Any]) {
    guard
      let adUserData = attributes["adUserDataConsent"] as? String,
      let adPersonalization = attributes["adPersonalizationConsent"] as? String,
      let source = attributes["adConsentSource"] as? String
    else {
      return nil
    }
    self.init(adUserData: adUserData, adPersonalization: adPersonalization, source: source)
  }
}

/// Reads the ad consent an IAB TCF v2 consent banner stores in `UserDefaults`.
enum TCFConsent {
  static let gdprAppliesKey = "IABTCF_gdprApplies"
  static let purposeConsentsKey = "IABTCF_PurposeConsents"

  /// The banner's consent, or `nil` when EU rules don't apply or there's no answer.
  ///
  /// `adUserData` needs purposes 1 and 7, and `adPersonalization` needs purposes 3
  /// and 4. Only purpose consents are read, not vendor consents.
  static func consent(from defaults: UserDefaults) -> AdConsent? {
    guard
      (defaults.object(forKey: gdprAppliesKey) as? Int) == 1,
      let purposes = defaults.string(forKey: purposeConsentsKey),
      !purposes.isEmpty
    else {
      return nil
    }
    let agreed = Array(purposes)
    func hasConsent(toPurposes numbers: Int...) -> Bool {
      numbers.allSatisfy { $0 <= agreed.count && agreed[$0 - 1] == "1" }
    }
    return AdConsent(
      adUserData: hasConsent(toPurposes: 1, 7) ? .granted : .denied,
      adPersonalization: hasConsent(toPurposes: 3, 4) ? .granted : .denied
    )
  }
}

/// Re-sends device attributes when a consent banner changes its stored answer,
/// for example after the user reopens the banner from the app's settings.
final class TCFConsentObserver {
  private let defaults: UserDefaults
  private let notificationCenter: NotificationCenter
  private let onChange: () async -> Void
  private let lock = NSLock()
  /// The banner's answer last seen, as `adUserData`/`adPersonalization`, or `nil`.
  private var lastSeen: [AdConsentStatus]?
  private var observer: NSObjectProtocol?

  init(
    defaults: UserDefaults = .standard,
    notificationCenter: NotificationCenter = .default,
    onChange: @escaping () async -> Void = {
      await Superwall.shared.republishDeviceAttributesIfAdConsentChanged()
    }
  ) {
    self.defaults = defaults
    self.notificationCenter = notificationCenter
    self.onChange = onChange
    self.lastSeen = Self.snapshot(of: defaults)
    // `didChangeNotification` fires for every write to any defaults in the
    // process, so only a change to the banner's answer goes any further.
    observer = notificationCenter.addObserver(
      forName: UserDefaults.didChangeNotification,
      object: nil,
      queue: nil
    ) { [weak self] _ in
      self?.bannerMayHaveChanged()
    }
  }

  deinit {
    if let observer {
      notificationCenter.removeObserver(observer)
    }
  }

  private static func snapshot(of defaults: UserDefaults) -> [AdConsentStatus]? {
    TCFConsent.consent(from: defaults).map { [$0.adUserData, $0.adPersonalization] }
  }

  private func bannerMayHaveChanged() {
    let current = Self.snapshot(of: defaults)
    lock.lock()
    let didChange = current != lastSeen
    lastSeen = current
    lock.unlock()
    guard didChange else {
      return
    }
    let onChange = onChange
    Task {
      await onChange()
    }
  }
}
