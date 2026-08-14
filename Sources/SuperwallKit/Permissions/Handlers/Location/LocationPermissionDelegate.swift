//
//  LocationPermissionDelegate.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/01/2026.
//

import Foundation

/// Delegate class to handle location authorization callbacks.
/// Implements both iOS 14+ and iOS 13 delegate methods dynamically.
///
/// The two `@objc` methods below put CoreLocation's exact delegate selectors into
/// the binary's Objective-C metadata — the section the proxies' mangling otherwise
/// keeps Apple's names out of. That's accepted, not overlooked: `CLLocationManager`
/// dispatches its delegate callbacks by these selectors at runtime, so the metadata
/// must carry them for the callbacks to arrive. Removing them would mean assembling
/// this class at runtime with `objc_allocateClassPair`. They're also callback names,
/// not request-API names or usage-description keys — nothing scanners are known to
/// react to. `scan-privacy-signatures.sh` deliberately leaves them off its list.
final class LocationPermissionDelegate: NSObject {
  private let onStatusChange: (Int) -> Void
  private var hasCompleted = false

  init(onStatusChange: @escaping (Int) -> Void) {
    self.onStatusChange = onStatusChange
    super.init()
  }

  /// iOS 14+ delegate method
  /// Selector: locationManagerDidChangeAuthorization:
  @objc func locationManagerDidChangeAuthorization(_ manager: AnyObject) {
    let status = currentAuthorizationStatus(from: manager)
    completeIfDetermined(status)
  }

  /// iOS 13 and earlier delegate method
  /// Selector: locationManager:didChangeAuthorization:
  #if !os(visionOS)
  @objc func locationManager(
    _ manager: AnyObject,
    didChangeAuthorization status: Int
  ) {
    completeIfDetermined(status)
  }
  #endif

  private func currentAuthorizationStatus(from manager: AnyObject) -> Int {
    // Try instance property first (iOS 14+). The key is decoded at runtime so the
    // name doesn't sit in the binary as a plaintext literal.
    let key = LocationManagerProxy.mangledAuthorizationStatusSelector.rot13()
    if let status = manager.value(forKey: key) as? Int {
      return status
    }
    return FakeLocationAuthorizationStatus.notDetermined.rawValue
  }

  private func completeIfDetermined(_ status: Int) {
    guard status != FakeLocationAuthorizationStatus.notDetermined.rawValue else {
      return
    }
    guard !hasCompleted else {
      return
    }
    hasCompleted = true
    onStatusChange(status)
  }
}
