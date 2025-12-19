//
//  LocationPermissionDelegate.swift
//  SuperwallKit
//
//  Created by Superwall on 2024.
//

import CoreLocation

extension CLLocationManager {
  var currentAuthorizationStatus: CLAuthorizationStatus {
    if #available(iOS 14.0, *) {
      return authorizationStatus
    } else {
      return CLLocationManager.authorizationStatus()
    }
  }
}

final class LocationPermissionDelegate: NSObject, CLLocationManagerDelegate {
  private let completion: (CLAuthorizationStatus) -> Void
  private var hasCompleted = false

  init(completion: @escaping (CLAuthorizationStatus) -> Void) {
    self.completion = completion
    super.init()
  }

  // iOS 14+
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    completeIfDetermined(manager.currentAuthorizationStatus)
  }

  // iOS 13 and earlier
  func locationManager(
    _ manager: CLLocationManager,
    didChangeAuthorization status: CLAuthorizationStatus
  ) {
    completeIfDetermined(status)
  }

  private func completeIfDetermined(_ status: CLAuthorizationStatus) {
    if status == .notDetermined {
      return
    }
    if hasCompleted {
      return
    }
    hasCompleted = true
    completion(status)
  }
}
