//
//  PermissionsHandler+Contacts.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 13/01/2026.
//

extension PermissionHandler {
  func checkContactsPermission() -> PermissionStatus {
    let proxy = ContactStoreProxy()
    let raw = proxy.authorizationStatus()
    guard raw >= 0 else {
      return .unsupported
    }
    return raw.toContactsPermissionStatus
  }

  @MainActor
  func requestContactsPermission() async -> PermissionStatus {
    guard hasPlistKey(PlistKey.contacts) else {
      await showMissingPlistKeyAlert(for: PlistKey.contacts, permissionName: "Contacts")
      return .unsupported
    }

    if checkContactsPermission() == .granted {
      return .granted
    }

    do {
      let proxy = ContactStoreProxy()
      let granted = try await proxy.requestAccess()
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
