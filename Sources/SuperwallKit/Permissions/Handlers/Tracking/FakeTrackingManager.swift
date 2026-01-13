//
//  FakeTrackingManager.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/01/2026.
//

import Foundation

final class FakeTrackingManager: NSObject {
  /// Class property returning notDetermined
  @objc static var trackingAuthorizationStatus: Int {
    return FakeTrackingAuthorizationStatus.notDetermined.rawValue
  }

  /// Class method for requesting authorization
  @objc static func requestTrackingAuthorization(
    completionHandler: @escaping (Int) -> Void
  ) {
    completionHandler(FakeTrackingAuthorizationStatus.notDetermined.rawValue)
  }
}
