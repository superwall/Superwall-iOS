//
//  File.swift
//  
//
//  Created by Jake Mor on 8/27/21.
//

import Foundation
import UIKit

final class DebugManager {
  @MainActor
	var viewController: DebugViewController?
	var isDebuggerLaunched = false

  private unowned let storage: Storage
  private unowned let factory: ViewControllerFactory

  init(
    storage: Storage,
    factory: ViewControllerFactory
  ) {
    self.storage = storage
    self.factory = factory
  }

  @MainActor
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

    storage.apiKey = debugKey

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
  /// If you call ``Superwall/handleDeepLink(_:)`` from `application(_:open:options:)` in your
  /// `AppDelegate`, this function is called automatically after scanning your debug QR code in Superwall's web dashboard.
  ///
  /// Remember to add your URL scheme in settings for QR code scanning to work.
  @MainActor
  func launchDebugger(withPaywallId paywallDatabaseId: String? = nil) async {
    if Superwall.shared.isPaywallPresented {
      await Superwall.shared.dismiss()
      await launchDebugger(withPaywallId: paywallDatabaseId)
		} else {
			if viewController == nil {
        let milliseconds = 200
        let nanoseconds = UInt64(milliseconds * 1_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
        await presentDebugger(withPaywallId: paywallDatabaseId)
			} else {
        await closeDebugger(animated: true)
        await launchDebugger(withPaywallId: paywallDatabaseId)
			}
		}
	}

  @MainActor
	func presentDebugger(withPaywallId paywallDatabaseId: String? = nil) async {
		isDebuggerLaunched = true
		if let viewController = viewController {
			viewController.paywallDatabaseId = paywallDatabaseId
			await viewController.loadPreview()
			await UIViewController.topMostViewController?.present(
        viewController,
        animated: true
      )
		} else {
      let viewController = factory.makeDebugViewController(withDatabaseId: paywallDatabaseId)
			UIViewController.topMostViewController?.present(
        viewController,
        animated: true,
        completion: nil
      )
      self.viewController = viewController
		}
	}

  @MainActor
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
