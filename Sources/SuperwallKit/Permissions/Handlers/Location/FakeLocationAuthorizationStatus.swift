//
//  FakeLocationAuthorizationStatus.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/01/2026.
//

#if canImport(WebKit)
import Foundation

@objc enum FakeLocationAuthorizationStatus: Int {
  case notDetermined = 0
  case restricted
  case denied
  case authorizedAlways
  case authorizedWhenInUse
}

extension FakeLocationAuthorizationStatus: CustomStringConvertible {
  var description: String {
    switch self {
    case .notDetermined: return "notDetermined"
    case .restricted: return "restricted"
    case .denied: return "denied"
    case .authorizedAlways: return "authorizedAlways"
    case .authorizedWhenInUse: return "authorizedWhenInUse"
    }
  }
}
#endif
