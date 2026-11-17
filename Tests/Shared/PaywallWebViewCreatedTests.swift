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
