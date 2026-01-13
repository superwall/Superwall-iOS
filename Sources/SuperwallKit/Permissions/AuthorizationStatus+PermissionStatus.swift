//
//  AuthorizationStatus+PermissionStatus.swift
//  SuperwallKit
//
//  Created by Superwall on 2024.
//

import AppTrackingTransparency
import AVFoundation
import Photos
import UserNotifications

extension UNAuthorizationStatus {
  var toPermissionStatus: PermissionStatus {
    switch self {
    case .authorized, .provisional, .ephemeral:
      return .granted
    case .denied, .notDetermined:
      return .denied
    @unknown default:
      return .unsupported
    }
  }
}


extension PHAuthorizationStatus {
  var toPermissionStatus: PermissionStatus {
    switch self {
    case .authorized,
      .limited:
      return .granted
    case .denied,
      .restricted,
      .notDetermined:
      return .denied
    @unknown default:
      return .unsupported
    }
  }
}

@available(macCatalyst 14.0, *)
extension AVAuthorizationStatus {
  var toPermissionStatus: PermissionStatus {
    switch self {
    case .authorized:
      return .granted
    case .denied,
      .restricted,
      .notDetermined:
      return .denied
    @unknown default:
      return .unsupported
    }
  }
}

@available(iOS 14, macCatalyst 14.0, macOS 11.0, tvOS 14.0, *)
extension ATTrackingManager.AuthorizationStatus {
  var toPermissionStatus: PermissionStatus {
    switch self {
    case .authorized:
      return .granted
    case .denied,
      .restricted,
      .notDetermined:
      return .denied
    @unknown default:
      return .unsupported
    }
  }
}

extension Int {
  var toContactsPermissionStatus: PermissionStatus {
    // CNAuthorizationStatus:
    // 0 notDetermined
    // 1 restricted
    // 2 denied
    // 3 authorized
    // 4 limited (iOS 18+)
    switch self {
    case 3, 4:
      return .granted
    case 0, 1, 2:
      return .denied
    default:
      // Mirrors your @unknown default policy
      return .granted
    }
  }

  var toLocationPermissionStatus: PermissionStatus {
    // CLAuthorizationStatus:
    // 0 notDetermined
    // 1 restricted
    // 2 denied
    // 3 authorizedAlways
    // 4 authorizedWhenInUse
    switch self {
    case 3, 4:
      return .granted
    case 0, 1, 2:
      return .denied
    default:
      return .unsupported
    }
  }

  var toBackgroundLocationPermissionStatus: PermissionStatus {
    // CLAuthorizationStatus:
    // 0 notDetermined
    // 1 restricted
    // 2 denied
    // 3 authorizedAlways
    // 4 authorizedWhenInUse
    switch self {
    case 3:
      return .granted
    case 0, 1, 2, 4:
      return .denied
    default:
      return .unsupported
    }
  }
}
