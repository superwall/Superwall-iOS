//
//  DeepLinkRouterTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 25/11/2025.
//
// swiftlint:disable all

import Testing
@testable import SuperwallKit
import Foundation

struct DeepLinkRouterTests {
  // MARK: - Superwall Universal Links

  @Test("Returns true for Superwall universal link with superwall.app domain")
  func storeDeepLink_superwallUniversalLink_superwallApp() {
    let url = URL(string: "https://myapp.superwall.app/app-link/some/path")!
    let result = DeepLinkRouter.storeDeepLink(url)
    #expect(result == true)
  }

  @Test("Returns true for Superwall universal link with superwallapp.dev domain")
  func storeDeepLink_superwallUniversalLink_superwallappDev() {
    let url = URL(string: "https://myapp.superwallapp.dev/app-link/some/path")!
    let result = DeepLinkRouter.storeDeepLink(url)
    #expect(result == true)
  }

  @Test("Returns false for superwall.app without app-link path")
  func storeDeepLink_superwallDomain_noAppLinkPath() {
    let url = URL(string: "https://myapp.superwall.app/other/path")!
    let result = DeepLinkRouter.storeDeepLink(url)
    #expect(result == false)
  }

  // MARK: - Redemption Code URLs

  @Test("Returns true for URL scheme redemption code")
  func storeDeepLink_redemptionCode_urlScheme() {
    // Format: scheme://superwall/redeem?code=XXX (host="superwall", path="/redeem")
    let url = URL(string: "myapp://superwall/redeem?code=ABC123")!
    let result = DeepLinkRouter.storeDeepLink(url)
    #expect(result == true)
  }

  @Test("Returns true for superwall.app redemption code")
  func storeDeepLink_redemptionCode_superwallApp() {
    let url = URL(string: "https://myapp.superwall.app/app-link/superwall/redeem?code=ABC123")!
    let result = DeepLinkRouter.storeDeepLink(url)
    #expect(result == true)
  }

  @Test("Returns true for superwallapp.dev redemption code")
  func storeDeepLink_redemptionCode_superwallappDev() {
    let url = URL(string: "https://myapp.superwallapp.dev/app-link/superwall/redeem?code=ABC123")!
    let result = DeepLinkRouter.storeDeepLink(url)
    #expect(result == true)
  }

  @Test("Returns false for redemption path without code parameter")
  func storeDeepLink_redemptionPath_noCode() {
    let url = URL(string: "myapp://superwall/redeem")!
    let result = DeepLinkRouter.storeDeepLink(url)
    #expect(result == false)
  }

  // MARK: - Debug/Preview URLs

  @Test("Returns true for debug URL with superwall_debug and token")
  func storeDeepLink_debugUrl_withToken() {
    let url = URL(string: "myapp://?superwall_debug=true&token=abc123")!
    let result = DeepLinkRouter.storeDeepLink(url)
    #expect(result == true)
  }

  @Test("Returns true for debug URL with paywall_id")
  func storeDeepLink_debugUrl_withPaywallId() {
    let url = URL(string: "myapp://?superwall_debug=true&token=abc123&paywall_id=pw123")!
    let result = DeepLinkRouter.storeDeepLink(url)
    #expect(result == true)
  }

  @Test("Returns false for superwall_debug without token")
  func storeDeepLink_debugUrl_noToken() {
    let url = URL(string: "myapp://?superwall_debug=true")!
    let result = DeepLinkRouter.storeDeepLink(url)
    #expect(result == false)
  }

  @Test("Returns false for superwall_debug=false")
  func storeDeepLink_debugUrl_debugFalse() {
    let url = URL(string: "myapp://?superwall_debug=false&token=abc123")!
    let result = DeepLinkRouter.storeDeepLink(url)
    #expect(result == false)
  }

  // MARK: - Non-Superwall URLs

  @Test("Returns false for generic app URL")
  func storeDeepLink_genericAppUrl() {
    let url = URL(string: "myapp://home")!
    let result = DeepLinkRouter.storeDeepLink(url)
    #expect(result == false)
  }

  @Test("Returns false for external website URL")
  func storeDeepLink_externalWebsite() {
    let url = URL(string: "https://example.com/some/path")!
    let result = DeepLinkRouter.storeDeepLink(url)
    #expect(result == false)
  }

  @Test("Returns false for URL with unrelated query params")
  func storeDeepLink_unrelatedQueryParams() {
    let url = URL(string: "myapp://settings?theme=dark&language=en")!
    let result = DeepLinkRouter.storeDeepLink(url)
    #expect(result == false)
  }

  @Test("Returns false for app deep link that looks similar")
  func storeDeepLink_similarLookingUrl() {
    let url = URL(string: "myapp://superwall/premium")!
    let result = DeepLinkRouter.storeDeepLink(url)
    #expect(result == false)
  }

  // MARK: - Cached Config with deepLink_open Trigger
  //
  // Note: The storeDeepLink function reads from the actual disk cache,
  // which makes it difficult to test the cached config scenario in isolation.
  // The isSuperwallURL logic for checking cached config is tested implicitly
  // through integration tests. The URL format detection tests above cover
  // the primary use cases.

  // MARK: - URL Extension Tests

  @Test("isSuperwallDeepLink returns true for valid format")
  func isSuperwallDeepLink_validFormat() {
    let url = URL(string: "https://test.superwall.app/app-link/path")!
    #expect(url.isSuperwallDeepLink == true)
  }

  @Test("isSuperwallDeepLink returns false without app-link prefix")
  func isSuperwallDeepLink_noAppLinkPrefix() {
    let url = URL(string: "https://test.superwall.app/other/path")!
    #expect(url.isSuperwallDeepLink == false)
  }

  @Test("isSuperwallDeepLink returns false for non-superwall domain")
  func isSuperwallDeepLink_wrongDomain() {
    let url = URL(string: "https://example.com/app-link/path")!
    #expect(url.isSuperwallDeepLink == false)
  }

  @Test("redeemableCode returns code from URL scheme format")
  func redeemableCode_urlScheme() {
    // Format: scheme://superwall/redeem?code=XXX (host="superwall", path="/redeem")
    let url = URL(string: "myapp://superwall/redeem?code=TESTCODE")!
    #expect(url.redeemableCode == "TESTCODE")
  }

  @Test("redeemableCode returns code from universal link format")
  func redeemableCode_universalLink() {
    let url = URL(string: "https://app.superwall.app/app-link/superwall/redeem?code=TESTCODE")!
    #expect(url.redeemableCode == "TESTCODE")
  }

  @Test("redeemableCode returns nil for non-redemption URL")
  func redeemableCode_nonRedemption() {
    let url = URL(string: "myapp://home")!
    #expect(url.redeemableCode == nil)
  }
}
