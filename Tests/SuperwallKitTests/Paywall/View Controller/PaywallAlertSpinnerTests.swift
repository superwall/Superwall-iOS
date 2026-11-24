//
//  PaywallAlertSpinnerTests.swift
//  SuperwallKit
//
//  Created by Superwall on 24/11/2026.
//
// swiftlint:disable all

import Foundation
import Testing
import UIKit
@testable import SuperwallKit

@Suite("A paywall alert that can't show")
@MainActor
struct PaywallAlertSpinnerTests {
  @Test("it still hides the purchase spinner")
  func alertThatCannotShowHidesTheSpinner() {
    let paywall = PresentingPaywallViewControllerMock.make()
    paywall.stubbedPresentedViewController = UIViewController()
    paywall.updateLoading(.purchaseStarted)
    #expect(paywall.store.read { $0.loadingState } == .loadingPurchase)

    paywall.showAlert(
      title: "Purchase failed",
      message: "Something went wrong",
      actionTitle: nil,
      closeActionTitle: "Done",
      action: nil
    )

    #expect(paywall.store.read { $0.loadingState } == .ready)
  }

  @Test("it leaves a page that's still loading alone")
  func alertThatCannotShowLeavesALoadingPageAlone() {
    let paywall = PresentingPaywallViewControllerMock.make()
    paywall.stubbedPresentedViewController = UIViewController()
    paywall.updateLoading(.webViewLoadStarted)
    #expect(paywall.store.read { $0.loadingState } == .loadingURL)

    paywall.showAlert(
      title: "Purchase failed",
      message: "Something went wrong",
      actionTitle: nil,
      closeActionTitle: "Done",
      action: nil
    )

    #expect(paywall.store.read { $0.loadingState } == .loadingURL)
  }

  @Test("it still reports the alert closed")
  func alertThatCannotShowReportsItClosed() {
    let paywall = PresentingPaywallViewControllerMock.make()
    paywall.stubbedPresentedViewController = UIViewController()
    var closes = 0

    paywall.presentAlert(title: "Title", onClose: { closes += 1 })

    #expect(closes == 1)
  }
}
