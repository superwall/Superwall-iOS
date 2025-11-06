//
//  LeakAvoider.swift
//  Superwall
//
//  Created by Yusuf Tör on 03/03/2022.
//

import Foundation
import WebKit

protocol WebEventDelegate: AnyObject {
  @MainActor func handle(_ message: PaywallMessage)
}

final class RawWebMessageHandler: NSObject, WKScriptMessageHandler {
  weak var delegate: WebEventDelegate?

  init(delegate: WebEventDelegate) {
    super.init()
    self.delegate = delegate
  }

  func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    Task { @MainActor in
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

      let wrappedPaywallMessages: WrappedPaywallMessages
      do {
        wrappedPaywallMessages = try JSONDecoder.fromSnakeCase.decode(
          WrappedPaywallMessages.self,
          from: bodyData
        )
      } catch {
        Logger.debug(
          logLevel: .warn,
          scope: .paywallViewController,
          message: "Invalid WrappedPaywallEvent",
          info: ["body": bodyString, "error": error.localizedDescription]
        )
        return
      }

      Logger.debug(
        logLevel: .debug,
        scope: .paywallViewController,
        message: "Body Converted",
        info: ["message": message.debugDescription, "events": wrappedPaywallMessages]
      )

      let messages = wrappedPaywallMessages.payload.messages

      for message in messages {
        delegate?.handle(message)
      }
    }
  }
}
