//
//  PresentingPaywallViewControllerMock.swift
//  SuperwallKit
//
//  Created by Superwall on 24/11/2026.
//
// swiftlint:disable all

import UIKit
@testable import SuperwallKit

/// A real paywall view controller that isn't on screen, with its view loaded
/// and its page marked as ready. It can be made to look as if it's presenting
/// something.
final class PresentingPaywallViewControllerMock: PaywallViewController {
  /// The view controller holds its dependencies unowned and starts tasks that
  /// outlive the test, so anything it depends on lives for the whole process.
  private static var retained: [AnyObject] = []

  /// What the paywall says it's presenting, if anything.
  var stubbedPresentedViewController: UIViewController?

  override var presentedViewController: UIViewController? {
    return stubbedPresentedViewController ?? super.presentedViewController
  }

  /// Loads no page, so nothing the web view reports changes the loading state
  /// during a test.
  override func loadWebView() {}

  static func make() -> PresentingPaywallViewControllerMock {
    let container = DependencyContainer()
    retained.append(container)
    let webView = SWWebView(
      isiOSAppOnMac: false,
      messageHandler: PaywallMessageHandler(
        receiptManager: container.receiptManager,
        factory: container,
        permissionHandler: FakePermissionHandler(),
        customCallbackRegistry: container.customCallbackRegistry
      ),
      isOnDeviceCacheEnabled: true,
      factory: container
    )
    let viewController = PresentingPaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: container.deviceHelper,
      factory: container,
      storage: container.storage,
      network: container.network,
      webView: webView,
      webEntitlementRedeemer: container.webEntitlementRedeemer,
      cache: nil,
      paywallArchiveManager: nil,
      customCallbackRegistry: container.customCallbackRegistry
    )
    retained.append(viewController)
    viewController.loadViewIfNeeded()
    viewController.updateLoading(.webContentLoaded)
    return viewController
  }
}
