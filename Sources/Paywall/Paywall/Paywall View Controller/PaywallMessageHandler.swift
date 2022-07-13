//
//  LeakAvoider.swift
//  Paywall
//
//  Created by Yusuf Tör on 03/03/2022.
//

import Foundation
import WebKit

protocol WebEventDelegate: AnyObject {
  func handleEvent(_ event: PaywallEvent)
}

final class PaywallMessageHandler: NSObject, WKScriptMessageHandler {
  weak var delegate: WebEventDelegate?

  init(delegate: WebEventDelegate) {
    super.init()
    self.delegate = delegate
  }

  func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    Logger.debug(
      logLevel: .debug,
      scope: .paywallViewController,
      message: "Did Receive Message",
      info: ["message": message.debugDescription],
      error: nil
    )

    guard let bodyString = message.body as? String else {
      Logger.debug(
        logLevel: .warn,
        scope: .paywallViewController,
        message: "Unable to Convert Message to String",
        info: ["message": message.debugDescription]
      )
      return
    }

    guard let bodyData = bodyString.data(using: .utf8) else {
      Logger.debug(
        logLevel: .warn,
        scope: .paywallViewController,
        message: "Unable to Convert Message to Data",
        info: ["message": message.debugDescription]
      )
      return
    }

    guard let wrappedPaywallEvents = try? JSONDecoder.fromSnakeCase.decode(
      WrappedPaywallEvents.self,
      from: bodyData
    ) else {
      Logger.debug(
        logLevel: .warn,
        scope: .paywallViewController,
        message: "Invalid WrappedPaywallEvent",
        info: ["message": message.debugDescription]
      )
      return
    }

    Logger.debug(
      logLevel: .debug,
      scope: .paywallViewController,
      message: "Body Converted",
      info: ["message": message.debugDescription, "events": wrappedPaywallEvents]
    )

    let events = wrappedPaywallEvents.payload.events

    for event in events {
      delegate?.handleEvent(event)
    }
  }
}
