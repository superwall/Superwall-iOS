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
  func webViewDidFail()
}

enum WebViewError: LocalizedError {
  case network(Int)
  case exceededAttempts
  case noEndpoints

  var errorDescription: String? {
    switch self {
    case .network(let errorCode):
      return "The network failed with error code \(errorCode)."
    case .exceededAttempts:
      return "The webview has attempted to load too many times."
    case .noEndpoints:
      return "There were no paywall URLs provided."
    }
  }
}

class SWWebView: WKWebView {
  let messageHandler: PaywallMessageHandler
  let loadingHandler: SWWebViewLoadingHandler
  weak var delegate: (SWWebViewDelegate & PaywallMessageHandlerDelegate)? {
    didSet {
      self.loadingHandler.webViewDelegate = delegate
    }
  }
  private let wkConfig: WKWebViewConfiguration
  private let isMac: Bool
  private let isOnDeviceCacheEnabled: Bool
  private var completion: ((Error?) -> Void)?

  init(
    isMac: Bool,
    messageHandler: PaywallMessageHandler,
    isOnDeviceCacheEnabled: Bool,
    factory: FeatureFlagsFactory
  ) {
    self.isMac = isMac
    self.messageHandler = messageHandler
    self.isOnDeviceCacheEnabled = isOnDeviceCacheEnabled
    let featureFlags = factory.makeFeatureFlags()

    self.loadingHandler = SWWebViewLoadingHandler(
      enableMultiplePaywallUrls: featureFlags?.enableMultiplePaywallUrls == true
    )

    let config = WKWebViewConfiguration()
    config.allowsInlineMediaPlayback = true
    config.allowsAirPlayForMediaPlayback = true
    config.allowsPictureInPictureMediaPlayback = true
    config.mediaTypesRequiringUserActionForPlayback = []

    if featureFlags?.enableSuppressesIncrementalRendering == true {
      config.suppressesIncrementalRendering = true
    }

    let preferences = WKPreferences()

    if #available(iOS 15.0, *),
      !isMac {
      preferences.isTextInteractionEnabled = featureFlags?.enableTextInteraction == true // ignore-xcode-12
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

    let size: CGSize

    #if os(visionOS)
    size = .zero
    #else
    size = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
    #endif

    super.init(
      frame: CGRect(origin: .zero, size: size),
      configuration: wkConfig
    )
    self.loadingHandler.loadingDelegate = self

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

  func loadURL(from paywall: Paywall) async {
    let didLoad = await loadingHandler.loadURL(
      paywallUrlConfig: paywall.urlConfig,
      paywallUrl: paywall.url
    )
    if !didLoad {
      delegate?.webViewDidFail()
    }
  }
}

extension SWWebView: SWWebViewLoadingDelegate {
  func loadWebView(
    with url: URL,
    timeout: TimeInterval?
  ) async throws {
    var request: URLRequest

    if isOnDeviceCacheEnabled {
      request = URLRequest(
        url: url,
        cachePolicy: .returnCacheDataElseLoad
      )
    } else {
      request = URLRequest(url: url)
    }

    if let timeout = timeout {
      request.timeoutInterval = timeout
    }
    load(request)

    return try await withCheckedThrowingContinuation { [weak self] continuation in
      self?.completion = { [weak self] error in
        if let error = error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: ())
        }
        self?.completion = nil
      }
    }
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
      completion?(WebViewError.network(statusCode))
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

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    completion?(nil)
  }

  func webView(
    _ webView: WKWebView,
    didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    completion?(error)
  }

  func webView(
    _ webView: WKWebView,
    didFail navigation: WKNavigation!,
    withError error: Error
  ) {
    completion?(error)
  }
}
