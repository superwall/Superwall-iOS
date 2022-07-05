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

  func handle(deepLinkUrl: URL) {
    guard let launchDebugger = SWDebugManagerLogic.getQueryItemValue(
      fromUrl: deepLinkUrl,
      withName: .superwallDebug
    ) else {
      return
    }
    guard Bool(launchDebugger) == true else {
      return
    }
    guard let debugKey = SWDebugManagerLogic.getQueryItemValue(
      fromUrl: deepLinkUrl,
      withName: .token
    ) else {
      return
    }

    Storage.shared.debugKey = debugKey

    let paywallId = SWDebugManagerLogic.getQueryItemValue(
      fromUrl: deepLinkUrl,
      withName: .paywallId
    )

    self.launchDebugger(withPaywallId: paywallId)
  }

	/// Launches the debugger for you to preview paywalls.
  ///
  /// If you call `Paywall.handleDeepLink(url)` from `application(_:, open:, options:)` in your `AppDelegate`, this function is called automatically after scanning your debug QR code in Superwall's web dashboard.
  ///
  /// Remember to add your URL scheme in settings for QR code scanning to work.
	func launchDebugger(withPaywallId paywallDatabaseId: String? = nil) {
    if Paywall.shared.isPaywallPresented {
			Paywall.dismiss { [weak self] in
				self?.launchDebugger(withPaywallId: paywallDatabaseId)
			}
		} else {
			if viewController == nil {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) { [weak self] in
          self?.presentDebugger(withPaywallId: paywallDatabaseId)
        }
			} else {
        closeDebugger { [weak self] in
          self?.launchDebugger(withPaywallId: paywallDatabaseId)
        }
			}
		}
	}

	func presentDebugger(withPaywallId paywallDatabaseId: String? = nil) {
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

	func closeDebugger(completion: (() -> Void)? = nil) {
		let animate = completion == nil

    func dismissViewController() {
      viewController?.dismiss(animated: animate) { [weak self] in
        self?.viewController = nil
        self?.isDebuggerLaunched = false
        completion?()
      }
    }

    if let presentedViewController = viewController?.presentedViewController {
			presentedViewController.dismiss(animated: animate) {
        dismissViewController()
			}
		} else {
      dismissViewController()
		}
	}
}
