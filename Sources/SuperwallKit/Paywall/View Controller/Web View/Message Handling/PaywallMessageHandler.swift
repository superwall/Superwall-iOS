//
//  EventHandler.swift
//  Superwall
//
//  Created by Yusuf Tör on 04/03/2022.
//
// swiftlint:disable function_body_length type_body_length file_length

import UIKit
import WebKit

protocol PaywallMessageHandlerDelegate: AnyObject {
  var request: PresentationRequest? { get }
  var paywall: Paywall { get set }
  var info: PaywallInfo { get }
  var webView: SWWebView { get }
  var loadingState: PaywallLoadingState { get set }
  var isActive: Bool { get }

  func eventDidOccur(_ paywallWebEvent: PaywallWebEvent)
  func openDeepLink(_ url: URL, shouldDismiss: Bool)
  func presentSafariInApp(_ url: URL)
  func presentSafariExternal(_ url: URL)
  func requestReview(type: ReviewType)
  func openPaymentSheet(_ url: URL)
}

@MainActor
final class PaywallMessageHandler: WebEventDelegate {
  weak var delegate: PaywallMessageHandlerDelegate?
  private unowned let receiptManager: ReceiptManager
  private let factory: VariablesFactory
  private let permissionHandler: PermissionHandling

  struct EnqueuedMessage {
    let name: String
    let paywall: Paywall
  }
  /// Used to enqueue `paywall_open` messages if the paywall isn't ready to receive them yet.
  private var messageQueue: Queue<EnqueuedMessage> = Queue()

  init(
    receiptManager: ReceiptManager,
    factory: VariablesFactory,
    permissionHandler: PermissionHandling
  ) {
    self.receiptManager = receiptManager
    self.factory = factory
    self.permissionHandler = permissionHandler
  }

  func handle(_ message: PaywallMessage) {
    Logger.debug(
      logLevel: .debug,
      scope: .paywallViewController,
      message: "Handle Message",
      info: ["message": message]
    )
    guard let paywall = delegate?.paywall else {
      return
    }

    switch message {
    case .templateParamsAndUserAttributes:
      Task {
        await self.passTemplatesToWebView(from: paywall)
      }
    case .onReady(let paywalljsVersion):
      delegate?.paywall.paywalljsVersion = paywalljsVersion
      let loadedAt = Date()
      Task {
        await self.didLoadWebView(for: paywall, at: loadedAt)
      }
    case .close:
      hapticFeedback()
      delegate?.eventDidOccur(.closed)
    case .paywallOpen:
      let paywallOpen = SuperwallEventObjc.paywallOpen.description
      if delegate?.paywall.paywalljsVersion == nil {
        let message = EnqueuedMessage(
          name: paywallOpen,
          paywall: paywall
        )
        messageQueue.enqueue(message)
      } else {
        Task {
          await self.pass(placement: paywallOpen, from: paywall)
        }
      }
    case .paywallClose:
      let paywallClose = SuperwallEventObjc.paywallClose.description
      if delegate?.paywall.paywalljsVersion == nil {
        let message = EnqueuedMessage(
          name: paywallClose,
          paywall: paywall
        )
        messageQueue.enqueue(message)
      } else {
        Task {
          await self.pass(placement: paywallClose, from: paywall)
        }
      }
    case .restoreStart:
      let restoreStart = SuperwallEventObjc.restoreStart.description
      Task {
        await self.pass(placement: restoreStart, from: paywall)
      }
    case .restoreComplete:
      let restoreComplete = SuperwallEventObjc.restoreComplete.description
      Task {
        await self.pass(placement: restoreComplete, from: paywall)
      }
    case .restoreFail:
      let restoreFail = SuperwallEventObjc.restoreFail.description
      Task {
        await self.pass(placement: restoreFail, from: paywall)
      }
    case .transactionRestore:
      let transactionRestore = SuperwallEventObjc.transactionRestore.description
      Task {
        await self.pass(placement: transactionRestore, from: paywall)
      }
    case .transactionStart:
      let transactionStart = SuperwallEventObjc.transactionStart.description
      Task {
        await self.pass(placement: transactionStart, from: paywall)
      }
    case let .transactionComplete(trialEndDate, productIdentifier):
      let freeTrialStart = SuperwallEventObjc.freeTrialStart.description
      Task {
        var payload: [String: Any] = ["product_identifier": productIdentifier]
        if let trialEndDate {
          payload["trial_end_date"] = Int(trialEndDate.timeIntervalSince1970 * 1000)
        }
        await self.pass(
          placement: freeTrialStart,
          from: paywall,
          payload: payload
        )
      }
    case .transactionFail:
      let transactionFail = SuperwallEventObjc.transactionFail.description
      Task {
        await self.pass(placement: transactionFail, from: paywall)
      }
    case .transactionAbandon:
      let transactionAbandon = SuperwallEventObjc.transactionAbandon.description
      Task {
        await self.pass(placement: transactionAbandon, from: paywall)
      }
    case .transactionTimeout:
      let transactionTimeout = SuperwallEventObjc.transactionTimeout.description
      Task {
        await self.pass(placement: transactionTimeout, from: paywall)
      }
    case .openUrl(let url):
      openUrl(url)
    case .openUrlInSafari(let url):
      openUrlInSafari(url)
    case .openPaymentSheet(let url):
      openPaymentSheet(url)
    case .openDeepLink(let url):
      openDeepLink(url)
    case .restore:
      restorePurchases()
    case .purchase(productId: let id):
      purchaseProduct(withId: id)
    case .custom(data: let name):
      handleCustomEvent(name)
    case let .customPlacement(name: name, params: params):
      handleCustomPlacement(name: name, params: params)
    case let .userAttributesUpdated(attributes: attributes):
      handleUserAttributesUpdated(attributes: attributes)
    case .initiateWebCheckout:
      // No-op: This is only here for backwards compatibility so that we don't log
      // and error when decoding the message.
      break
    case .requestStoreReview(let reviewType):
      requestReview(type: reviewType)
    case let .scheduleNotification(type, title, subtitle, body, delay):
      let notification = LocalNotification(
        type: type,
        title: title,
        subtitle: subtitle,
        body: body,
        delay: delay
      )
      delegate?.eventDidOccur(.scheduleNotification(notification: notification))
    case let .requestPermission(permissionType, requestId):
      handleRequestPermission(
        permissionType: permissionType,
        requestId: requestId,
        paywall: paywall
      )
    }
  }

  nonisolated private func pass(
    placement: String,
    from paywall: Paywall,
    payload: [String: Any] = [:]
  ) async {
    var event: [String: Any] = [
      "event_name": placement,
      "paywall_id": paywall.databaseId,
      "paywall_identifier": paywall.identifier
    ]
    event.merge(payload) { _, new in new }

    guard let jsonData = try? JSONSerialization.data(withJSONObject: [event]) else {
      return
    }
    let base64Event = jsonData.base64EncodedString()
    await passMessageToWebView(base64Event)
  }

  /// Passes the templated variables and params to the webview.
  ///
  /// This is called every paywall open incase variables like user attributes have changed.
  nonisolated private func passTemplatesToWebView(from paywall: Paywall) async {
    let eventData = await delegate?.request?.presentationInfo.placementData
    let base64Templates = await TemplateLogic.getBase64EncodedTemplates(
      from: paywall,
      placement: eventData,
      receiptManager: receiptManager,
      factory: factory
    )
    await passMessageToWebView(base64Templates)
  }

  private func passMessageToWebView(_ base64String: String) {
    let messageScript = """
    window.paywall.accept64('\(base64String)');
    """

    Logger.debug(
      logLevel: .debug,
      scope: .paywallViewController,
      message: "Posting Message",
      info: ["message": messageScript]
    )

    delegate?.webView.evaluateJavaScript(messageScript) { _, error in
      if let error = error {
        Logger.debug(
          logLevel: .error,
          scope: .paywallViewController,
          message: "Error Evaluating JS",
          info: ["message": messageScript],
          error: error
        )
      }
    }
  }

  func getState() async -> [String: Any] {
    let messageScript = """
    window.app.getAllState();
    """

    Logger.debug(
      logLevel: .debug,
      scope: .paywallViewController,
      message: "Getting state",
      info: ["message": messageScript]
    )

    do {
      let result = try await delegate?.webView.evaluateJavaScript(messageScript) as? [String: Any]
      return result ?? [:]
    } catch {
      Logger.debug(
        logLevel: .debug,
        scope: .paywallViewController,
        message: "Error Evaluating JS",
        info: ["message": messageScript],
        error: error
      )
      return [:]
    }
  }

  /// Passes in the HTML substitutions, templates and other scripts to make the webview
  /// feel native.
  nonisolated private func didLoadWebView(
    for paywall: Paywall,
    at loadedAt: Date
  ) async {
    Task(priority: .utility) {
      guard let delegate = await self.delegate else {
        return
      }

      delegate.paywall.webviewLoadingInfo.endAt = loadedAt

      let paywallInfo = delegate.info
      let webViewLoad = InternalSuperwallEvent.PaywallWebviewLoad(
        state: .complete,
        paywallInfo: paywallInfo
      )
      await Superwall.shared.track(webViewLoad)
    }

    let htmlSubstitutions = paywall.htmlSubstitutions
    let placementData = await delegate?.request?.presentationInfo.placementData
    let templates = await TemplateLogic.getBase64EncodedTemplates(
      from: paywall,
      placement: placementData,
      receiptManager: receiptManager,
      factory: factory
    )
    let scriptSrc = """
    window.paywall.accept64('\(templates)');
    window.paywall.accept64('\(htmlSubstitutions)');
    """

    Logger.debug(
      logLevel: .debug,
      scope: .paywallViewController,
      message: "Posting Message",
      info: ["message": scriptSrc],
      error: nil
    )

    await MainActor.run {
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

        let delay = self?.delegate?.paywall.presentation.delay ?? 0
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay)) {
          self?.delegate?.loadingState = .ready
        }
      }

      // block selection
      let selectionString =
        "var css = '*{-webkit-touch-callout:none;-webkit-user-select:none} .w-webflow-badge { display: none !important; }'; "
        + "var head = document.head || document.getElementsByTagName('head')[0]; "
        + "var style = document.createElement('style'); style.type = 'text/css'; "
        + "style.appendChild(document.createTextNode(css)); head.appendChild(style); "

      let selectionScript = WKUserScript(
        source: selectionString,
        injectionTime: .atDocumentEnd,
        forMainFrameOnly: true
      )
      self.delegate?.webView.configuration.userContentController.addUserScript(selectionScript)

      let preventSelection =
        "var css = '*{-webkit-touch-callout:none;-webkit-user-select:none}'; var head = document.head || document.getElementsByTagName('head')[0]; var style = document.createElement('style'); style.type = 'text/css'; style.appendChild(document.createTextNode(css)); head.appendChild(style);"
      self.delegate?.webView.evaluateJavaScript(preventSelection)

      let preventZoom =
        "var meta = document.createElement('meta');" + "meta.name = 'viewport';"
        + "meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';"
        + "var head = document.getElementsByTagName('head')[0];" + "head.appendChild(meta);"
      self.delegate?.webView.evaluateJavaScript(preventZoom)

      while !messageQueue.isEmpty {
        if let message = messageQueue.dequeue() {
          Task {
            await self.pass(
              placement: message.name,
              from: message.paywall
            )
          }
        }
      }
    }
  }

  private func openUrl(_ url: URL) {
    #if os(visionOS)
      openUrlInSafari(url)
    #else
      detectHiddenPaywallEvent(
        "openUrl",
        userInfo: ["url": url]
      )
      hapticFeedback()
      delegate?.eventDidOccur(.openedURL(url: url))
      delegate?.presentSafariInApp(url)
    #endif
  }

  private func openUrlInSafari(_ url: URL) {
    detectHiddenPaywallEvent(
      "openUrlInSafari",
      userInfo: ["url": url]
    )
    hapticFeedback()
    delegate?.eventDidOccur(.openedUrlInSafari(url))
    delegate?.presentSafariExternal(url)
  }

  private func openPaymentSheet(_ url: URL) {
    detectHiddenPaywallEvent(
      "openPaymentSheet",
      userInfo: ["url": url]
    )
    hapticFeedback()
    delegate?.openPaymentSheet(url)
  }

  private func openDeepLink(_ url: URL) {
    detectHiddenPaywallEvent(
      "openDeepLink",
      userInfo: ["url": url]
    )
    hapticFeedback()
    // Don't dismiss paywall for redemption links
    let shouldDismiss = url.redeemableCode == nil
    delegate?.openDeepLink(url, shouldDismiss: shouldDismiss)
  }

  private func requestReview(type: ReviewType) {
    delegate?.requestReview(type: type)
  }

  private func restorePurchases() {
    detectHiddenPaywallEvent("restore")
    hapticFeedback()
    delegate?.eventDidOccur(.initiateRestore)
  }

  private func purchaseProduct(withId id: String) {
    detectHiddenPaywallEvent("purchase")
    hapticFeedback()
    delegate?.eventDidOccur(.initiatePurchase(productId: id))
  }

  private func handleCustomEvent(_ customEvent: String) {
    detectHiddenPaywallEvent(
      "custom",
      userInfo: ["custom_event": customEvent]
    )
    delegate?.eventDidOccur(.custom(string: customEvent))
  }

  private func handleCustomPlacement(name: String, params: JSON) {
    delegate?.eventDidOccur(.customPlacement(name: name, params: params))
  }

  private func handleUserAttributesUpdated(attributes: JSON) {
    delegate?.eventDidOccur(.userAttributesUpdated(attributes: attributes))
  }

  private func detectHiddenPaywallEvent(
    _ eventName: String,
    userInfo: [String: Any]? = nil
  ) {
    guard delegate?.isActive == false else {
      return
    }
    let paywallDebugDescription = Superwall.shared.paywallViewController.debugDescription
    var info: [String: Any] = [
      "self": self,
      "Superwall.shared.paywallViewController": paywallDebugDescription,
      "event": eventName
    ]
    if let userInfo = userInfo {
      info = info.merging(userInfo)
    }
    Logger.debug(
      logLevel: .error,
      scope: .paywallViewController,
      message: "Received Event on Hidden Superwall",
      info: info
    )
  }

  private func hapticFeedback() {
    guard Superwall.shared.options.paywalls.isHapticFeedbackEnabled else {
      return
    }
    if Superwall.shared.options.isGameControllerEnabled {
      return
    }
    #if !os(visionOS)
      UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
    #endif
  }

  // MARK: - Permission Handling

  private func handleRequestPermission(
    permissionType: PermissionType,
    requestId: String,
    paywall: Paywall
  ) {
    let permissionName = permissionType.rawValue

    Task {
      // Track permission requested event
      let requestedEvent = InternalSuperwallEvent.Permission(
        state: .requested,
        permissionName: permissionName,
        paywallIdentifier: paywall.identifier
      )
      await Superwall.shared.track(requestedEvent)

      let status = await permissionHandler.requestPermission(permissionType)

      // Track permission result event
      let resultState: InternalSuperwallEvent.PermissionState = status == .granted ? .granted : .denied
      let resultEvent = InternalSuperwallEvent.Permission(
        state: resultState,
        permissionName: permissionName,
        paywallIdentifier: paywall.identifier
      )
      await Superwall.shared.track(resultEvent)

      await pass(
        placement: "permission_result",
        from: paywall,
        payload: [
          "permission_type": permissionType.rawValue,
          "request_id": requestId,
          "status": status.rawValue
        ]
      )
    }
  }
}
