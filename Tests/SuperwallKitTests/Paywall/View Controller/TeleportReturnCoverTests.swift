//
//  TeleportReturnCoverTests.swift
//  SuperwallKitTests
//

import Testing
import UIKit
import WebKit
@testable import SuperwallKit

/// Drives the cover through the app lifecycle the way iOS does, with notifications, and with the
/// checkout never settling, so every cover is the one put up just before suspension.
@MainActor
struct TeleportReturnCoverTests {
  @MainActor
  private final class Fixture {
    let window: UIWindow
    let view: UIView
    let webView: WKWebView
    let cover: TeleportReturnCover
    /// This fixture's own center, so no other test's cover hears its notifications.
    let notificationCenter = NotificationCenter()

    init(timing: TeleportReturnCover.Timing, isSettled: Bool = false) {
      window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
      view = UIView(frame: window.bounds)
      webView = WKWebView(frame: window.bounds)
      window.addSubview(view)
      window.isHidden = false
      var state: UIApplication.State = .active
      var environment = TeleportReturnCover.Environment()
      environment.applicationState = { state }
      environment.isSettled = { _ in isSettled }
      environment.makeStill = { _ in UIView() }
      environment.beginBackgroundTask = { _ in UIBackgroundTaskIdentifier(rawValue: 1) }
      environment.endBackgroundTask = { _ in }
      environment.backgroundTimeRemaining = { 30 }
      environment.notificationCenter = notificationCenter
      cover = TeleportReturnCover(
        view: view,
        webView: webView,
        timing: timing,
        environment: environment
      )
      setState = { state = $0 }
    }

    private var setState: (UIApplication.State) -> Void = { _ in }

    func set(_ newState: UIApplication.State) {
      setState(newState)
    }
  }

  private static let watch = TeleportReturnCover.Watch(
    teleportId: "tp_1",
    teleportStatusUrl: URL(string: "https://example.com/teleport")!,
    checkoutStatusUrl: URL(string: "https://example.com/checkout")!,
    publicApiKey: "pk_test"
  )

  private static var fastTiming: TeleportReturnCover.Timing {
    var timing = TeleportReturnCover.Timing()
    timing.drawWait = 50_000_000
    timing.stillTimeout = 50_000_000
    timing.backgroundCheckLimit = 0
    timing.suspendLead = 0
    timing.snapshotLinger = 10_000_000
    timing.revealGrace = 100_000_000
    timing.revealDuration = 0.4
    return timing
  }

  private func post(
    _ name: Notification.Name,
    to fixture: Fixture,
    userInfo: [AnyHashable: Any]? = nil
  ) {
    fixture.notificationCenter.post(name: name, object: nil, userInfo: userInfo)
  }

  private func sleep(_ seconds: Double) async {
    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
  }

  /// Leaves for the browser and comes back to a suspended app: the cover put up before
  /// suspension is over the waiting screen.
  private func makeSuspendedCover() async -> Fixture {
    let fixture = Fixture(timing: Self.fastTiming)
    fixture.cover.startWatching(Self.watch)
    fixture.cover.leave(drawingWaitingScreen: true) {}
    await sleep(0.1)
    fixture.set(.background)
    post(UIApplication.didEnterBackgroundNotification, to: fixture)
    await sleep(0.1)
    #expect(fixture.cover.isCovering)
    return fixture
  }

  @Test("An activation interrupted during the grace period does not stop the next one revealing")
  func testRevealAfterInterruptedGrace() async {
    let fixture = await makeSuspendedCover()

    // The app becomes active and then inactive again before the grace period ends.
    fixture.set(.active)
    post(UIApplication.didBecomeActiveNotification, to: fixture)
    fixture.set(.inactive)
    await sleep(0.2)
    #expect(fixture.cover.isCovering)

    fixture.set(.active)
    post(UIApplication.didBecomeActiveNotification, to: fixture)
    await sleep(0.2 + Self.fastTiming.revealDuration + 0.2)

    #expect(!fixture.cover.isCovering)
  }

  @Test("A return link during the fade keeps the cover whole until the page removes the screen")
  func testReturnLinkDuringFade() async {
    let fixture = await makeSuspendedCover()

    fixture.set(.active)
    post(UIApplication.didBecomeActiveNotification, to: fixture)
    await sleep(0.2)
    #expect(fixture.cover.isCovering)

    post(.superwallReturnLinkOpened, to: fixture, userInfo: ["reason": "purchased"])
    #expect(fixture.cover.isCovering)
    #expect(fixture.cover.coverAlpha == 1)

    await sleep(0.15)
    #expect(!fixture.cover.isCovering)
  }

  @Test(
    "The page functions are called by their teleport names, or their checkout names on older pages",
    arguments: [
      ("showTeleportWaitingScreen", "handleTeleportReturn"),
      ("showCheckoutWaitingScreen", "hideCheckoutWaitingScreen"),
    ]
  )
  func pageFunctions(show: String, handleReturn: String) async throws {
    let webView = try await loadedWebView()
    _ = try await webView.callAsyncJavaScript(
      """
      window.calls = [];
      window.app = {
        [show]: async () => { window.calls.push("show"); return true },
        [handleReturn]: async (options) => { window.calls.push("return:" + options.reason); return true },
      };
      """,
      arguments: ["show": show, "handleReturn": handleReturn],
      contentWorld: .page
    )

    let shown = try await webView.callAsyncJavaScript(
      TeleportReturnCover.showWaitingScreenScript,
      contentWorld: .page
    )
    let returned = try await webView.callAsyncJavaScript(
      TeleportReturnCover.returnScript,
      arguments: ["reason": "purchased"],
      contentWorld: .page
    )
    let calls = try await webView.callAsyncJavaScript(
      "return window.calls",
      contentWorld: .page
    ) as? [String]

    #expect(shown as? Bool == true)
    #expect(returned as? Bool == true)
    #expect(calls == ["show", "return:purchased"])
  }

  @Test("A page with both names only has the teleport-named function called")
  func pageWithBothNames() async throws {
    let webView = try await loadedWebView()
    _ = try await webView.callAsyncJavaScript(
      """
      window.calls = [];
      window.app = {
        showTeleportWaitingScreen: () => { window.calls.push("show") },
        showCheckoutWaitingScreen: () => { window.calls.push("showCheckout") },
        handleTeleportReturn: () => { window.calls.push("return") },
        hideCheckoutWaitingScreen: () => { window.calls.push("hideCheckout") },
      };
      """,
      contentWorld: .page
    )

    _ = try await webView.callAsyncJavaScript(
      TeleportReturnCover.showWaitingScreenScript,
      contentWorld: .page
    )
    _ = try await webView.callAsyncJavaScript(
      TeleportReturnCover.returnScript,
      arguments: ["reason": ""],
      contentWorld: .page
    )
    let calls = try await webView.callAsyncJavaScript(
      "return window.calls",
      contentWorld: .page
    ) as? [String]

    #expect(calls == ["show", "return"])
  }

  @Test("A still from an earlier leave timing out does not take down a later leave's still")
  func testEarlierStillTimeoutKeepsLaterStill() async {
    var timing = Self.fastTiming
    timing.stillTimeout = 200_000_000
    let fixture = Fixture(timing: timing)

    fixture.cover.leave(drawingWaitingScreen: true) {}
    await sleep(0.1)
    fixture.cover.leave(drawingWaitingScreen: true) {}
    // Past the first leave's timeout, before the second's.
    await sleep(0.18)
    #expect(fixture.view.subviews.count == 1)

    await sleep(0.2)
    #expect(fixture.view.subviews.isEmpty)
  }

  @Test("Back after settling, the page hears the reason of a return link that arrives late")
  func testSettledCoverWaitsForLateReturnLink() async throws {
    var timing = Self.fastTiming
    timing.backgroundCheckLimit = 1
    let fixture = Fixture(timing: timing, isSettled: true)
    fixture.webView.loadHTMLString("<html><body id=\"loaded\"></body></html>", baseURL: nil)
    while try await fixture.webView.evaluateJavaScript(
      "document.getElementById('loaded') !== null"
    ) as? Bool != true {
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    _ = try await fixture.webView.callAsyncJavaScript(
      """
      window.reasons = [];
      window.app = {
        handleTeleportReturn: async (options) => { window.reasons.push(options.reason); return true },
      };
      """,
      contentWorld: .page
    )

    fixture.cover.startWatching(Self.watch)
    fixture.cover.leave(drawingWaitingScreen: true) {}
    await sleep(0.1)
    fixture.set(.background)
    post(UIApplication.didEnterBackgroundNotification, to: fixture)
    await sleep(0.1)
    #expect(fixture.cover.isCovering)

    // The app is active before the link is handed over.
    fixture.set(.active)
    post(UIApplication.didBecomeActiveNotification, to: fixture)
    await sleep(0.02)
    post(.superwallReturnLinkOpened, to: fixture, userInfo: ["reason": "purchased"])
    await sleep(0.3)

    let reasons = try await fixture.webView.callAsyncJavaScript(
      "return window.reasons",
      contentWorld: .page
    ) as? [String]
    #expect(reasons == ["purchased"])
    #expect(!fixture.cover.isCovering)
  }

  @Test("A page without the functions is answered with false")
  func pageWithoutFunctions() async throws {
    let webView = try await loadedWebView()

    let shown = try await webView.callAsyncJavaScript(
      TeleportReturnCover.showWaitingScreenScript,
      contentWorld: .page
    )
    let returned = try await webView.callAsyncJavaScript(
      TeleportReturnCover.returnScript,
      arguments: ["reason": ""],
      contentWorld: .page
    )

    #expect(shown as? Bool == false)
    #expect(returned as? Bool == false)
  }

  /// A web view whose page has loaded. The blank page before it already reads as complete, so the
  /// wait is for an element only the loaded page has.
  private func loadedWebView() async throws -> WKWebView {
    let webView = WKWebView()
    webView.loadHTMLString("<html><body id=\"loaded\"></body></html>", baseURL: nil)
    while try await webView.evaluateJavaScript(
      "document.getElementById('loaded') !== null"
    ) as? Bool != true {
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    return webView
  }
}
