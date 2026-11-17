//
//  PaywallWebViewCreatedTests.swift
//  SuperwallKit
//

#if canImport(WebKit)
@testable import SuperwallKit
import Testing
import WebKit

@Suite(.serialized)
@MainActor
struct PaywallWebViewCreatedTests {
  @Test
  func firesOncePerWebViewBeforeItLoads() {
    let dependencyContainer = DependencyContainer()
    var received: [WKWebView] = []
    var loadedBeforeHook = false
    Superwall.paywallWebViewCreated = { webView in
      if webView.url != nil || webView.isLoading {
        loadedBeforeHook = true
      }
      received.append(webView)
    }
    defer { Superwall.paywallWebViewCreated = nil }

    let first = dependencyContainer.makePaywallViewController(
      for: .stub(),
      withCache: nil,
      withPaywallArchiveManager: nil,
      delegate: nil
    )
    let second = dependencyContainer.makePaywallViewController(
      for: .stub(),
      withCache: nil,
      withPaywallArchiveManager: nil,
      delegate: nil
    )

    #expect(received.count == 2)
    #expect(received.first === first.webView)
    #expect(received.last === second.webView)
    #expect(!loadedBeforeHook)
  }

  @Test
  func changesMadeInTheHookStayOnThePaywallWebView() {
    let dependencyContainer = DependencyContainer()
    Superwall.paywallWebViewCreated = { webView in
      webView.customUserAgent = "AddOn/1.0"
    }
    defer { Superwall.paywallWebViewCreated = nil }

    let paywallViewController = dependencyContainer.makePaywallViewController(
      for: .stub(),
      withCache: nil,
      withPaywallArchiveManager: nil,
      delegate: nil
    )

    let webView = paywallViewController.webView
    #expect(webView.customUserAgent == "AddOn/1.0")
    // The paywall's own wiring is untouched by the hook.
    #expect(webView.navigationDelegate === webView)
    #expect(webView.url == nil)
  }

  @Test
  func onlyTheLatestHookIsCalled() {
    let dependencyContainer = DependencyContainer()
    var firstCalls = 0
    var secondCalls = 0
    Superwall.paywallWebViewCreated = { _ in firstCalls += 1 }
    Superwall.paywallWebViewCreated = { _ in secondCalls += 1 }
    defer { Superwall.paywallWebViewCreated = nil }

    _ = dependencyContainer.makePaywallViewController(
      for: .stub(),
      withCache: nil,
      withPaywallArchiveManager: nil,
      delegate: nil
    )

    #expect(firstCalls == 0)
    #expect(secondCalls == 1)
  }

  @Test
  func checkoutWebViewsNeverReachTheHook() throws {
    var calls = 0
    Superwall.paywallWebViewCreated = { _ in calls += 1 }
    defer { Superwall.paywallWebViewCreated = nil }

    let url = try #require(URL(string: "https://example.com/checkout"))
    _ = CheckoutWebViewController(url: url)

    #expect(calls == 0)
  }

  @Test
  func unsetHookChangesNothing() {
    Superwall.paywallWebViewCreated = nil
    let dependencyContainer = DependencyContainer()

    let paywallViewController = dependencyContainer.makePaywallViewController(
      for: .stub(),
      withCache: nil,
      withPaywallArchiveManager: nil,
      delegate: nil
    )

    #expect(paywallViewController.webView.url == nil)
  }
}
#endif
