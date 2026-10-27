//
//  SK2ReceiptManagerPurchaseCorrectionTests.swift
//  SuperwallKitTests
//
// The subscription status is derived from purchases, so a purchase has to follow
// the subscription-level state StoreKit reports. In a billing grace period the
// latest transaction has expired, but Apple keeps the subscriber's access, so
// its purchase is corrected to active.
//
// swiftlint:disable all

import Foundation
import Testing
@testable import SuperwallKit

struct SK2ReceiptManagerPurchaseCorrectionTests {
  private let productId = "com.app.monthly"
  private let expiredAt = Date().addingTimeInterval(-3600)

  private var purchaseDate: Date {
    expiredAt.addingTimeInterval(-30 * 24 * 3600)
  }

  private func makeSubscription(
    isInGracePeriod: Bool,
    isActive: Bool
  ) -> SubscriptionTransaction {
    return SubscriptionTransaction(
      transactionId: "1",
      productId: productId,
      purchaseDate: purchaseDate,
      willRenew: true,
      isRevoked: false,
      isInGracePeriod: isInGracePeriod,
      isInBillingRetryPeriod: false,
      isActive: isActive,
      expirationDate: expiredAt
    )
  }

  private func makeEntitlements(isActive: Bool) -> [String: Set<Entitlement>] {
    return [
      productId: [
        Entitlement(
          id: "pro",
          isActive: isActive,
          productIds: [productId],
          store: .appStore,
          expiresAt: expiredAt,
          state: isActive ? .inGracePeriod : .expired
        )
      ]
    ]
  }

  @Test("An expired purchase in a billing grace period is corrected to active")
  func gracePeriodPurchaseIsActive() {
    let purchases: Set<Purchase> = [
      Purchase(id: productId, isActive: false, purchaseDate: purchaseDate)
    ]

    let corrected = SK2ReceiptManager.correctPurchases(
      purchases,
      entitlementsByProductId: makeEntitlements(isActive: true),
      subscriptions: [makeSubscription(isInGracePeriod: true, isActive: true)]
    )

    #expect(corrected == [Purchase(id: productId, isActive: true, purchaseDate: purchaseDate)])
  }

  @Test("Only the transaction in a grace period is corrected, not older renewals")
  func onlyGracePeriodTransactionIsCorrected() {
    let olderPurchaseDate = purchaseDate.addingTimeInterval(-30 * 24 * 3600)
    let purchases: Set<Purchase> = [
      Purchase(id: productId, isActive: false, purchaseDate: olderPurchaseDate),
      Purchase(id: productId, isActive: false, purchaseDate: purchaseDate)
    ]

    let corrected = SK2ReceiptManager.correctPurchases(
      purchases,
      entitlementsByProductId: makeEntitlements(isActive: true),
      subscriptions: [makeSubscription(isInGracePeriod: true, isActive: true)]
    )

    #expect(corrected == [
      Purchase(id: productId, isActive: false, purchaseDate: olderPurchaseDate),
      Purchase(id: productId, isActive: true, purchaseDate: purchaseDate)
    ])
  }

  @Test("An expired purchase outside a grace period stays inactive")
  func expiredPurchaseStaysInactive() {
    let purchases: Set<Purchase> = [
      Purchase(id: productId, isActive: false, purchaseDate: purchaseDate)
    ]

    let corrected = SK2ReceiptManager.correctPurchases(
      purchases,
      entitlementsByProductId: makeEntitlements(isActive: false),
      subscriptions: [makeSubscription(isInGracePeriod: false, isActive: false)]
    )

    #expect(corrected == purchases)
  }

  @Test("A purchase whose entitlements are all inactive is still corrected to inactive")
  func revokedPurchaseIsInactive() {
    let purchases: Set<Purchase> = [
      Purchase(id: productId, isActive: true, purchaseDate: purchaseDate)
    ]

    let corrected = SK2ReceiptManager.correctPurchases(
      purchases,
      entitlementsByProductId: makeEntitlements(isActive: false),
      subscriptions: [makeSubscription(isInGracePeriod: false, isActive: false)]
    )

    #expect(corrected == [Purchase(id: productId, isActive: false, purchaseDate: purchaseDate)])
  }
}
