//
//  PermissionHandler+Contacts.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/01/2026.
//

import Foundation

@objc enum FakeContactsAuthorizationStatus: Int {
  case notDetermined = 0
  case restricted
  case denied
  case authorized
}

extension FakeContactsAuthorizationStatus: CustomStringConvertible {
  var description: String {
    switch self {
    case .notDetermined: return "notDetermined"
    case .restricted: return "restricted"
    case .denied: return "denied"
    case .authorized: return "authorized"
    }
  }
}
