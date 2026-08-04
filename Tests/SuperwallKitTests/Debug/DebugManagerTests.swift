//
//  DebugManagerTests.swift
//  SuperwallKit
//
//  Created by Konrad Roj on 04/08/2026.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

struct DebugManagerTests {
  @Test func outcomeForDeepLink_notADebugLink() {
    let url = URL(string: "myapp://?paywall_id=123")!

    let outcome = DebugManager.outcomeForDeepLink(url: url)

    #expect(outcome == nil)
  }

  @Test func outcomeForDeepLink_missingToken() {
    let url = URL(string: "myapp://?superwall_debug=true&paywall_id=123")!

    let outcome = DebugManager.outcomeForDeepLink(url: url)

    #expect(outcome == nil)
  }

  @Test func outcomeForDeepLink_requiresDebugFlag() {
    let url = URL(string: "myapp://?superwall_debug=false&token=abc")!

    let outcome = DebugManager.outcomeForDeepLink(url: url)

    #expect(outcome == nil)
  }

  @Test func outcomeForDeepLink_minimalValidLink() {
    let url = URL(string: "myapp://?superwall_debug=true&token=abc")!

    let outcome = DebugManager.outcomeForDeepLink(url: url)

    #expect(outcome?.debugKey == "abc")
    #expect(outcome?.paywallId == nil)
    #expect(outcome?.overrides.isEmpty == true)
  }

  @Test func outcomeForDeepLink_carriesOverrides() {
    let url = URL(string: "myapp://?superwall_debug=true&token=abc&paywall_id=123&trial_state=ineligible&appearance=dark&locale=de&present=true")!

    let outcome = DebugManager.outcomeForDeepLink(url: url)

    #expect(outcome?.debugKey == "abc")
    #expect(outcome?.paywallId == "123")
    #expect(outcome?.overrides.freeTrialOverride == false)
    #expect(outcome?.overrides.appearance == .dark)
    #expect(outcome?.overrides.localeIdentifier == "de")
    #expect(outcome?.overrides.shouldPresent == true)
  }
}
