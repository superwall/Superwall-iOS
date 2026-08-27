//
//  DebugPaywallOverridesTests.swift
//  SuperwallKit
//
//  Created by Konrad Roj on 04/08/2026.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

struct DebugPaywallOverridesTests {
  @Test func parse_noOverrides_isEmpty() {
    let url = URL(string: "myapp://?superwall_debug=true&token=abc&paywall_id=123")!

    let overrides = DebugPaywallOverrides(url: url)

    #expect(overrides.isEmpty)
    #expect(overrides.freeTrialOverride == nil)
    #expect(overrides.appearance == nil)
    #expect(overrides.localeIdentifier == nil)
    #expect(overrides.shouldPresent == false)
  }

  @Test func parse_trialState_eligible() {
    let url = URL(string: "myapp://?trial_state=eligible")!

    let overrides = DebugPaywallOverrides(url: url)

    #expect(overrides.freeTrialOverride == true)
  }

  @Test func parse_trialState_ineligible() {
    let url = URL(string: "myapp://?trial_state=ineligible")!

    let overrides = DebugPaywallOverrides(url: url)

    #expect(overrides.freeTrialOverride == false)
  }

  @Test func parse_trialState_caseInsensitive() {
    let url = URL(string: "myapp://?trial_state=ELIGIBLE")!

    let overrides = DebugPaywallOverrides(url: url)

    #expect(overrides.freeTrialOverride == true)
  }

  @Test func parse_trialState_unknownIsIgnored() {
    let url = URL(string: "myapp://?trial_state=maybe")!

    let overrides = DebugPaywallOverrides(url: url)

    #expect(overrides.freeTrialOverride == nil)
  }

  @Test func parse_appearance_light() {
    let url = URL(string: "myapp://?appearance=light")!

    let overrides = DebugPaywallOverrides(url: url)

    #expect(overrides.appearance == .light)
    #expect(overrides.appearance?.interfaceStyle == .light)
  }

  @Test func parse_appearance_dark() {
    let url = URL(string: "myapp://?appearance=dark")!

    let overrides = DebugPaywallOverrides(url: url)

    #expect(overrides.appearance == .dark)
    #expect(overrides.appearance?.interfaceStyle == .dark)
  }

  @Test func parse_appearance_systemClearsInterfaceStyle() {
    let url = URL(string: "myapp://?appearance=system")!

    let overrides = DebugPaywallOverrides(url: url)

    #expect(overrides.appearance == .system)
    #expect(overrides.appearance?.interfaceStyle == nil)
    #expect(overrides.isEmpty == false)
  }

  @Test func parse_appearance_unknownIsIgnored() {
    let url = URL(string: "myapp://?appearance=sepia")!

    let overrides = DebugPaywallOverrides(url: url)

    #expect(overrides.appearance == nil)
  }

  @Test func parse_locale() {
    let url = URL(string: "myapp://?locale=de")!

    let overrides = DebugPaywallOverrides(url: url)

    #expect(overrides.localeIdentifier == "de")
  }

  @Test func parse_locale_emptyIsIgnored() {
    let url = URL(string: "myapp://?locale=")!

    let overrides = DebugPaywallOverrides(url: url)

    #expect(overrides.localeIdentifier == nil)
  }

  @Test func parse_present_true() {
    let url = URL(string: "myapp://?present=true")!

    let overrides = DebugPaywallOverrides(url: url)

    #expect(overrides.shouldPresent == true)
  }

  @Test func parse_present_false() {
    let url = URL(string: "myapp://?present=false")!

    let overrides = DebugPaywallOverrides(url: url)

    #expect(overrides.shouldPresent == false)
  }

  @Test(arguments: ["true", "TRUE", "1", "yes", "YES"])
  func parse_present_truthyValues(value: String) {
    let url = URL(string: "myapp://?present=\(value)")!

    let overrides = DebugPaywallOverrides(url: url)

    #expect(overrides.shouldPresent == true)
  }

  @Test(arguments: ["false", "0", "no", "nope", ""])
  func parse_present_falsyValues(value: String) {
    let url = URL(string: "myapp://?present=\(value)")!

    let overrides = DebugPaywallOverrides(url: url)

    #expect(overrides.shouldPresent == false)
  }

  @Test func parse_combined() {
    let url = URL(string: "myapp://?superwall_debug=true&token=abc&paywall_id=123&trial_state=ineligible&appearance=dark&locale=de&present=true")!

    let overrides = DebugPaywallOverrides(url: url)

    #expect(overrides.freeTrialOverride == false)
    #expect(overrides.appearance == .dark)
    #expect(overrides.localeIdentifier == "de")
    #expect(overrides.shouldPresent == true)
    #expect(overrides.isEmpty == false)
  }
}
