//
//  FakeLocationManager.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/01/2026.
//

import Foundation

final class FakeLocationManager: NSObject {
  weak var delegate: AnyObject?

  // Instance property (iOS 14+)
  @objc var authorizationStatus: Int {
    return FakeLocationAuthorizationStatus.notDetermined.rawValue
  }

  @objc func requestWhenInUseAuthorization() {
    // No-op in fake implementation
  }

  @objc func requestAlwaysAuthorization() {
    // No-op in fake implementation
  }
}
