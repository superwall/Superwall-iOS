//
//  FakeTrackingAuthorizationStatus.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/01/2026.
//

import Foundation

/// Mirrors ATTrackingManager.AuthorizationStatus raw values
@objc enum FakeTrackingAuthorizationStatus: Int {
  case notDetermined = 0
  case restricted
  case denied
  case authorized
}

extension FakeTrackingAuthorizationStatus: CustomStringConvertible {
  var description: String {
    switch self {
    case .notDetermined: return "notDetermined"
    case .restricted: return "restricted"
    case .denied: return "denied"
    case .authorized: return "authorized"
    }
  }
}
