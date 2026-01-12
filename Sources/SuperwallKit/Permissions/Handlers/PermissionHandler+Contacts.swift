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

  @MainActor
  func requestContactsPermission() async -> PermissionStatus {
    guard hasPlistKey(PlistKey.contacts) else {
      await showMissingPlistKeyAlert(for: PlistKey.contacts, permissionName: "Contacts")
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
