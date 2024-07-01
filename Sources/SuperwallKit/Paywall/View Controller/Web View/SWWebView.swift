//
//  SWWebView.swift
//  Superwall
//
//  Created by Yusuf Tör on 03/03/2022.
//
// swiftlint:disable implicitly_unwrapped_optional function_body_length

import Foundation
import WebKit

protocol SWWebViewDelegate: AnyObject {
  var info: PaywallInfo { get }
  func webViewDidFailProvisionalNavigation()
  func webViewDidFail()
}

class SWWebView: WKWebView {
  let messageHandler: PaywallMessageHandler
  weak var delegate: (SWWebViewDelegate & PaywallMessageHandlerDelegate)?
  var didFailToLoad = false
  private let wkConfig: WKWebViewConfiguration
  private let isMac: Bool

  init(
    isMac: Bool,
    sessionEventsManager: SessionEventsManager,
    messageHandler: PaywallMessageHandler,
    factory: FeatureFlagsFactory
  ) {
    self.isMac = isMac
    self.messageHandler = messageHandler

    let config = WKWebViewConfiguration()
    config.allowsInlineMediaPlayback = true
    config.allowsAirPlayForMediaPlayback = true
    config.allowsPictureInPictureMediaPlayback = true
    config.mediaTypesRequiringUserActionForPlayback = []

    let featureFlags = factory.makeFeatureFlags()
    if featureFlags?.enableSuppressesIncrementalRendering == true {
      config.suppressesIncrementalRendering = true
    }

    let preferences = WKPreferences()
    if #available(iOS 15.0, *),
      !isMac {
      preferences.isTextInteractionEnabled = false // ignore-xcode-12
    }
    preferences.javaScriptCanOpenWindowsAutomatically = true

    #if compiler(>=5.9.0)
    if #available(iOS 17.0, *) {
      if featureFlags?.enableThrottleSchedulingPolicy == true {
        preferences.inactiveSchedulingPolicy = .throttle
      } else if featureFlags?.enableNoneSchedulingPolicy == true {
        preferences.inactiveSchedulingPolicy = .none
      }
    }
    #endif

    config.preferences = preferences
    wkConfig = config

    super.init(
      frame: .zero,
      configuration: wkConfig
    )
    wkConfig.userContentController.add(
      RawWebMessageHandler(delegate: messageHandler),
      name: "paywallMessageHandler"
    )
    self.navigationDelegate = self

    translatesAutoresizingMaskIntoConstraints = false
    allowsBackForwardNavigationGestures = true
    allowsLinkPreview = false
    backgroundColor = .clear
    scrollView.maximumZoomScale = 1.0
    scrollView.minimumZoomScale = 1.0
    isOpaque = false
    #if compiler(>=5.8) && os(iOS)
    if #available(iOS 16.4, *) {
      isInspectable = true
    }
    #endif

    scrollView.contentInsetAdjustmentBehavior = .never
    scrollView.bounces = true
    scrollView.contentInset = .zero
    scrollView.scrollIndicatorInsets = .zero
    scrollView.showsVerticalScrollIndicator = false
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.maximumZoomScale = 1.0
    scrollView.minimumZoomScale = 1.0
    scrollView.backgroundColor = .clear
    scrollView.isOpaque = false
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - WKNavigationDelegate
extension SWWebView: WKNavigationDelegate {
  enum WebViewError: LocalizedError {
    case network(Int)

    var errorDescription: String? {
      switch self {
      case .network(let errorCode):
        return "The network failed with error code \(errorCode)"
      }
    }
  }

  func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationResponse: WKNavigationResponse
  ) async -> WKNavigationResponsePolicy {
    guard let statusCode = (navigationResponse.response as? HTTPURLResponse)?.statusCode else {
      // if there's no http status code to act on, exit and allow navigation
      return .allow
    }

    // Track paywall errors
    if statusCode >= 400 {
      await trackPaywallError(WebViewError.network(statusCode))
      return .cancel
    }

    return .allow
  }

  func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction
  ) async -> WKNavigationActionPolicy {
    if webView.isLoading {
      return .allow
    }
    if navigationAction.navigationType == .reload {
      return .allow
    }
    return .cancel
  }

  func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    didFailToLoad = false
  }

  func webView(
    _ webView: WKWebView,
    didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    didFailToLoad = true
    delegate?.webViewDidFailProvisionalNavigation()
  }

  func webView(
    _ webView: WKWebView,
    didFail navigation: WKNavigation!,
    withError error: Error
  ) {
    didFailToLoad = true
    delegate?.webViewDidFail()
    let date = Date()
    Task {
      await trackPaywallError(error, at: date)
    }
  }

  func trackPaywallError(
    _ error: Error,
    at failAt: Date = Date()
  ) async {
    delegate?.paywall.webviewLoadingInfo.failAt = failAt

    guard let paywallInfo = delegate?.info else {
      return
    }

    let trackedEvent = InternalSuperwallEvent.PaywallWebviewLoad(
      state: .fail(error),
      paywallInfo: paywallInfo
    )
    await Superwall.shared.track(trackedEvent)
  }
}
