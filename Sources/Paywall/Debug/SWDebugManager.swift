//
//  File.swift
//  
//
//  Created by Jake Mor on 8/27/21.
//

import Foundation
import UIKit

struct DebugResponse {
  var paywallId: Int
  var token: String
}

final class SWDebugManager {
	var viewController: SWDebugViewController?
  static let shared = SWDebugManager()
	var isDebuggerLaunched = false

  func handle(deepLink: URL) {
    let deepLinkURLString = deepLink.absoluteString

    if let launchDebugger = getQueryStringParameter(url: deepLinkURLString, param: "superwall_debug") {
      if launchDebugger == "true" {
        Store.shared.debugKey = getQueryStringParameter(url: deepLinkURLString, param: "token")

        if Store.shared.debugKey != nil {
          SWDebugManager.shared.launchDebugger(
            toPaywall: getQueryStringParameter(url: deepLinkURLString, param: "paywall_id")
          )
        }
      }
    }
  }

	/// Launches the debugger for you to preview paywalls.
  ///
  /// If you call `Paywall.track(.deepLinkOpen(deepLinkUrl: url))` from `application(_:, open:, options:)` in your `AppDelegate`, this function is called automatically after scanning your debug QR code in Superwall's web dashboard.
  ///
  /// Remember to add you URL scheme in settings for QR code scanning to work.
	func launchDebugger(toPaywall paywallDatabaseId: String? = nil) {
		if Paywall.shared.isPaywallPresented {
			Paywall.dismiss { [weak self] in
				self?.launchDebugger(toPaywall: paywallDatabaseId)
			}
		} else {
			if viewController == nil {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) { [weak self] in
          self?.presentDebugger(toPaywall: paywallDatabaseId)
        }
			} else {
        closeDebugger { [weak self] in
          self?.launchDebugger(toPaywall: paywallDatabaseId)
        }
			}
		}
	}

	func presentDebugger(toPaywall paywallDatabaseId: String? = nil) {
		isDebuggerLaunched = true
		if let viewController = viewController {
			viewController.paywallDatabaseId = paywallDatabaseId
			viewController.loadPreview()
			UIViewController.topMostViewController?.present(
        viewController,
        animated: true
      )
		} else {
			let viewController = SWDebugViewController()
			viewController.paywallDatabaseId = paywallDatabaseId
			viewController.modalPresentationStyle = .overFullScreen
			UIViewController.topMostViewController?.present(
        viewController,
        animated: true,
        completion: nil
      )
      self.viewController = viewController
		}
	}

	func closeDebugger(completion: (() -> Void)?) {
		let animate = completion == nil

		if viewController?.presentedViewController != nil {
			viewController?.presentedViewController?.dismiss(animated: animate) { [weak self] in
				self?.viewController?.dismiss(animated: animate) { [weak self] in
					self?.viewController = nil
					self?.isDebuggerLaunched = false
					completion?()
				}
			}
		} else {
			viewController?.dismiss(animated: animate) { [weak self] in
				self?.viewController = nil
				self?.isDebuggerLaunched = false
				completion?()
			}
		}
	}

  func getQueryStringParameter(
    url: String,
    param: String
  ) -> String? {
    guard let url = URLComponents(string: url) else {
      return nil
    }
    return url.queryItems?.first { $0.name == param }?.value
  }
}
