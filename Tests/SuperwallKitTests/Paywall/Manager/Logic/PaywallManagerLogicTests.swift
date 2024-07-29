//
//  File.swift
//  
//
//  Created by Yusuf Tör on 26/06/2024.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit

final class PaywallManagerLogicTests: XCTestCase {
  func testHandleCachedPaywall_isNotForPresentation() {
    let outcomes = PaywallManagerLogic.handleCachedPaywall(
      newPaywall: .stub(),
      oldPaywall: .stub(),
      isPreloading: false,
      isForPresentation: false
    )
    XCTAssertTrue(outcomes.isEmpty)
  }

  func testHandleCachedPaywall_samePaywallURLs_isPreloading() {
    let outcomes = PaywallManagerLogic.handleCachedPaywall(
      newPaywall: .stub(),
      oldPaywall: .stub(),
      isPreloading: true,
      isForPresentation: false
    )
    XCTAssertTrue(outcomes.isEmpty)
  }

  func testHandleCachedPaywall_samePaywallURLs_isNotPreloading() {
    let outcomes = PaywallManagerLogic.handleCachedPaywall(
      newPaywall: .stub(),
      oldPaywall: .stub(),
      isPreloading: false,
      isForPresentation: true
    )
    XCTAssertEqual(outcomes, [.setDelegate, .updatePaywall])
  }

  func testHandleCachedPaywall_diffPaywallURLs_isNotPreloading() {
    let outcomes = PaywallManagerLogic.handleCachedPaywall(
      newPaywall: .stub().setting(\.url, to: URL(string: "https://twitter.com")!),
      oldPaywall: .stub()
        .setting(\.cacheKey, to: "123"),
      isPreloading: false,
      isForPresentation: true
    )
    XCTAssertEqual(outcomes, [.replacePaywall, .loadWebView, .setDelegate])
  }

  func testHandleCachedPaywall_diffPaywallURLs_isPreloading() {
    let outcomes = PaywallManagerLogic.handleCachedPaywall(
      newPaywall: .stub().setting(\.url, to: URL(string: "https://twitter.com")!),
      oldPaywall: .stub()
        .setting(\.cacheKey, to: "123"),
      isPreloading: true,
      isForPresentation: true
    )
    XCTAssertEqual(outcomes, [.replacePaywall, .loadWebView])
  }
}
