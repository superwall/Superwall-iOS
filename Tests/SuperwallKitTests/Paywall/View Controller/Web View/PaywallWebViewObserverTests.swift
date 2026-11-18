//
//  PaywallWebViewObserverTests.swift
//  SuperwallKit
//

#if canImport(WebKit)
@testable import SuperwallKit
import Testing
import WebKit

@Suite(.serialized)
@MainActor
struct PaywallWebViewObserverTests {
  let dependencyContainer = DependencyContainer()

  private func makePaywallWebView() -> WKWebView {
    return dependencyContainer.makePaywallViewController(
      for: .stub(),
      withCache: nil,
      withPaywallArchiveManager: nil,
      delegate: nil
    ).webView
  }

  @Test
  func calledOncePerWebViewBeforeItLoads() {
    var received: [WKWebView] = []
    var loadedBeforeObserver = false
    let observation = Superwall.addPaywallWebViewObserver { webView in
      if webView.url != nil || webView.isLoading {
        loadedBeforeObserver = true
      }
      received.append(webView)
    }
    defer { observation.cancel() }

    let first = makePaywallWebView()
    let second = makePaywallWebView()

    #expect(received.count == 2)
    #expect(received.first === first)
    #expect(received.last === second)
    #expect(!loadedBeforeObserver)
  }

  @Test
  func changesMadeByAnObserverStayOnThePaywallWebView() {
    let observation = Superwall.addPaywallWebViewObserver { webView in
      webView.customUserAgent = "AddOn/1.0"
    }
    defer { observation.cancel() }

    let webView = makePaywallWebView()

    #expect(webView.customUserAgent == "AddOn/1.0")
    #expect(webView.navigationDelegate === webView)
    #expect(webView.url == nil)
  }

  @Test
  func everyObserverIsCalledInTheOrderAdded() {
    var calls: [String] = []
    let first = Superwall.addPaywallWebViewObserver { _ in calls.append("first") }
    let second = Superwall.addPaywallWebViewObserver { _ in calls.append("second") }
    let third = Superwall.addPaywallWebViewObserver { _ in calls.append("third") }
    defer {
      first.cancel()
      second.cancel()
      third.cancel()
    }

    _ = makePaywallWebView()

    #expect(calls == ["first", "second", "third"])
  }

  @Test
  func cancelledObserverIsNotCalledAgain() {
    var cancelledCalls = 0
    var keptCalls = 0
    let cancelled = Superwall.addPaywallWebViewObserver { _ in cancelledCalls += 1 }
    let kept = Superwall.addPaywallWebViewObserver { _ in keptCalls += 1 }
    defer { kept.cancel() }

    _ = makePaywallWebView()
    cancelled.cancel()
    // Cancelling twice does nothing.
    cancelled.cancel()
    _ = makePaywallWebView()

    #expect(cancelledCalls == 1)
    #expect(keptCalls == 2)
  }

  @Test
  func observerCanCancelItselfWhileItIsCalled() {
    var selfCancellingCalls = 0
    var laterCalls = 0
    var observation: PaywallWebViewObservation?
    observation = Superwall.addPaywallWebViewObserver { _ in
      selfCancellingCalls += 1
      observation?.cancel()
    }
    let later = Superwall.addPaywallWebViewObserver { _ in laterCalls += 1 }
    defer { later.cancel() }

    _ = makePaywallWebView()
    _ = makePaywallWebView()

    #expect(selfCancellingCalls == 1)
    // The one added after it still gets the web view it was cancelled on.
    #expect(laterCalls == 2)
  }

  @Test
  func lettingGoOfTheObservationKeepsObserving() throws {
    var calls = 0
    var observation: PaywallWebViewObservation? = Superwall.addPaywallWebViewObserver { _ in
      calls += 1
    }
    let id = try #require(observation?.id)
    defer { PaywallWebViewObservers.remove(id: id) }
    observation = nil

    _ = makePaywallWebView()

    #expect(calls == 1)
  }

  @Test
  func checkoutWebViewsNeverReachAnObserver() throws {
    var calls = 0
    let observation = Superwall.addPaywallWebViewObserver { _ in calls += 1 }
    defer { observation.cancel() }

    let url = try #require(URL(string: "https://example.com/checkout"))
    _ = CheckoutWebViewController(url: url)

    #expect(calls == 0)
  }
}
#endif
