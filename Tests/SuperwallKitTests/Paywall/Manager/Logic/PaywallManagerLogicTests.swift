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
      isPreloading: false,
      isForPresentation: false
    )
    #expect(outcomes.isEmpty)
  }

  @Test func handleCachedPaywall_samePaywallURLs_isPreloading() {
    let outcomes = PaywallManagerLogic.handleCachedPaywall(
      newPaywall: .stub(),
      oldPaywall: .stub(),
      isPreloading: true,
      isForPresentation: false
    )
    #expect(outcomes.isEmpty)
  }

  @Test func handleCachedPaywall_samePaywallURLs_isNotPreloading() {
    let outcomes = PaywallManagerLogic.handleCachedPaywall(
      newPaywall: .stub(),
      oldPaywall: .stub(),
      isPreloading: false,
      isForPresentation: true
    )
    #expect(outcomes == [.setDelegate, .updatePaywall])
  }

  @Test func handleCachedPaywall_diffPaywallURLs_isNotPreloading() {
    let outcomes = PaywallManagerLogic.handleCachedPaywall(
      newPaywall: .stub().setting(\.url, to: URL(string: "https://twitter.com")!),
      oldPaywall: .stub()
        .setting(\.cacheKey, to: "123"),
      isPreloading: false,
      isForPresentation: true
    )
    #expect(outcomes == [.replacePaywall, .loadWebView, .setDelegate])
  }

  @Test func handleCachedPaywall_diffPaywallURLs_isPreloading() {
    let outcomes = PaywallManagerLogic.handleCachedPaywall(
      newPaywall: .stub().setting(\.url, to: URL(string: "https://twitter.com")!),
      oldPaywall: .stub()
        .setting(\.cacheKey, to: "123"),
      isPreloading: true,
      isForPresentation: true
    )
    #expect(outcomes == [.replacePaywall, .loadWebView])
  }
}
