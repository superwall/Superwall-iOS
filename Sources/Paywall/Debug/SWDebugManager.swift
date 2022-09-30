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

@MainActor
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
    Task {
      await self.launchDebugger(withPaywallId: paywallId)
    }
  }

	/// Launches the debugger for you to preview paywalls.
  ///
  /// If you call `Paywall.handleDeepLink(url)` from `application(_:, open:, options:)` in your `AppDelegate`, this function is called automatically after scanning your debug QR code in Superwall's web dashboard.
  ///
  /// Remember to add your URL scheme in settings for QR code scanning to work.
  func launchDebugger(withPaywallId paywallDatabaseId: String? = nil) async {
    if Paywall.shared.isPaywallPresented {
      await Paywall.dismiss()
      await launchDebugger(withPaywallId: paywallDatabaseId)
		} else {
			if viewController == nil {
        let twoHundredMilliseconds = UInt64(200_000_000)
        try? await Task.sleep(nanoseconds: twoHundredMilliseconds)
        await presentDebugger(withPaywallId: paywallDatabaseId)
			} else {
        await closeDebugger(animated: true)
        await launchDebugger(withPaywallId: paywallDatabaseId)
			}
		}
	}

	func presentDebugger(withPaywallId paywallDatabaseId: String? = nil) async {
		isDebuggerLaunched = true
		if let viewController = viewController {
			viewController.paywallDatabaseId = paywallDatabaseId
			await viewController.loadPreview()
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

  func closeDebugger(animated: Bool) async {
    func dismissViewController() async {
      return await withCheckedContinuation { continuation in
        viewController?.dismiss(animated: animated) { [weak self] in
          self?.viewController = nil
          self?.isDebuggerLaunched = false
          continuation.resume()
        }
      }
    }

    if let presentedViewController = viewController?.presentedViewController {
			await presentedViewController.dismiss(animated: animated)
      await dismissViewController()
		} else {
      await dismissViewController()
		}
	}
}
