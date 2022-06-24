//
//  EventHandler.swift
//  Paywall
//
//  Created by Yusuf Tör on 04/03/2022.
//
// swiftlint:disable line_length

import UIKit
import WebKit

protocol WebEventHandlerDelegate: AnyObject {
  var presentationInfo: PresentationInfo? { get }
  var paywallResponse: PaywallResponse { get set }
  var paywallInfo: PaywallInfo { get }
  var webView: SWWebView { get }
  var loadingState: PaywallLoadingState { get set }
  var isPresentedViewController: Bool { get }

  func eventDidOccur(_ paywallPresentationResult: PaywallPresentationResult)
  func presentSafari(_ url: URL)
}

final class WebEventHandler: WebEventDelegate {
  weak var delegate: WebEventHandlerDelegate?

  init(delegate: WebEventHandlerDelegate?) {
    self.delegate = delegate
  }

  func handleEvent(_ event: PaywallEvent) {
    Logger.debug(
      logLevel: .debug,
      scope: .paywallViewController,
      message: "Handle Event",
      info: ["event": event],
      error: nil
    )

    guard let paywallResponse = delegate?.paywallResponse else {
      return
    }

    switch event {
    case .templateParamsAndUserAttributes:
      templateParams(from: paywallResponse)
    case .onReady:
      didLoadWebView(from: paywallResponse)
    case .close:
      hapticFeedback()
      delegate?.eventDidOccur(.closed)
    case .openUrl(let url):
      openUrl(url)
    case .openDeepLink(let url):
      openDeepLink(url)
    case .restore:
      restorePurchases()
    case .purchase(product: let type):
      purchaseProduct(
        withType: type,
        from: paywallResponse
      )
    case .custom(data: let customEvent):
      handleCustomEvent(customEvent)
    }
  }

  private func templateParams(from paywallResponse: PaywallResponse) {
    let params = paywallResponse.getBase64EventsString(
      params: delegate?.presentationInfo?.eventData?.parameters
    )
    let scriptSrc = """
      window.paywall.accept64('\(params)');
    """
    delegate?.webView.evaluateJavaScript(scriptSrc) { _, error in
      if let error = error {
        Logger.debug(
          logLevel: .error,
          scope: .paywallViewController,
          message: "Error Evaluating JS",
          info: ["message": scriptSrc],
          error: error
        )
      }
    }

    Logger.debug(
      logLevel: .debug,
      scope: .paywallViewController,
      message: "Posting Message",
      info: ["message": scriptSrc],
      error: nil
    )
  }

  private func didLoadWebView(from paywallResponse: PaywallResponse) {
    if let paywallInfo = delegate?.paywallInfo {
      if paywallResponse.webViewLoadCompleteTime == nil {
        delegate?.paywallResponse.webViewLoadCompleteTime = Date()
      }

      let trackedEvent = SuperwallEvent.PaywallWebviewLoad(
        state: .complete,
        paywallInfo: paywallInfo
      )
      Paywall.track(trackedEvent)

      SessionEventsManager.shared.triggerSession.trackWebviewLoad(
        forPaywallId: paywallInfo.id,
        state: .end
      )
    }

    let params = paywallResponse.getBase64EventsString(
      params: delegate?.presentationInfo?.eventData?.parameters
    )
    let jsEvent = paywallResponse.paywalljsEvent
    let scriptSrc = """
      window.paywall.accept64('\(params)');
      window.paywall.accept64('\(jsEvent)');
    """

    Logger.debug(
      logLevel: .debug,
      scope: .paywallViewController,
      message: "Posting Message",
      info: ["message": scriptSrc],
      error: nil
    )

    delegate?.webView.evaluateJavaScript(scriptSrc) { [weak self] _, error in
      if let error = error {
        Logger.debug(
          logLevel: .error,
          scope: .paywallViewController,
          message: "Error Evaluating JS",
          info: ["message": scriptSrc],
          error: error
        )
      }
      self?.delegate?.loadingState = .ready
    }

    // block selection
    let selectionString = "var css = '*{-webkit-touch-callout:none;-webkit-user-select:none} .w-webflow-badge { display: none !important; }'; "
      + "var head = document.head || document.getElementsByTagName('head')[0]; "
      + "var style = document.createElement('style'); style.type = 'text/css'; "
      + "style.appendChild(document.createTextNode(css)); head.appendChild(style); "

    let selectionScript = WKUserScript(
      source: selectionString,
      injectionTime: .atDocumentEnd,
      forMainFrameOnly: true
    )
    delegate?.webView.configuration.userContentController.addUserScript(selectionScript)

    // swiftlint:disable:next line_length
    let preventSelection = "var css = '*{-webkit-touch-callout:none;-webkit-user-select:none}'; var head = document.head || document.getElementsByTagName('head')[0]; var style = document.createElement('style'); style.type = 'text/css'; style.appendChild(document.createTextNode(css)); head.appendChild(style);"
    delegate?.webView.evaluateJavaScript(preventSelection)

    // swiftlint:disable:next line_length
    let preventZoom: String = "var meta = document.createElement('meta');" + "meta.name = 'viewport';" + "meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';" + "var head = document.getElementsByTagName('head')[0];" + "head.appendChild(meta);"
    delegate?.webView.evaluateJavaScript(preventZoom)
  }

  private func openUrl(_ url: URL) {
    detectHiddenPaywallEvent(
      "openUrl",
      userInfo: ["url": url]
    )
    hapticFeedback()
    delegate?.eventDidOccur(.openedURL(url: url))
    delegate?.presentSafari(url)
  }

  private func openDeepLink(_ url: URL) {
    detectHiddenPaywallEvent(
      "openDeepLink",
      userInfo: ["url": url]
    )
    hapticFeedback()
    delegate?.eventDidOccur(.openedDeepLink(url: url))
    // TODO: Handle deep linking
  }

  private func restorePurchases() {
    detectHiddenPaywallEvent("restore")
    hapticFeedback()
    delegate?.eventDidOccur(.initiateRestore)
  }

  private func purchaseProduct(
    withType productType: ProductType,
    from paywallResponse: PaywallResponse
  ) {
    detectHiddenPaywallEvent("purchase")
    hapticFeedback()
    let product = paywallResponse.products.first { $0.type == productType }
    if let product = product {
      delegate?.eventDidOccur(.initiatePurchase(productId: product.id))
    }
  }

  private func handleCustomEvent(_ customEvent: String) {
    detectHiddenPaywallEvent(
      "custom",
      userInfo: ["custom_event": customEvent]
    )
    delegate?.eventDidOccur(.custom(string: customEvent))
  }

  private func detectHiddenPaywallEvent(
    _ eventName: String,
    userInfo: [String: Any]? = nil
  ) {
    guard delegate?.isPresentedViewController == false else {
      return
    }
    let paywallDebugDescription = Paywall.shared.paywallViewController.debugDescription
    var info: [String: Any] = [
      "self": self,
      "Paywall.shared.paywallViewController": paywallDebugDescription,
      "event": eventName
    ]
    if let userInfo = userInfo {
      info = info.merging(userInfo)
    }
    Logger.debug(
      logLevel: .error,
      scope: .paywallViewController,
      message: "Received Event on Hidden Paywall",
      info: info
    )
  }

  private func hapticFeedback() {
    if Paywall.isGameControllerEnabled {
      return
    }
    UIImpactFeedbackGenerator().impactOccurred()
  }
}
