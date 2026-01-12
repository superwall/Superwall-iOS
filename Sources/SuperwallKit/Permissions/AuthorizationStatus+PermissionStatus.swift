//
//  AuthorizationStatus+PermissionStatus.swift
//  SuperwallKit
//
//  Created by Superwall on 2024.
//

import AVFoundation
import Contacts
import CoreLocation
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

extension CLAuthorizationStatus {
  var toPermissionStatus: PermissionStatus {
    switch self {
    case .authorizedWhenInUse, .authorizedAlways:
      return .granted
    case .denied, .restricted, .notDetermined:
      return .denied
    @unknown default:
      return .unsupported
    }
  }

  var toBackgroundPermissionStatus: PermissionStatus {
    switch self {
    case .authorizedAlways:
      return .granted
    case .authorizedWhenInUse, .denied, .restricted, .notDetermined:
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

extension CNAuthorizationStatus {
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
      // Handles .limited on iOS 18+ and future cases
      return .granted
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
