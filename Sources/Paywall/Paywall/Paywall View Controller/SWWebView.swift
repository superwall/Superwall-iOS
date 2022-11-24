//
//  SWWebView.swift
//  Paywall
//
//  Created by Yusuf Tör on 03/03/2022.
//
// swiftlint:disable implicitly_unwrapped_optional

import Foundation
import WebKit

protocol SWWebViewDelegate: AnyObject {
  var paywallInfo: PaywallInfo { get }
}

final class SWWebView: WKWebView {
  lazy var eventHandler = WebEventHandler(delegate: delegate)
  weak var delegate: (SWWebViewDelegate & WebEventHandlerDelegate)?

  private var wkConfig: WKWebViewConfiguration = {
    let config = WKWebViewConfiguration()
    config.allowsInlineMediaPlayback = true
    config.allowsAirPlayForMediaPlayback = true
    config.allowsPictureInPictureMediaPlayback = true
    config.mediaTypesRequiringUserActionForPlayback = []

    let preferences = WKPreferences()
    if #available(iOS 15.0, *) {
      if !DeviceHelper.shared.isMac {
//         preferences.isTextInteractionEnabled = false // ignore-xcode-12
      }
    }
    preferences.javaScriptCanOpenWindowsAutomatically = true
    config.preferences = preferences
    return config
  }()

  init(delegate: SWWebViewDelegate & WebEventHandlerDelegate) {
    self.delegate = delegate
    super.init(
      frame: .zero,
      configuration: wkConfig
    )
    wkConfig.userContentController.add(
      PaywallMessageHandler(delegate: eventHandler),
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
  func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationResponse: WKNavigationResponse,
    decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
  ) {
    guard let statusCode = (navigationResponse.response as? HTTPURLResponse)?.statusCode else {
      // if there's no http status code to act on, exit and allow navigation
      return decisionHandler(.allow)
    }

    // Track paywall errors
    if statusCode >= 400 {
      trackPaywallError()
      return decisionHandler(.cancel)
    }

    decisionHandler(.allow)
  }

  func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
  ) {
    if webView.isLoading {
      return decisionHandler(.allow)
    }
    if navigationAction.navigationType == .reload {
      return decisionHandler(.allow)
    }
    decisionHandler(.cancel)
  }

  func webView(
    _ webView: WKWebView,
    didFail navigation: WKNavigation!,
    withError error: Error
  ) {
    trackPaywallError()
  }

  func trackPaywallError() {
    delegate?.paywallResponse.webViewLoadFailTime = Date()

    guard let paywallInfo = delegate?.paywallInfo else {
      return
    }

    SessionEventsManager.shared.triggerSession.trackWebviewLoad(
      forPaywallId: paywallInfo.id,
      state: .fail
    )

    let trackedEvent = SuperwallEvent.PaywallWebviewLoad(
      state: .fail,
      paywallInfo: paywallInfo
    )
    Paywall.track(trackedEvent)
  }
}
