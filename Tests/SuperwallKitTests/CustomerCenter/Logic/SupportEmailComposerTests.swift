//
//  SupportEmailComposerTests.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Testing
import Foundation
@testable import SuperwallKit

@Suite("SupportEmailComposer")
struct SupportEmailComposerTests {
  let diagnostics = SupportEmailDiagnostics(
    userId: "user_1", appVersion: "1.2.3", osVersion: "18.0", deviceModel: "iPhone",
    sdkVersion: "4.17.0", activeEntitlementIds: ["pro", "plus"], isSandbox: true
  )

  @Test("nil or blank email yields nil")
  func nilEmail() {
    #expect(SupportEmailComposer.mailtoURL(email: nil, subject: "s", body: "b", diagnostics: diagnostics) == nil)
    #expect(SupportEmailComposer.mailtoURL(email: "  ", subject: "s", body: "b", diagnostics: diagnostics) == nil)
  }

  @Test("builds a mailto URL with encoded subject and diagnostics body")
  func buildsURL() throws {
    let url = try #require(SupportEmailComposer.mailtoURL(
      email: "help@app.com", subject: "Support Request", body: "Please describe your issue.", diagnostics: diagnostics
    ))
    #expect(url.scheme == "mailto")
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    #expect(components.path == "help@app.com")
    let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    #expect(items["subject"] == "Support Request")
    let body = try #require(items["body"])
    #expect(body.hasPrefix("Please describe your issue."))
    #expect(body.contains("- User ID: user_1"))
    #expect(body.contains("- App Version: 1.2.3"))
    #expect(body.contains("- OS Version: 18.0"))
    #expect(body.contains("- Device: iPhone"))
    #expect(body.contains("- SDK Version: 4.17.0"))
    #expect(body.contains("- Entitlements: pro, plus"))
    #expect(body.contains("- Sandbox: true"))
  }
}
