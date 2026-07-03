//
//  SK2ReceiptManagerTests.swift
//  SuperwallKitTests
//
// Regression tests for a bug where SK2 introductory-offer eligibility was cached
// in `SK2ReceiptManager` for the lifetime of the app process. The cache was never
// invalidated — it survived `reset()`, user identity switches, and purchases — so a
// paywall could show a free trial that Apple would not actually grant. The fix
// removes the cache and resolves eligibility live from StoreKit on every call.
//

import Foundation
import Testing
@testable import SuperwallKit

struct SK2ReceiptManagerTests {
  /// A lightweight StoreProduct to feed the manager. The injected resolvers in
  /// these tests ignore the product, so an SK1-backed mock product is sufficient.
  private func makeStoreProduct() -> StoreProduct {
    return StoreProduct(
      sk1Product: MockSkProduct(
        productIdentifier: "com.superwall.product",
        subscriptionGroupIdentifier: "group"
      ),
      entitlements: []
    )
  }

  @Test("isEligibleForIntroOffer re-queries StoreKit on every call and is never cached")
  func eligibilityIsNotCached() async {
    guard #available(iOS 15.0, *) else {
      return
    }
    // Returns `true` on the first call and `false` afterwards, simulating Apple's
    // eligibility flipping once the user has consumed their intro offer. A cache
    // would freeze the first `true` and return it forever.
    let calls = CallCounter()
    let manager = SK2ReceiptManager(
      resolveIntroOfferEligibility: { _ in
        await calls.increment() == 1
      }
    )
    let product = makeStoreProduct()

    let first = await manager.isEligibleForIntroOffer(product)
    let second = await manager.isEligibleForIntroOffer(product)

    #expect(first == true)
    #expect(second == false)
    // StoreKit must be consulted on each call rather than served from a cache.
    #expect(await calls.count == 2)
  }

  @Test("loadIntroOfferEligibility is a no-op and does not freeze a value for later reads")
  func loadDoesNotFreezeEligibility() async {
    guard #available(iOS 15.0, *) else {
      return
    }
    // Eligibility starts `true`, then becomes `false` (e.g. after the user starts a
    // trial). The old implementation called `isEligibleForIntroOffer` inside
    // `loadIntroOfferEligibility` and cached the result, so the later read returned a
    // stale `true`. The fixed implementation must reflect the current value.
    let eligibility = MutableFlag(value: true)
    let manager = SK2ReceiptManager(
      resolveIntroOfferEligibility: { _ in
        await eligibility.read()
      }
    )
    let product = makeStoreProduct()

    // `loadIntroOfferEligibility` is now a no-op — it must not consult the resolver
    // (the old code queried eligibility here and cached the result).
    await manager.loadIntroOfferEligibility(forProducts: [product])
    #expect(await eligibility.reads == 0)

    #expect(await manager.isEligibleForIntroOffer(product) == true)

    await eligibility.set(false)
    #expect(await manager.isEligibleForIntroOffer(product) == false)

    // One read per `isEligibleForIntroOffer` call — never served from a frozen value.
    #expect(await eligibility.reads == 2)
  }

  @Test("the default resolver runs the live StoreKit path end-to-end")
  func defaultResolverIsWired() async {
    guard #available(iOS 15.0, *) else {
      return
    }
    // No custom resolver, so the production default `liveIntroOfferEligibility(for:)`
    // runs. A StoreKit 1-backed product isn't an `SK2StoreProduct`, so the live path
    // short-circuits to `false` without touching StoreKit. This proves the default
    // resolver is wired through `init` and the no-cache path runs end-to-end.
    let manager = SK2ReceiptManager()
    let sk1BackedProduct = makeStoreProduct()
    #expect(await manager.isEligibleForIntroOffer(sk1BackedProduct) == false)
  }
}

private actor CallCounter {
  private(set) var count = 0

  func increment() -> Int {
    count += 1
    return count
  }
}

private actor MutableFlag {
  private(set) var value: Bool
  private(set) var reads = 0

  init(value: Bool) {
    self.value = value
  }

  func read() -> Bool {
    reads += 1
    return value
  }

  func set(_ newValue: Bool) {
    value = newValue
  }
}
