//
//  LocationPermissionDelegate.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/01/2026.
//

import Foundation

/// Delegate class to handle location authorization callbacks.
/// Implements both iOS 14+ and iOS 13 delegate methods dynamically.
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
    // Try instance property first (iOS 14+)
    if let status = manager.value(forKey: "authorizationStatus") as? Int {
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
