//
//  WebApplePayProbe.swift
//  SuperwallKit
//
//  Created by Jake Mor on 04/11/2026.
//

import Foundation
import WebKit

/// Whether the browser can pay with Apple Pay at the app's web checkout, as
/// opposed to whether the device supports Apple Pay at all.
///
/// Reported as the `webApplePayReadiness` device attribute: `ready`, `notReady`,
/// or `unknown:<reason>`. Audience rules should route on `notReady` only, so a
/// browser that couldn't be measured keeps the default behaviour.
enum WebApplePayReadiness: Equatable {
  case ready
  case notReady
  case unknown(Reason)

  enum Reason: String {
    /// No probe has answered yet on this device.
    case notMeasured
    /// Turned off with ``SuperwallOptions/isWebApplePayReadinessEnabled``.
    case disabled
    /// The config names no web checkout domain, so there is nothing to measure.
    case noCheckoutDomain
    /// The web view has no Apple Pay web API at all.
    case noApplePayAPI
    /// Apple Pay's web API threw or answered with something unreadable.
    case apiError
    /// The probe page never ran: the load failed or its web content process died.
    case probeFailed
    case timedOut
  }

  var rawValue: String {
    switch self {
    case .ready:
      return "ready"
    case .notReady:
      return "notReady"
    case .unknown(let reason):
      return "unknown:\(reason.rawValue)"
    }
  }

  /// Only real measurements are stored and served on later launches.
  init?(measuredRawValue: String) {
    switch measuredRawValue {
    case "ready":
      self = .ready
    case "notReady":
      self = .notReady
    default:
      return nil
    }
  }

  var isUnknown: Bool {
    if case .unknown = self {
      return true
    }
    return false
  }
}

/// Runs Apple Pay's web API in an offscreen `WKWebView` whose document has the
/// web checkout's origin, so it answers the question the checkout page asks.
///
/// `canMakePaymentsWithActiveCard` is the only signal that reflects whether the
/// Wallet holds a card usable at that origin's merchant. Native PassKit checks
/// say yes on any Apple Pay capable device, including one with an empty Wallet,
/// and they ignore Safari's "Check for Apple Pay" setting.
///
/// Apple Pay refuses insecure documents and pages with injected scripts, so the
/// HTML is loaded with `loadHTMLString(_:baseURL:)` under the https origin, with
/// nothing fetched, and reports back through a message handler rather than any
/// user script or `evaluateJavaScript`.
@MainActor
final class WebApplePayProbe: NSObject {
  struct Outcome: Equatable {
    let readiness: WebApplePayReadiness
    let duration: TimeInterval
    /// Set when the page couldn't answer.
    let failureReason: String?
  }

  private static let messageName = "superwallApplePayProbe"

  private let origin: URL
  private let timeout: TimeInterval
  private var startedAt = Date()
  private var webView: WKWebView?
  private var continuation: CheckedContinuation<Outcome, Never>?
  private var resolvedOutcome: Outcome?

  /// The timeout bounds how long the probe lives, not how long anything waits on
  /// it. On a cold launch WebKit can take seconds to start its processes before
  /// the page runs, and a measurement that lands late is still stored for the
  /// next launch.
  init(origin: URL, timeout: TimeInterval = 10) {
    self.origin = origin
    self.timeout = timeout
  }

  func run() async -> Outcome {
    if let resolvedOutcome = resolvedOutcome {
      return resolvedOutcome
    }
    startedAt = Date()

    let controller = WKUserContentController()
    // The handler is retained by the controller until `finish` removes it.
    controller.add(self, name: Self.messageName)
    let configuration = WKWebViewConfiguration()
    configuration.userContentController = controller

    let webView = WKWebView(
      frame: CGRect(x: 0, y: 0, width: 1, height: 1),
      configuration: configuration
    )
    webView.navigationDelegate = self
    webView.isHidden = true
    self.webView = webView

    return await withCheckedContinuation { continuation in
      self.continuation = continuation
      webView.loadHTMLString(Self.probeHTML, baseURL: origin)

      Task { [weak self, timeout] in
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        self?.finish(readiness: .unknown(.timedOut), failureReason: "timeout")
      }
    }
  }

  /// Anything other than a boolean `activeCard` is an absent measurement, never
  /// a negative one, so a page that fails to answer can't send a user away from
  /// web checkout.
  nonisolated static func result(
    for payload: [String: Any]
  ) -> (readiness: WebApplePayReadiness, failureReason: String?) {
    if let activeCard = payload["activeCard"] as? Bool {
      return (activeCard ? .ready : .notReady, nil)
    }
    let error = payload["error"] as? String ?? "malformedResult"
    let reason: WebApplePayReadiness.Reason = error == "noApplePaySession" ? .noApplePayAPI : .apiError
    return (.unknown(reason), error)
  }

  /// The JS result, a load failure and the timeout race to get here. The first
  /// one wins and the rest are dropped.
  func finish(readiness: WebApplePayReadiness, failureReason: String?) {
    guard resolvedOutcome == nil else {
      return
    }

    webView?.configuration.userContentController.removeScriptMessageHandler(forName: Self.messageName)
    webView?.stopLoading()
    webView?.navigationDelegate = nil
    webView = nil

    let outcome = Outcome(
      readiness: readiness,
      duration: Date().timeIntervalSince(startedAt),
      failureReason: failureReason
    )
    resolvedOutcome = outcome
    let continuation = self.continuation
    self.continuation = nil
    continuation?.resume(returning: outcome)
  }

  /// Stripe registers a web domain for Apple Pay under the merchant identifier
  /// `merchant.<hostname>.stripe`, and that's the identifier its checkout asks
  /// Apple Pay about, so the probe asks about the same one.
  private static let probeHTML = """
  <!DOCTYPE html>
  <html><head><meta charset="utf-8"></head><body><script>
  (function () {
    var post = function (o) { try { window.webkit.messageHandlers.\(messageName).postMessage(o); } catch (e) {} };
    if (!window.ApplePaySession) { post({ error: 'noApplePaySession' }); return; }
    var merchantId = 'merchant.' + window.location.hostname + '.stripe';
    try {
      Promise.resolve(window.ApplePaySession.canMakePaymentsWithActiveCard(merchantId))
        .then(function (v) { post({ activeCard: v === true }); })
        .catch(function (e) { post({ error: 'activeCardRejected: ' + String(e) }); });
    } catch (e) {
      post({ error: 'activeCardThrew: ' + String(e) });
    }
  })();
  </script></body></html>
  """
}

// MARK: - WKScriptMessageHandler
extension WebApplePayProbe: WKScriptMessageHandler {
  func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    guard message.name == Self.messageName else {
      return
    }
    let result = Self.result(for: message.body as? [String: Any] ?? [:])
    finish(readiness: result.readiness, failureReason: result.failureReason)
  }
}

// MARK: - WKNavigationDelegate
// swiftlint:disable implicitly_unwrapped_optional
extension WebApplePayProbe: WKNavigationDelegate {
  func webView(
    _ webView: WKWebView,
    didFail navigation: WKNavigation!,
    withError error: Error
  ) {
    finish(readiness: .unknown(.probeFailed), failureReason: "didFail: \(error.localizedDescription)")
  }

  func webView(
    _ webView: WKWebView,
    didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    finish(
      readiness: .unknown(.probeFailed),
      failureReason: "didFailProvisional: \(error.localizedDescription)"
    )
  }

  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    finish(readiness: .unknown(.probeFailed), failureReason: "webContentProcessTerminated")
  }
}
// swiftlint:enable implicitly_unwrapped_optional
