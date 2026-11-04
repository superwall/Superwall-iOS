//
//  File.swift
//
//
//  Created by Yusuf Tör on 26/06/2024.
//
// swiftlint:disable all

import UIKit
import Testing
@testable import SuperwallKit

struct PaywallManagerLogicTests {
  @Test func handleCachedPaywall_isNotForPresentation() {
    let outcomes = PaywallManagerLogic.handleCachedPaywall(
      newPaywall: .stub(),
      oldPaywall: .stub(),
      isForPresentation: false
    )
    #expect(outcomes.isEmpty)
  }

  @Test func handleCachedPaywall_samePaywall_isForPresentation() {
    let outcomes = PaywallManagerLogic.handleCachedPaywall(
      newPaywall: .stub(),
      oldPaywall: .stub(),
      isForPresentation: true
    )
    #expect(outcomes.isEmpty)
  }

  @Test func handleCachedPaywall_diffPaywall_isNotForPresentation() {
    let outcomes = PaywallManagerLogic.handleCachedPaywall(
      newPaywall: .stub().setting(\.url, to: URL(string: "https://twitter.com")!),
      oldPaywall: .stub()
        .setting(\.cacheKey, to: "123"),
      isForPresentation: false
    )
    #expect(outcomes.isEmpty)
  }

  @Test func handleCachedPaywall_diffPaywall_isForPresentation() {
    let outcomes = PaywallManagerLogic.handleCachedPaywall(
      newPaywall: .stub().setting(\.url, to: URL(string: "https://twitter.com")!),
      oldPaywall: .stub()
        .setting(\.cacheKey, to: "123"),
      isForPresentation: true
    )
    #expect(outcomes == [.replacePaywall, .loadWebView])
  }
}
