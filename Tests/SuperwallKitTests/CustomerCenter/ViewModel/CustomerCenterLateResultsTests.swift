//
//  CustomerCenterLateResultsTests.swift
//
//
//  Created by Yusuf Tör on 15/10/2026.
//

import Testing
import Foundation
@testable import SuperwallKit

/// Answers that arrive after the screen has moved on: a purchase changed under an open detail
/// screen, a sheet whose screen was left while it was being prepared, and StoreKit taking too long
/// to describe the products.
@Suite("Customer Center late results")
@MainActor
struct CustomerCenterLateResultsTests {
  private static let now = Date()
  private let monthly = ProductDisplayInfo(
    productId: "monthly",
    title: "Monthly",
    localizedPrice: "$9.99",
    price: 9.99,
    localizedPeriod: "month",
    subscriptionGroupId: "g1",
    isAutoRenewable: true
  )

  private func sub(willRenew: Bool = true) -> SubscriptionTransaction {
    SubscriptionTransaction(
      transactionId: "t1",
      productId: "monthly",
      purchaseDate: Self.now.addingTimeInterval(-86_400),
      willRenew: willRenew,
      isRevoked: false,
      isInGracePeriod: false,
      isInBillingRetryPeriod: false,
      isActive: true,
      expirationDate: Self.now.addingTimeInterval(12 * 86_400),
      offerType: nil,
      subscriptionGroupId: "g1",
      store: .appStore
    )
  }

  private func info(_ subs: [SubscriptionTransaction]) -> CustomerInfo {
    CustomerInfo(subscriptions: subs, nonSubscriptions: [], entitlements: [])
  }

  private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
      try? await Task.sleep(nanoseconds: 20_000_000)
    }
  }

  private func makeLoaded(
    lookup: StoreKitTransactionLookupMock = StoreKitTransactionLookupMock(),
    tracker: CustomerCenterEventTracking = EventTrackerMock()
  ) async -> (CustomerCenterViewModel, CustomerInfoProviderMock) {
    let infoMock = CustomerInfoProviderMock(info([sub()]))
    let products = ProductsProviderMock()
    products.products = ["monthly": monthly]
    let deps = CustomerCenterDependencies(
      customerInfo: infoMock,
      products: products,
      restore: RestorerMock(),
      urlOpener: URLOpenerMock(),
      tracker: tracker,
      environment: EnvironmentMock(),
      transactionLookup: lookup,
      appStoreVersion: AppStoreVersionProviderMock()
    )
    let viewModel = CustomerCenterViewModel(configuration: .default, dependencies: deps, strings: .english)
    await viewModel.load()
    return (viewModel, infoMock)
  }

  // MARK: - The detail screen follows the purchase

  /// A detail screen pushed onto the host's navigation controller keeps the purchase it was built
  /// with. After cancelling in Apple's sheet it has to show the cancellation, not the old renewal.
  @Test("the detail screen shows the purchase as it is now, not as it was when it opened")
  func detailFollowsTheCurrentPurchase() async throws {
    let (viewModel, infoMock) = await makeLoaded()
    let opened = try #require(viewModel.purchases.first)
    #expect(opened.statusLine.hasPrefix("Renews on"))

    viewModel.sheet = .manageSubscriptions(groupId: "g1")
    infoMock.subject.value = info([sub(willRenew: false)])
    viewModel.sheet = nil
    await viewModel.sheetDidDismiss()
    await waitUntil { viewModel.purchases.first?.badge == .cancelled }

    let content = viewModel.detailContent(for: opened)
    #expect(content.purchase.badge == .cancelled)
    #expect(!content.purchase.statusLine.hasPrefix("Renews on"))
    #expect(opened.statusLine.hasPrefix("Renews on"), "the copy the screen was built with is the stale one")
  }

  @Test("a purchase that's no longer listed keeps its card but offers nothing to do")
  func detailForAPurchaseThatWentAway() async throws {
    let (viewModel, infoMock) = await makeLoaded()
    let opened = try #require(viewModel.purchases.first)
    #expect(viewModel.detailContent(for: opened).emptyState == nil)

    infoMock.subject.send(info([]))
    await waitUntil { viewModel.purchases.isEmpty }

    let content = viewModel.detailContent(for: opened)
    #expect(content.purchase == opened)
    #expect(content.emptyState == .nothingToDo)
  }

  // MARK: - A sheet stays with the screen that asked for it

  /// The user asks for a refund on the detail screen and goes back while the transaction is being
  /// looked up. The refund sheet must not then open on the root.
  @Test("a refund whose screen was left during the lookup doesn't open")
  func refundDroppedWhenItsScreenLeaves() async throws {
    let lookup = StoreKitTransactionLookupMock()
    lookup.transactionIDs["monthly"] = 7
    lookup.holdsTransactionLookup = true
    let (viewModel, _) = await makeLoaded(lookup: lookup)
    let purchase = try #require(viewModel.purchases.first)
    let refund = try #require(
      viewModel.paths(for: purchase, isScreenLevel: false).first { $0.path.id == "refund" }
    )
    let detail = UUID()
    viewModel.claimPushedSurface(detail, depth: 1)

    let selecting = Task { await viewModel.select(refund, purchase: purchase) }
    await waitUntil { lookup.isHoldingTransactionLookup }
    viewModel.releasePushedSurface(detail)
    lookup.releaseTransactionLookup()
    await selecting.value

    #expect(viewModel.sheet == nil, "the refund sheet opened after the user had gone back")
    #expect(viewModel.pendingRefundProductId == nil)
  }

  @Test("a refund whose screen is still on top opens when the lookup answers")
  func refundOpensWhenItsScreenStays() async throws {
    let lookup = StoreKitTransactionLookupMock()
    lookup.transactionIDs["monthly"] = 7
    lookup.holdsTransactionLookup = true
    let (viewModel, _) = await makeLoaded(lookup: lookup)
    let purchase = try #require(viewModel.purchases.first)
    let refund = try #require(
      viewModel.paths(for: purchase, isScreenLevel: false).first { $0.path.id == "refund" }
    )
    viewModel.claimPushedSurface(UUID(), depth: 1)

    let selecting = Task { await viewModel.select(refund, purchase: purchase) }
    await waitUntil { lookup.isHoldingTransactionLookup }
    lookup.releaseTransactionLookup()
    await selecting.value

    #expect(viewModel.sheet == .refund(transactionId: 7, productId: "monthly"))
    #expect(viewModel.sheetOwnerDepth == 1)
    #expect(viewModel.pendingRefundProductId == "monthly")
  }

  /// The same wait happens before any sheet: the action is tracked first.
  @Test("a survey whose screen was left while the tap was being tracked doesn't open")
  func surveyDroppedWhenItsScreenLeaves() async throws {
    let tracker = GatedTrackerMock()
    let (viewModel, _) = await makeLoaded(tracker: tracker)
    let purchase = try #require(viewModel.purchases.first)
    let cancel = try #require(
      viewModel.paths(for: purchase, isScreenLevel: false).first { $0.path.id == "manage_subscription" }
    )
    let detail = UUID()
    viewModel.claimPushedSurface(detail, depth: 1)

    tracker.holdsNextEvent = true
    let selecting = Task { await viewModel.select(cancel, purchase: purchase) }
    await waitUntil { tracker.isHolding }
    viewModel.releasePushedSurface(detail)
    tracker.release()
    await selecting.value

    #expect(viewModel.sheet == nil, "the survey opened after the user had gone back")
    #expect(viewModel.pendingSurvey == nil)
  }

  // MARK: - StoreKit doesn't hold the screen

  /// Offline, the StoreKit products lookup retries for about half a minute. The purchases are
  /// already known, so the screen draws without product details and fills them in later.
  @Test("a slow StoreKit lookup doesn't keep the screen loading, and fills in when it answers")
  func slowStoreKitDoesNotHoldTheScreen() async {
    let products = GatedProductsProviderMock()
    products.products = ["monthly": monthly]
    let deps = CustomerCenterDependencies(
      customerInfo: CustomerInfoProviderMock(info([sub()])),
      products: products,
      restore: RestorerMock(),
      urlOpener: URLOpenerMock(),
      tracker: EventTrackerMock(),
      environment: EnvironmentMock(),
      transactionLookup: StoreKitTransactionLookupMock(),
      appStoreVersion: AppStoreVersionProviderMock()
    )
    let viewModel = CustomerCenterViewModel(
      configuration: .default,
      dependencies: deps,
      strings: .english,
      storeKitProductsWait: 0.1
    )

    let loading = Task { await viewModel.load() }
    await waitUntil(timeout: 2) { viewModel.state != .loading }
    #expect(viewModel.state == .management, "the screen waited on StoreKit before drawing")
    #expect(viewModel.purchases.map(\.id) == ["monthly"])
    #expect(viewModel.purchases.first?.title == nil)

    products.release()
    await loading.value
    await waitUntil { viewModel.purchases.first?.title == "Monthly" }
    #expect(viewModel.purchases.first?.title == "Monthly")
    #expect(viewModel.purchases.first?.priceLine == "$9.99 / month")
  }
}

/// Holds the next tracked event until `release()`.
private final class GatedTrackerMock: CustomerCenterEventTracking {
  var holdsNextEvent = false
  private(set) var isHolding = false
  private var gate: CheckedContinuation<Void, Never>?

  func track(_ event: Trackable) async {
    if !holdsNextEvent {
      return
    }
    holdsNextEvent = false
    await withCheckedContinuation { continuation in
      gate = continuation
      isHolding = true
    }
  }

  func release() {
    gate?.resume()
    gate = nil
  }
}
