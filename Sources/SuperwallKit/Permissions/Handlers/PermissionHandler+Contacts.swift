//
//  PermissionHandler+Contacts.swift
//  SuperwallKit
//
//  Created by Superwall on 2024.
//

import Contacts

extension PermissionHandler {
  func checkContactsPermission() -> PermissionStatus {
    return CNContactStore.authorizationStatus(for: .contacts).toPermissionStatus
  }

  func requestContactsPermission() async -> PermissionStatus {
    guard hasPlistKey(PlistKey.contacts) else {
      Logger.debug(
        logLevel: .error,
        scope: .paywallViewController,
        message: "Missing \(PlistKey.contacts) in Info.plist. Cannot request contacts permission."
      )
      return .unsupported
    }

    let currentStatus = checkContactsPermission()
    if currentStatus == .granted {
      return .granted
    }

    let store = CNContactStore()
    do {
      let granted = try await store.requestAccess(for: .contacts)
      return granted ? .granted : .denied
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .paywallViewController,
        message: "Error requesting contacts permission",
        error: error
      )
      return .denied
    }
  }
}
