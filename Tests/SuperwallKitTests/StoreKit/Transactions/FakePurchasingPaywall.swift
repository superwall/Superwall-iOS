//
//  FakePurchasingPaywall.swift
//  SuperwallKit
//
//  Created by Superwall on 16/11/2026.
//
// swiftlint:disable all

import Foundation
@testable import SuperwallKit

/// A paywall that records what the purchase and restore flows ask of it.
@MainActor
final class FakePurchasingPaywall: PurchasingPaywall {
  var info: PaywallInfo = .empty()
  var introOfferToken: IntroOfferToken?
  var referenceName: String?
  private(set) var calls: [String] = []
  /// Also told of each call, to record it in order with a context's calls.
  private let log: ((String) -> Void)?

  init(log: ((String) -> Void)? = nil) {
    self.log = log
  }

  private func record(_ call: String) {
    calls.append(call)
    log?("paywall.\(call)")
  }

  /// The case name of an enum value, without what it carries.
  private func name<Value>(of value: Value) -> String {
    return String(String(describing: value).prefix { $0 != "(" })
  }

  func introOfferToken(forProductId productId: String) -> IntroOfferToken? {
    record("introOfferToken")
    return introOfferToken
  }

  func referenceName(forCacheKey cacheKey: String) -> String? {
    record("referenceName")
    return referenceName
  }

  func notify(of message: PaywallMessage) {
    record("notify:\(name(of: message))")
  }

  func updateLoading(_ change: PaywallLoadingChange) {
    record("updateLoading:\(name(of: change))")
  }

  func markPurchaseCompleted(_ product: StoreProduct) {
    record("markPurchaseCompleted")
  }

  func customStoreCheckoutFinished() {
    record("customStoreCheckoutFinished")
  }

  func showAlert(
    title: String,
    message: String,
    actionTitle: String?,
    closeActionTitle: String,
    action: (() -> Void)?
  ) {
    record("showAlert")
  }
}
