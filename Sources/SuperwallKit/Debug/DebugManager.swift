//
//  File.swift
//  
//
//  Created by Jake Mor on 8/27/21.
//

import Foundation
import UIKit

final class DebugManager {
  @MainActor var viewController: DebugViewController?
	var isDebuggerLaunched = false

  private unowned let storage: Storage
  private unowned let factory: ViewControllerFactory
  struct DeepLinkOutcome {
    let debugKey: String
    let paywallId: String?
    let overrides: DebugPaywallOverrides
  }

  init(
    storage: Storage,
    factory: ViewControllerFactory
  ) {
    self.storage = storage
    self.factory = factory
  }

  func handle(deepLinkUrl url: URL) -> Bool {
    guard let outcome = Self.outcomeForDeepLink(url: url) else {
      return false
    }
    storage.debugKey = outcome.debugKey
    Task {
      await self.launchDebugger(
        withPaywallId: outcome.paywallId,
        overrides: outcome.overrides
      )
    }
    return true
  }

  static func outcomeForDeepLink(url: URL) -> DeepLinkOutcome? {
    guard let launchDebugger = SWDebugManagerLogic.getQueryItemValue(
      fromUrl: url,
      withName: .superwallDebug
    ) else {
      return nil
    }
    guard Bool(launchDebugger) == true else {
      return nil
    }
    guard let debugKey = SWDebugManagerLogic.getQueryItemValue(
      fromUrl: url,
      withName: .token
    ) else {
      return nil
    }
    let paywallId = SWDebugManagerLogic.getQueryItemValue(
      fromUrl: url,
      withName: .paywallId
    )
    return .init(
      debugKey: debugKey,
      paywallId: paywallId,
      overrides: DebugPaywallOverrides(url: url)
    )
  }

	/// Launches the debugger for you to preview paywalls.
  ///
  /// If you call ``Superwall/handleDeepLink(_:)`` from `application(_:open:options:)` in your
  /// `AppDelegate`, this function is called automatically after scanning your debug QR code in Superwall's web dashboard.
  ///
  /// Remember to add your URL scheme in settings for QR code scanning to work.
  @MainActor
  func launchDebugger(
    withPaywallId paywallDatabaseId: String? = nil,
    overrides: DebugPaywallOverrides = DebugPaywallOverrides()
  ) async {
    if Superwall.shared.isPaywallPresented {
      await Superwall.shared.dismiss()
      await launchDebugger(withPaywallId: paywallDatabaseId, overrides: overrides)
		} else {
			if viewController == nil {
        let milliseconds = 200
        let nanoseconds = UInt64(milliseconds * 1_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
        await presentDebugger(withPaywallId: paywallDatabaseId, overrides: overrides)
			} else {
        await closeDebugger(animated: true)
        await launchDebugger(withPaywallId: paywallDatabaseId, overrides: overrides)
			}
		}
	}

  @MainActor
	func presentDebugger(
    withPaywallId paywallDatabaseId: String? = nil,
    overrides: DebugPaywallOverrides = DebugPaywallOverrides()
  ) async {
		isDebuggerLaunched = true
		if let viewController = viewController {
      if viewController.isBeingPresented {
        return
      }
			viewController.paywallDatabaseId = paywallDatabaseId
      viewController.overrides = overrides
      // On reuse, `viewDidLoad` won't run again, so apply locale/appearance here.
      viewController.applyOverrides()
			await viewController.loadPreview()
			await UIViewController.topMostViewController?.present(
        viewController,
        animated: true
      )
		} else {
      let viewController = factory.makeDebugViewController(
        withDatabaseId: paywallDatabaseId,
        overrides: overrides
      )
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
