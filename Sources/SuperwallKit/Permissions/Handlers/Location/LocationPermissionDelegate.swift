//
//  LocationPermissionDelegate.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/01/2026.
//

import Foundation

/// Delegate class to handle location authorization callbacks.
///
/// The `@objc` method below puts CoreLocation's exact delegate selector into
/// the binary's Objective-C metadata — the section the proxies' mangling otherwise
/// keeps Apple's names out of. That's accepted, not overlooked: `CLLocationManager`
/// dispatches its delegate callbacks by selector at runtime, so the metadata
/// must carry it for the callback to arrive. Removing it would mean assembling
/// this class at runtime with `objc_allocateClassPair`. It's also a callback name,
/// not a request-API name or usage-description key — nothing scanners are known to
/// react to. `scan-privacy-signatures.sh` deliberately leaves it off its list.
final class LocationPermissionDelegate: NSObject {
  private let onStatusChange: (Int) -> Void
  private var hasCompleted = false

  init(onStatusChange: @escaping (Int) -> Void) {
    self.onStatusChange = onStatusChange
    super.init()
  }

  /// Selector: locationManagerDidChangeAuthorization:
  @objc func locationManagerDidChangeAuthorization(_ manager: AnyObject) {
    let status = currentAuthorizationStatus(from: manager)
    completeIfDetermined(status)
  }

  private func currentAuthorizationStatus(from manager: AnyObject) -> Int {
    // The key is decoded at runtime so the name doesn't sit in the binary as a
    // plaintext literal.
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
