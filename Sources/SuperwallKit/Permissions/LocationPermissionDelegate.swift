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

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    completeIfDetermined(manager.currentAuthorizationStatus)
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
