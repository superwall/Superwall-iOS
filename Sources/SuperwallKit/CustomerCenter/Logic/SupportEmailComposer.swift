//
//  SupportEmailComposer.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Foundation

struct SupportEmailDiagnostics: Equatable {
  var userId: String
  var appVersion: String
  var osVersion: String
  var deviceModel: String
  var sdkVersion: String
  var activeEntitlementIds: [String]
  var isSandbox: Bool
}

enum SupportEmailComposer {
  static func mailtoURL(
    email: String?,
    subject: String,
    body: String,
    diagnostics: SupportEmailDiagnostics
  ) -> URL? {
    guard
      let email = email?.trimmingCharacters(in: .whitespacesAndNewlines),
      !email.isEmpty
    else {
      return nil
    }
    let entitlements = diagnostics.activeEntitlementIds.isEmpty
      ? "none"
      : diagnostics.activeEntitlementIds.joined(separator: ", ")
    let fullBody = """
      \(body)

      ---------------------------
      - User ID: \(diagnostics.userId)
      - App Version: \(diagnostics.appVersion)
      - OS Version: \(diagnostics.osVersion)
      - Device: \(diagnostics.deviceModel)
      - SDK Version: \(diagnostics.sdkVersion)
      - Entitlements: \(entitlements)
      - Sandbox: \(diagnostics.isSandbox)
      """
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = email
    components.queryItems = [
      URLQueryItem(name: "subject", value: subject),
      URLQueryItem(name: "body", value: fullBody)
    ]
    return components.url
  }
}
