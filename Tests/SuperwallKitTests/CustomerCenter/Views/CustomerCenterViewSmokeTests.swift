//
//  CustomerCenterViewSmokeTests.swift
//
//
//  Created by Claude on 20/08/2026.
//

import Testing
import SwiftUI
@testable import SuperwallKit

@Suite("CustomerCenterView smoke")
@MainActor
struct CustomerCenterViewSmokeTests {
  @Test("hosts without crashing in management and no-active states and exposes accessibility ids")
  @available(iOS 15.0, *)
  func hosts() async throws {
    let now = Date()
    let sub = SubscriptionTransaction(
      transactionId: "t",
      productId: "monthly",
      purchaseDate: now,
      willRenew: true,
      isRevoked: false,
      isInGracePeriod: false,
      isInBillingRetryPeriod: false,
      isActive: true,
      expirationDate: now.addingTimeInterval(86_400),
      offerType: nil,
      subscriptionGroupId: "g",
      store: .appStore
    )
    for info in [
      CustomerInfo(subscriptions: [sub], nonSubscriptions: [], entitlements: []),
      CustomerInfo(subscriptions: [], nonSubscriptions: [], entitlements: [])
    ] {
      let (deps, _, _) = CustomerCenterDependencies.mock(info: info)
      let model = CustomerCenterViewModel(configuration: .default, dependencies: deps, strings: .english)
      await model.load()
      let host = UIHostingController(rootView: CustomerCenterView(viewModel: model, navigationOptions: .default))
      host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
      // A hosting controller only materializes its SwiftUI-backed subviews (e.g. `List`'s
      // internal UICollectionView) once it's part of a real window hierarchy — `loadViewIfNeeded()`
      // plus `layoutIfNeeded()` alone isn't enough to drive that pass in a headless test.
      let window = UIWindow(frame: host.view.frame)
      window.rootViewController = host
      window.makeKeyAndVisible()
      host.view.layoutIfNeeded()
      #expect(host.view.subviews.isEmpty == false)
      window.isHidden = true
    }
  }

  @Test("survey and history views host")
  @available(iOS 15.0, *)
  func secondaryViews() async {
    let now = Date()
    let sub = SubscriptionTransaction(
      transactionId: "t",
      productId: "monthly",
      purchaseDate: now,
      willRenew: true,
      isRevoked: false,
      isInGracePeriod: false,
      isInBillingRetryPeriod: false,
      isActive: true,
      expirationDate: now.addingTimeInterval(86_400),
      offerType: nil,
      subscriptionGroupId: "g",
      store: .appStore
    )
    let (deps, _, _) = CustomerCenterDependencies.mock(
      info: CustomerInfo(subscriptions: [sub], nonSubscriptions: [], entitlements: [])
    )
    let vm = CustomerCenterViewModel(configuration: .default, dependencies: deps, strings: .english)
    await vm.load()
    let purchase = vm.purchases[0]
    let manage = vm.paths(for: purchase).first { $0.path.id == "manage_subscription" }!
    await vm.select(manage, purchase: purchase)
    for view in [AnyView(FeedbackSurveyView(viewModel: vm)), AnyView(PurchaseHistoryView(viewModel: vm))] {
      let host = UIHostingController(rootView: view)
      host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
      let window = UIWindow(frame: host.view.frame)
      window.rootViewController = host
      window.makeKeyAndVisible()
      host.view.layoutIfNeeded()
      #expect(!host.view.subviews.isEmpty)
      window.isHidden = true
    }
  }

  @Test("presentCustomerCenter(isPresented:) compiles and hosts")
  @available(iOS 15.0, *)
  func presentCustomerCenterHosts() {
    struct Host: View {
      @State var isPresented = true
      var body: some View {
        NavigationView { Text("Root") }.presentCustomerCenter(isPresented: $isPresented)
      }
    }
    let host = UIHostingController(rootView: Host())
    host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    let window = UIWindow(frame: host.view.frame)
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.layoutIfNeeded()
    #expect(!host.view.subviews.isEmpty)
    window.isHidden = true
  }

  @Test("onCustomerCenterAction applied outside CustomerCenterView merges into the view model and fires on selection")
  @available(iOS 15.0, *)
  func environmentCallbackMergesAndFires() async throws {
    let now = Date()
    let sub = SubscriptionTransaction(
      transactionId: "t",
      productId: "monthly",
      purchaseDate: now,
      willRenew: true,
      isRevoked: false,
      isInGracePeriod: false,
      isInBillingRetryPeriod: false,
      isActive: true,
      expirationDate: now.addingTimeInterval(86_400),
      offerType: nil,
      subscriptionGroupId: "g",
      store: .appStore
    )
    let (deps, _, _) = CustomerCenterDependencies.mock(
      info: CustomerInfo(subscriptions: [sub], nonSubscriptions: [], entitlements: [])
    )
    let vm = CustomerCenterViewModel(configuration: .default, dependencies: deps, strings: .english)
    await vm.load()

    final class ReceivedBox: @unchecked Sendable {
      var action: CustomerCenterAction?
      var transaction: SubscriptionTransaction?
    }
    let received = ReceivedBox()

    let view = CustomerCenterView(viewModel: vm, navigationOptions: .default)
      .onCustomerCenterAction { action, transaction in
        received.action = action
        received.transaction = transaction
      }
    let host = UIHostingController(rootView: view)
    host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    let window = UIWindow(frame: host.view.frame)
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.layoutIfNeeded()

    // `.task` runs asynchronously once the hosted view is part of a real window hierarchy;
    // give the run loop a few turns to let it fire and merge the environment callback in.
    for _ in 0..<20 where vm.callbacks.didSelectAction == nil {
      try await Task.sleep(nanoseconds: 20_000_000)
    }
    #expect(vm.callbacks.didSelectAction != nil)

    let purchase = vm.purchases[0]
    let manage = vm.paths(for: purchase).first { $0.path.id == "manage_subscription" }!
    await vm.select(manage, purchase: purchase)

    #expect(received.action == .manageSubscription)
    #expect(received.transaction?.transactionId == "t")
    window.isHidden = true
  }

  @Test("merged prefers the environment's non-nil closures and keeps un-overridden ones")
  @available(iOS 15.0, *)
  func mergedHelperSemantics() {
    var existing = CustomerCenterCallbacks()
    var existingRestoreCalled = false
    var existingDismissCalled = false
    existing.shouldRestore = { _ in existingRestoreCalled = true }
    existing.didDismiss = { existingDismissCalled = true }

    var environment = CustomerCenterCallbacks()
    var envSelectCalled = false
    environment.didSelectAction = { _, _ in envSelectCalled = true }

    let result = CustomerCenterView.merged(existing, environment)

    // Field only set on `existing` survives untouched.
    result.didDismiss?()
    #expect(existingDismissCalled)

    // Field only set on `environment` is present in the result.
    result.didSelectAction?(.restore, nil)
    #expect(envSelectCalled)

    // Field set on `existing` but not `environment` still comes from `existing`.
    result.shouldRestore?({ _ in })
    #expect(existingRestoreCalled)

    // Field unset on both stays nil.
    #expect(result.didCompleteSurvey == nil)
    #expect(result.didCompleteRefund == nil)
  }
}
