//
//  File.swift
//  
//
//  Created by Yusuf Tör on 19/01/2023.
//

import Foundation
@testable import SuperwallKit

final class FakeWebView: SWWebView {
  var willHandleJs = false

  #if compiler(>=6.0)
  override func evaluateJavaScript(_ javaScriptString: String, completionHandler: (@MainActor (Any?, (any Error)?) -> Void)? = nil) {
    willHandleJs = true
  }
  #else
  override func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, (any Error)?) -> Void)? = nil) {
    willHandleJs = true
  }
  #endif
}

final class PaywallMessageHandlerDelegateMock: PaywallMessageHandlerDelegate {
  var eventDidOccur: PaywallWebEvent?
  var didPresentSafariInApp = false
  var didOpenDeepLink = false
  var didPresentSafariExternal = false
  var didRequestReview = false
  var didOpenPaymentSheet = false

  var request: PresentationRequest?

  var paywall: SuperwallKit.Paywall = .stub()

  var info: SuperwallKit.PaywallInfo

  var webView: SuperwallKit.SWWebView

  var loadingState: SuperwallKit.PaywallLoadingState = .loadingURL

  var isActive = false

  init(
    paywallInfo: SuperwallKit.PaywallInfo,
    webView: FakeWebView
  ) {
    self.info = paywallInfo
    self.webView = webView
  }

  func eventDidOccur(_ paywallWebEvent: SuperwallKit.PaywallWebEvent) {
    eventDidOccur = paywallWebEvent
  }

  func openDeepLink(_ url: URL) {
    didOpenDeepLink = true
  }

  func presentSafariInApp(_ url: URL) {
    didPresentSafariInApp = true
  }

  func presentSafariExternal(_ url: URL) {
    didPresentSafariExternal = true
  }

  func requestReview(type: ReviewType) {
    didRequestReview = true
  }

  func openPaymentSheet(_ url: URL) {
    didOpenPaymentSheet = true
  }
}
