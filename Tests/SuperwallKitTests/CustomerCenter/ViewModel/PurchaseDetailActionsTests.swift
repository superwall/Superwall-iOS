//
//  PurchaseDetailActionsTests.swift
//
//
//  Created by Jordan Morgan on 11/09/2026.
//

import Testing
import Foundation
@testable import SuperwallKit

/// Every subscription row opens its detail screen. These pin what that screen has to say once it
/// is open, driven from the shipped `.default` configuration — no support email, no web
/// management URL — because that is the configuration under which several realistic purchases
/// resolve to no actions at all. What the screen says then depends on *why* there are none: a
/// customer still paying for a subscription this SDK can't drive must be told where to manage
/// it, never that there is nothing to manage.
@Suite("Purchase detail: actions, or the right explanation")
@MainActor
struct PurchaseDetailActionsTests {
  typealias EmptyState = CustomerCenterViewModel.DetailEmptyState

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
  private func emptyState(_ viewModel: CustomerCenterViewModel) throws -> EmptyState? {
    let purchase = try #require(viewModel.purchases.first, "the row exists — nothing is hidden")
    return viewModel.detailEmptyState(for: purchase)
  }

  // MARK: Genuinely nothing to do

  @available(iOS 15.0, *)
  @Test("a revoked App Store subscription: nothing to do")
  func revokedAppStore() async throws {
    let viewModel = await makeViewModel(subscriptions: [subscription(isRevoked: true)])
    #expect(try emptyState(viewModel) == .nothingToDo)
  }

  @available(iOS 15.0, *)
  @Test("a lapsed web subscription: nothing to do")
  func lapsedWeb() async throws {
    let viewModel = await makeViewModel(subscriptions: [subscription(store: .stripe, isActive: false)])
    #expect(try emptyState(viewModel) == .nothingToDo)
  }

  @available(iOS 15.0, *)
  @Test("a comped grant with no management page: nothing to do")
  func compedGrant() async throws {
    let viewModel = await makeViewModel(entitlements: [Entitlement(id: "pro", store: nil)])
    #expect(try emptyState(viewModel) == .nothingToDo)
  }

  /// A lifetime grant from a store this SDK can't drive is not "managed elsewhere": nothing
  /// renews, so there is nothing to manage anywhere, and the card's "Lifetime" badge would sit
  /// over a sentence about a subscription. Liveness alone isn't the test; renewal is.
  @available(iOS 15.0, *)
  @Test("a lifetime Play Store grant: nothing to do, not a subscription to manage elsewhere")
  func lifetimePlayStoreGrant() async throws {
    let lifetime = Entitlement(id: "pro", isActive: true, store: .playStore, isLifetime: true)
    let viewModel = await makeViewModel(entitlements: [lifetime])
    let purchase = try #require(viewModel.purchases.first)
    #expect(purchase.badge == .lifetime, "the shape under test")
    #expect(viewModel.detailEmptyState(for: purchase) == .nothingToDo)
  }

  // MARK: Still paying, but not here

  /// The shape the last review caught: an active Play Store subscription on an iOS client. Its
  /// card reads "Active — renews on …", so "nothing to manage" would be a lie. The store has a
  /// name, and the sentence uses it.
  @available(iOS 15.0, *)
  @Test("a live Play Store subscription is managed elsewhere, by name")
  func livePlayStore() async throws {
    let viewModel = await makeViewModel(subscriptions: [subscription(store: .playStore)])
    #expect(try emptyState(viewModel) == .managedElsewhere(storeLabelKey: "customer_center_store_google_play"))
  }

  @available(iOS 15.0, *)
  @Test("a live subscription from an unnamed store is managed elsewhere, generically")
  func liveOtherStore() async throws {
    let viewModel = await makeViewModel(subscriptions: [subscription(store: .other)])
    #expect(try emptyState(viewModel) == .managedElsewhere(storeLabelKey: nil))
  }

  /// A lapsed Play Store subscription is not "managed elsewhere" — there is nothing left to
  /// manage anywhere. Liveness, not store, decides between the two sentences.
  @available(iOS 15.0, *)
  @Test("a lapsed Play Store subscription: nothing to do")
  func lapsedPlayStore() async throws {
    let viewModel = await makeViewModel(subscriptions: [subscription(store: .playStore, isActive: false)])
    #expect(try emptyState(viewModel) == .nothingToDo)
  }

  // MARK: Has actions, so no explanation at all

  @available(iOS 15.0, *)
  @Test("an active App Store subscription has actions")
  func activeAppStore() async throws {
    let viewModel = await makeViewModel(subscriptions: [subscription()])
    #expect(try emptyState(viewModel) == nil)
  }

  /// A live web subscription with no management URL still gets the row that explains where the
  /// link is — fixed once already, and this keeps it from being read as an empty state.
  @available(iOS 15.0, *)
  @Test("an active web subscription has the management row even with no URL")
  func activeWeb() async throws {
    let viewModel = await makeViewModel(subscriptions: [subscription(store: .stripe)])
    #expect(try emptyState(viewModel) == nil)
  }
}
