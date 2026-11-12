//
//  TransactionAlert.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Presents the alerts the purchase and restore flows show.
enum TransactionAlert {
  static func present(
    title: String,
    message: String,
    closeActionTitle: String? = nil,
    source: GenericSource
  ) async {
    let resolvedCloseTitle = closeActionTitle ?? LocalizationLogic.localizedBundle().localizedString(
      forKey: "alert_action_done",
      value: nil,
      table: nil
    )
    switch source {
    #if canImport(WebKit)
    case .internal(let paywallViewController):
      await paywallViewController.presentAlert(
        title: title,
        message: message,
        closeActionTitle: resolvedCloseTitle
      )
    #endif
    case .external:
      #if canImport(WebKit)
      guard let topMostViewController = await PlatformViewController.topMostViewController else {
        Logger.debug(
          logLevel: .error,
          scope: .transactions,
          message:
            "Could not find the top-most view controller to present a transaction alert from."
        )
        return
      }
      #if os(macOS)
      await AlertControllerFactory.present(
        title: title,
        message: message,
        closeActionTitle: resolvedCloseTitle,
        on: topMostViewController
      )
      #else
      let alertController = await AlertControllerFactory.make(
        title: title,
        message: message,
        closeActionTitle: resolvedCloseTitle,
        sourceView: topMostViewController.view
      )
      await topMostViewController.present(alertController, animated: true)
      #endif
      #else
      // There's no SDK alert UI here, so the app reports the failure itself.
      Logger.debug(
        logLevel: .warn,
        scope: .transactions,
        message: "\(title): \(message)"
      )
      #endif
    }
  }
}
