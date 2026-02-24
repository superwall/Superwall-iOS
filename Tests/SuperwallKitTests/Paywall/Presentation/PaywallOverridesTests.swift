//
//  PaywallOverridesTests.swift
//  SuperwallKitTests
//

import Testing
import Foundation
@testable import SuperwallKit

struct PaywallOverridesTests {
  @Test("checkoutOnly defaults to false")
  func checkoutOnlyDefaultsFalse() {
    let overrides = PaywallOverrides()
    #expect(overrides.checkoutOnly == false)
  }

  @Test("checkoutOnly can be set to true")
  func checkoutOnlySetToTrue() {
    let overrides = PaywallOverrides(checkoutOnly: true)
    #expect(overrides.checkoutOnly == true)
  }

  @Test("checkoutOnly false with products and style")
  func checkoutOnlyFalseWithOtherParams() {
    let overrides = PaywallOverrides(
      productsByName: [:],
      presentationStyleOverride: .fullscreen
    )
    #expect(overrides.checkoutOnly == false)
  }

  @Test("checkoutOnly true with products and style")
  func checkoutOnlyTrueWithOtherParams() {
    let overrides = PaywallOverrides(
      productsByName: [:],
      presentationStyleOverride: .fullscreen,
      checkoutOnly: true
    )
    #expect(overrides.checkoutOnly == true)
    #expect(overrides.presentationStyle == .fullscreen)
  }

  @Test("productsByName-only init defaults checkoutOnly to false")
  func productsByNameInitDefaultsCheckoutOnly() {
    let overrides = PaywallOverrides(productsByName: [:])
    #expect(overrides.checkoutOnly == false)
  }
}
