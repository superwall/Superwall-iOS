//
//  PaywallShownAgainWhileDismissingTests.swift
//  SuperwallKit
//
//  Created by Superwall on 06/11/2026.
//
// swiftlint:disable all

import Combine
import Foundation
import Testing
import UIKit
@testable import SuperwallKit

/// Counts how many times the app hears the paywall finished.
private final class FinishCountingDelegate: PaywallViewControllerDelegate {
  var results: [PaywallResult] = []

  func paywall(
    _ paywall: PaywallViewController,
    didFinishWith result: PaywallResult,
    shouldDismiss: Bool
  ) {
    results.append(result)
  }
}

/// A `getPaywall` view controller the app takes down and shows again straight
/// away, before the first dismissal has finished saving the page's state.
@Suite("A paywall shown again while its dismissal finishes")
@MainActor
struct PaywallShownAgainWhileDismissingTests {
  /// The view controller holds its dependencies unowned and starts tasks that
  /// outlive the test, so anything it depends on lives for the whole process.
  private static var retained: [AnyObject] = []

  private func makeViewController(
    delegate: FinishCountingDelegate,
    publisher: PassthroughSubject<PaywallState, Never>
  ) -> PaywallViewController {
    let container = DependencyContainer()
    Self.retained.append(container)
    Self.retained.append(delegate)
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
    let viewController = PaywallViewController(
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
    Self.retained.append(viewController)
    let adapter = PaywallViewControllerDelegateAdapter(swiftDelegate: delegate, objcDelegate: nil)
    Self.retained.append(adapter)
    let request = container.makePresentationRequest(
      .implicitTrigger(PlacementData(name: "placement", parameters: [:], createdAt: Date())),
      isDebuggerLaunched: false,
      isPaywallPresented: false,
      type: .getPaywall(adapter)
    )
    viewController.set(
      request: request,
      paywall: .stub(),
      paywallStatePublisher: publisher,
      unsavedOccurrence: nil
    )
    viewController.loadViewIfNeeded()
    return viewController
  }

  private func waitUntil(_ condition: () -> Bool) async {
    for _ in 0..<250 where !condition() {
      try? await Task.sleep(nanoseconds: 20_000_000)
    }
  }

  @Test("The first dismissal finishes for the first presentation only")
  func firstDismissalLeavesTheSecondPresentationAlone() async {
    let delegate = FinishCountingDelegate()
    let publisher = PassthroughSubject<PaywallState, Never>()
    var dismissedCount = 0
    let cancellable = publisher.sink { state in
      if case .dismissed = state {
        dismissedCount += 1
      }
    }
    defer { cancellable.cancel() }
    let viewController = makeViewController(delegate: delegate, publisher: publisher)

    viewController.viewWillAppear(false)
    viewController.viewDidAppear(false)
    #expect(viewController.isPresented)

    // Taken down and shown again before the first dismissal has finished.
    viewController.viewWillDisappear(false)
    viewController.viewDidDisappear(false)
    viewController.viewWillAppear(false)
    viewController.viewDidAppear(false)

    await waitUntil { dismissedCount == 1 }
    #expect(dismissedCount == 1)
    #expect(delegate.results.count == 1)
    // The second presentation is still on screen.
    #expect(viewController.isPresented)

    viewController.viewWillDisappear(false)
    viewController.viewDidDisappear(false)
    await waitUntil { dismissedCount == 2 }

    // Each presentation reports its own end, once.
    #expect(dismissedCount == 2)
    #expect(delegate.results.count == 2)
    #expect(!viewController.isPresented)
  }
}
