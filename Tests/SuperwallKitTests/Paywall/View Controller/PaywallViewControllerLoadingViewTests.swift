//
//  PaywallViewControllerLoadingViewTests.swift
//  SuperwallKitTests
//

import Testing
import UIKit
@testable import SuperwallKit

@MainActor
struct PaywallViewControllerLoadingViewTests {
  private func makePaywallViewController(
    backgroundView: PaywallOptions.TransactionBackgroundView
  ) -> PaywallViewController {
    let dependencyContainer = DependencyContainer()
    let paywallCache = PaywallViewControllerCache(
      deviceLocaleString: dependencyContainer.deviceHelper.localeIdentifier
    )
    let paywallViewController = dependencyContainer.makePaywallViewController(
      for: .stub(),
      withCache: paywallCache,
      withPaywallArchiveManager: nil,
      delegate: nil
    )
    paywallViewController.transactionBackgroundView = { backgroundView }
    return paywallViewController
  }

  @Test(arguments: [PaywallLoadingState.loadingPurchase, .manualLoading])
  func spinner_addsLoadingView(state: PaywallLoadingState) {
    let paywallViewController = makePaywallViewController(backgroundView: .spinner)

    paywallViewController.loadingState = state

    let loadingView = paywallViewController.loadingViewController?.view
    #expect(loadingView != nil)
    #expect(loadingView?.superview === paywallViewController.view)
  }

  @Test(arguments: [PaywallLoadingState.loadingPurchase, .manualLoading])
  func none_neverAddsLoadingView(state: PaywallLoadingState) {
    let paywallViewController = makePaywallViewController(backgroundView: .none)

    paywallViewController.loadingState = state

    #expect(paywallViewController.loadingViewController == nil)
    #expect(paywallViewController.loadingState == state)
  }

  @Test
  func none_togglePaywallSpinnerKeepsLoadingStateWithoutView() {
    let paywallViewController = makePaywallViewController(backgroundView: .none)
    paywallViewController.loadingState = .ready

    paywallViewController.togglePaywallSpinner(isHidden: false)
    #expect(paywallViewController.loadingState == .manualLoading)
    #expect(paywallViewController.loadingViewController == nil)

    paywallViewController.togglePaywallSpinner(isHidden: true)
    #expect(paywallViewController.loadingState == .ready)
  }
}
