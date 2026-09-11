//
//  PurchaseDetailActionsTests.swift
//
//
//  Created by Jordan Morgan on 11/09/2026.
//

import Testing
import Foundation
@testable import SuperwallKit

/// Every subscription row opens its detail screen. These pin what that screen has to say once
/// it is open, driven from the shipped `.default` configuration — no support email, no web
/// management URL — because that is the configuration under which several realistic purchases
/// resolve to no actions at all, and a heading over an empty list is not an acceptable answer.
@Suite("Purchase detail: actions or an explanation")
@MainActor
struct PurchaseDetailActionsTests {
  private func subscription(
    store: ProductStore = .appStore,
    isActive: Bool = true,
    isRevoked: Bool = false
  ) -> SubscriptionTransaction {
    SubscriptionTransaction(
      transactionId: "t1",
      productId: "pro_monthly",
      purchaseDate: Date().addingTimeInterval(-30 * 86_400),
      willRenew: isActive,
      isRevoked: isRevoked,
      isInGracePeriod: false,
      isInBillingRetryPeriod: false,
      isActive: isActive,
      expirationDate: Date().addingTimeInterval(isActive ? 12 * 86_400 : -86_400),
      subscriptionGroupId: "group_pro",
      store: store
    )
  }

  @available(iOS 15.0, *)
  private func makeViewModel(
    subscriptions: [SubscriptionTransaction] = [],
    entitlements: [Entitlement] = []
  ) async -> CustomerCenterViewModel {
    let (deps, _, _) = CustomerCenterDependencies.mock(
      info: CustomerInfo(subscriptions: subscriptions, nonSubscriptions: [], entitlements: entitlements)
    )
    let viewModel = CustomerCenterViewModel(
      configuration: .default,
      dependencies: deps,
      strings: .english
    )
    await viewModel.load()
    return viewModel
  }

  @available(iOS 15.0, *)
  private func hasActions(_ viewModel: CustomerCenterViewModel) throws -> Bool {
    let purchase = try #require(viewModel.purchases.first, "the row exists — nothing is hidden")
    return viewModel.hasActions(for: purchase)
  }

  /// The shapes the last review found opening onto an empty "Actions" section.
  @available(iOS 15.0, *)
  @Test("a revoked App Store subscription has nothing to act on")
  func revokedAppStoreHasNoActions() async throws {
    let viewModel = await makeViewModel(subscriptions: [subscription(isRevoked: true)])
    #expect(try !hasActions(viewModel))
  }

  @available(iOS 15.0, *)
  @Test("a lapsed web subscription has nothing to act on")
  func lapsedWebHasNoActions() async throws {
    let viewModel = await makeViewModel(subscriptions: [subscription(store: .stripe, isActive: false)])
    #expect(try !hasActions(viewModel))
  }

  @available(iOS 15.0, *)
  @Test("a purchase from another store has nothing to act on", arguments: [ProductStore.playStore, .other])
  func otherStoreHasNoActions(store: ProductStore) async throws {
    let viewModel = await makeViewModel(subscriptions: [subscription(store: store)])
    #expect(try !hasActions(viewModel))
  }

  @available(iOS 15.0, *)
  @Test("a comped grant with no management page has nothing to act on")
  func compedGrantHasNoActions() async throws {
    let viewModel = await makeViewModel(entitlements: [Entitlement(id: "pro", store: nil)])
    #expect(try !hasActions(viewModel))
  }

  /// And the shapes that do have somewhere to go, so the explanation isn't shown by mistake.
  @available(iOS 15.0, *)
  @Test("an active App Store subscription has actions")
  func activeAppStoreHasActions() async throws {
    let viewModel = await makeViewModel(subscriptions: [subscription()])
    #expect(try hasActions(viewModel))
  }

  /// A live web subscription with no management URL still gets the row that explains where the
  /// link is — that was fixed once already, and this keeps it from being read as "nothing to do".
  @available(iOS 15.0, *)
  @Test("an active web subscription has the management row even with no URL")
  func activeWebHasActions() async throws {
    let viewModel = await makeViewModel(subscriptions: [subscription(store: .stripe)])
    #expect(try hasActions(viewModel))
  }
}
