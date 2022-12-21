//
//  SWWebView.swift
//  Superwall
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
  lazy var messageHandler = PaywallMessageHandler(delegate: delegate)
  weak var delegate: (SWWebViewDelegate & PaywallMessageHandlerDelegate)?
  private let deviceHelper: DeviceHelper
  private let wkConfig: WKWebViewConfiguration
  private let sessionEventsManager: SessionEventsManager

  init(
    delegate: SWWebViewDelegate & PaywallMessageHandlerDelegate,
    deviceHelper: DeviceHelper,
    sessionEventsManager: SessionEventsManager
  ) {
    self.deviceHelper = deviceHelper
    self.delegate = delegate
    self.sessionEventsManager = sessionEventsManager

    let config = WKWebViewConfiguration()
    config.allowsInlineMediaPlayback = true
    config.allowsAirPlayForMediaPlayback = true
    config.allowsPictureInPictureMediaPlayback = true
    config.mediaTypesRequiringUserActionForPlayback = []

    let preferences = WKPreferences()
    if #available(iOS 15.0, *) {
      if !deviceHelper.isMac {
        preferences.isTextInteractionEnabled = false // ignore-xcode-12
      }
    }
    preferences.javaScriptCanOpenWindowsAutomatically = true
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
    decidePolicyFor navigationResponse: WKNavigationResponse
  ) async -> WKNavigationResponsePolicy {
    guard let statusCode = (navigationResponse.response as? HTTPURLResponse)?.statusCode else {
      // if there's no http status code to act on, exit and allow navigation
      return .allow
    }

    // Track paywall errors
    if statusCode >= 400 {
      await trackPaywallError()
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

  func webView(
    _ webView: WKWebView,
    didFail navigation: WKNavigation!,
    withError error: Error
  ) {
    Task {
      await trackPaywallError()
    }
  }

  func trackPaywallError() async {
    delegate?.paywall.webviewLoadingInfo.failAt = Date()

    guard let paywallInfo = delegate?.paywallInfo else {
      return
    }

    await sessionEventsManager.triggerSession.trackWebviewLoad(
      forPaywallId: paywallInfo.databaseId,
      state: .fail
    )

    let trackedEvent = InternalSuperwallEvent.PaywallWebviewLoad(
      state: .fail,
      paywallInfo: paywallInfo
    )
    await Superwall.track(trackedEvent)
  }
}
