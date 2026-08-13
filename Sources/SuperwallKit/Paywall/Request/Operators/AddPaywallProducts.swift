// swiftlint:disable file_length
//
//  File.swift
//
//
//  Created by Yusuf Tör on 12/05/2023.
//
import Foundation

extension PaywallRequestManager {
  func addProducts(
    to paywall: Paywall,
    request: PaywallRequest
  ) async throws -> Paywall {
    var paywall = paywall

    paywall = await trackProductsLoadStart(
      paywall: paywall,
      request: request
    )
    paywall = try await getProducts(
      for: paywall,
      request: request
    )
    paywall = await trackProductsLoadFinish(
      paywall: paywall,
      placement: request.placementData
    )

    return paywall
  }

  private func getProducts(for paywall: Paywall, request: PaywallRequest) async throws -> Paywall {
    var paywall = paywall

    // Pre-populate custom products from the Superwall API before fetching
    // App Store products so they're already cached in productsById.
    let customProducts = paywall.customProducts
    if !customProducts.isEmpty {
      await fetchAndCacheCustomProducts(customProducts)
    }

    do {
      let result = try await storeKitManager.getProducts(
        forPaywall: paywall,
        placement: request.placementData,
        substituting: request.overrides.products,
        isTestMode: factory.isTestMode
      )

      paywall.products = result.productItems

      // Merge custom products into the composite-keyed map so they appear in
      // product variables and templating. Custom products have unique IDs,
      // so composite ID == Apple ID for them and the lookup is direct.
      var mergedProductsByCompositeId = result.productsByCompositeId
      for product in customProducts {
        if let cached = await storeKitManager.productsById[product.id] {
          mergedProductsByCompositeId[product.id] = cached
        }
      }

      let outcome = PaywallLogic.getProductVariables(
        productItems: result.productItems,
        productsById: mergedProductsByCompositeId
      )
      paywall.productVariables = outcome.productVariables

      return paywall
    } catch {
      paywall.productsLoadingInfo.failAt = Date()
      let paywallInfo = paywall.getInfo(fromPlacement: request.placementData)

      if let productFetchingError = error as? ProductFetchingError,
        case .noProductsFound(let identifiers) = productFetchingError {
        await trackProductLoadMissingProducts(
          paywallInfo: paywallInfo,
          placement: request.placementData,
          identifiers: identifiers
        )
      } else {
        await trackProductLoadFail(
          paywallInfo: paywallInfo,
          placement: request.placementData,
          error: error
        )
      }
      return paywall
    }
  }

  // MARK: - Custom Products

  /// Fetches custom products from the Superwall API and caches them in
  /// `storeKitManager.productsById` so they can be used for templating.
  private func fetchAndCacheCustomProducts(_ customProducts: [Product]) async {
    var duplicateCustomProductIds = Set<String>()
    let customProductsById = customProducts.reduce(into: [String: Product]()) { result, product in
      if result.updateValue(product, forKey: product.id) != nil {
        duplicateCustomProductIds.insert(product.id)
      }
    }

    if !duplicateCustomProductIds.isEmpty {
      let duplicateIds = duplicateCustomProductIds.sorted().joined(separator: ", ")
      Logger.debug(
        logLevel: .warn,
        scope: .productsManager,
        message: "Paywall contains duplicate custom product ids: \(duplicateIds). Using the last occurrence."
      )
    }

    let cachedProductsById = await storeKitManager.productsById
    let idsNeedingRefresh = Set(
      customProductsById.compactMap { id, productItem in
        guard let cached = cachedProductsById[id] else {
          return id
        }
        guard cached.isCustomProduct else {
          return id
        }
        return cached.entitlements == productItem.entitlements ? nil : id
      }
    )

    if idsNeedingRefresh.isEmpty {
      return
    }

    do {
      let response = try await network.getSuperwallProducts()
      for superwallProduct in response.data where idsNeedingRefresh.contains(superwallProduct.identifier) {
        guard let productItem = customProductsById[superwallProduct.identifier] else {
          continue
        }
        let testProduct = APIStoreProduct(
          superwallProduct: superwallProduct,
          entitlements: productItem.entitlements
        )
        let storeProduct = StoreProduct(customProduct: testProduct)
        await storeKitManager.setProduct(
          storeProduct,
          forIdentifier: superwallProduct.identifier
        )
      }
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .productsManager,
        message: "Failed to fetch custom products from API",
        error: error
      )
    }
  }

  // MARK: - Analytics
  private func trackProductsLoadStart(paywall: Paywall, request: PaywallRequest) async -> Paywall {
    var paywall = paywall
    paywall.productsLoadingInfo.startAt = Date()
    let paywallInfo = paywall.getInfo(fromPlacement: request.placementData)
    let productsLoad = InternalSuperwallEvent.PaywallProductsLoad(
      state: .start,
      paywallInfo: paywallInfo,
      placementData: request.placementData
    )
    await Superwall.shared.track(productsLoad)

    return paywall
  }

  private func trackProductLoadFail(
    paywallInfo: PaywallInfo,
    placement: PlacementData?,
    error: Error
  ) async {
    let productLoad = InternalSuperwallEvent.PaywallProductsLoad(
      state: .fail(error),
      paywallInfo: paywallInfo,
      placementData: placement
    )
    await Superwall.shared.track(productLoad)
  }

  private func trackProductLoadMissingProducts(
    paywallInfo: PaywallInfo,
    placement: PlacementData?,
    identifiers: Set<String>
  ) async {
    let productLoad = InternalSuperwallEvent.PaywallProductsLoad(
      state: .missingProducts(identifiers),
      paywallInfo: paywallInfo,
      placementData: placement
    )
    await Superwall.shared.track(productLoad)
  }

  private func trackProductsLoadFinish(
    paywall: Paywall,
    placement: PlacementData?
  ) async -> Paywall {
    var paywall = paywall
    paywall.productsLoadingInfo.endAt = Date()
    let paywallInfo = paywall.getInfo(fromPlacement: placement)
    let productsLoad = InternalSuperwallEvent.PaywallProductsLoad(
      state: .complete,
      paywallInfo: paywallInfo,
      placementData: placement
    )
    await Superwall.shared.track(productsLoad)

    return paywall
  }

  // MARK: - Free Trial Refresh

  /// Recalculates `isFreeTrialAvailable` and `isFreeTrialAvailableByProductName`
  /// for a paywall.
  ///
  /// This is called both for freshly loaded paywalls and cached paywalls to ensure
  /// trial eligibility reflects the user's current entitlement/subscription state.
  func refreshFreeTrialAvailability(
    for paywall: Paywall,
    request: PaywallRequest
  ) async -> Paywall {
    var paywall = paywall

    // Test mode overrides take highest precedence, followed by the developer
    // override. When forced, the paywall-level flag takes the forced value
    // verbatim and per-product availability is gated by whether the product
    // has an intro offer at all.
    var forcedAvailability: Bool?
    if factory.isTestMode {
      switch factory.testModeFreeTrialOverride {
      case .forceAvailable:
        forcedAvailability = true
      case .forceUnavailable:
        forcedAvailability = false
      case .useDefault:
        break
      }
    }
    if forcedAvailability == nil,
      let override = request.overrides.isFreeTrial {
      forcedAvailability = override
    }

    // Lookup uses the composite-keyed map so billing-plan-specific Superwall
    // Products resolve to the right clone. Falls back to the Apple-ID-keyed
    // map for products loaded outside the paywall flow (e.g. preloaded
    // overrides).
    let productsByCompositeId = await storeKitManager.productsByCompositeId
    let productsByAppleId = await storeKitManager.productsById

    var isFreeTrialAvailableByProductName: [String: Bool] = [:]
    var isFreeTrialAvailable = false

    for productItem in paywall.products {
      let isAvailable = await freeTrialAvailability(
        for: productItem,
        forcedAvailability: forcedAvailability,
        introOfferEligibility: paywall.introOfferEligibility,
        productsByCompositeId: productsByCompositeId,
        productsByAppleId: productsByAppleId
      )
      if let name = productItem.name {
        isFreeTrialAvailableByProductName[name] = isAvailable
      }
      if isAvailable {
        isFreeTrialAvailable = true
      }
    }

    paywall.isFreeTrialAvailableByProductName = isFreeTrialAvailableByProductName
    paywall.isFreeTrialAvailable = forcedAvailability ?? isFreeTrialAvailable

    return paywall
  }

  /// Determines whether a free trial is available for a single product on
  /// the paywall.
  private func freeTrialAvailability(
    for productItem: Product,
    forcedAvailability: Bool?,
    introOfferEligibility: IntroOfferEligibility,
    productsByCompositeId: [String: StoreProduct],
    productsByAppleId: [String: StoreProduct]
  ) async -> Bool {
    switch productItem.type {
    case .appStore:
      guard let storeProduct = storeProduct(
        for: productItem,
        productsByCompositeId: productsByCompositeId,
        productsByAppleId: productsByAppleId
      ) else {
        return false
      }
      if let forcedAvailability = forcedAvailability {
        return forcedAvailability && storeProduct.hasFreeTrial
      }
      return await checkAppStoreTrialEligibility(
        for: storeProduct,
        introOfferEligibility: introOfferEligibility
      )
    case .stripe(let stripeProduct):
      if let forcedAvailability = forcedAvailability {
        return forcedAvailability && (stripeProduct.trialDays ?? 0) > 0
      }
      return await checkStripeTrialEligibility(
        for: productItem,
        stripeProduct: stripeProduct,
        introOfferEligibility: introOfferEligibility
      )
    case .custom:
      guard let storeProduct = storeProduct(
        for: productItem,
        productsByCompositeId: productsByCompositeId,
        productsByAppleId: productsByAppleId
      ) else {
        return false
      }
      if let forcedAvailability = forcedAvailability {
        return forcedAvailability && storeProduct.hasFreeTrial
      }
      // Custom products with a cached StoreProduct also pass through the
      // App Store-style check so `ALWAYS_ELIGIBLE` continues to surface
      // their trial without requiring entitlement history.
      if await checkAppStoreTrialEligibility(
        for: storeProduct,
        introOfferEligibility: introOfferEligibility
      ) {
        return true
      }
      return await checkCustomTrialEligibility(
        for: productItem,
        storeProduct: storeProduct,
        introOfferEligibility: introOfferEligibility
      )
    case .paddle:
      return false
    }
  }

  /// Looks up the cached `StoreProduct` for a product item, preferring the
  /// composite-keyed map and falling back to the Apple-ID-keyed map.
  private func storeProduct(
    for productItem: Product,
    productsByCompositeId: [String: StoreProduct],
    productsByAppleId: [String: StoreProduct]
  ) -> StoreProduct? {
    if let composite = productsByCompositeId[productItem.id] {
      return composite
    }
    if case .appStore(let appStoreProduct) = productItem.type {
      return productsByAppleId[appStoreProduct.id]
    }
    return productsByAppleId[productItem.id]
  }

  /// Checks App Store trial eligibility for a single product.
  private func checkAppStoreTrialEligibility(
    for product: StoreProduct,
    introOfferEligibility: IntroOfferEligibility
  ) async -> Bool {
    switch introOfferEligibility {
    case .eligible:
      guard product.hasFreeTrial else {
        return false
      }
      let hasActiveIntro = await hasActiveIntroOffer(
        inSubscriptionGroup: product.subscriptionGroupIdentifier
      )
      return !hasActiveIntro
    case .ineligible:
      return false
    case .automatic:
      return await factory.isFreeTrialAvailable(for: product)
    }
  }

  // MARK: - Intro Offer Check

  /// Checks if the user has an active intro offer (e.g., free trial) in the given subscription group.
  ///
  /// This uses the subscription data from `customerInfo` which is populated during `loadPurchasedProducts`,
  /// avoiding additional StoreKit calls that could slow down paywall presentation.
  ///
  /// - Parameter subscriptionGroupId: The subscription group identifier to check. If `nil`, returns `false`.
  /// - Returns: `true` if the user has an active intro offer in the subscription group, `false` otherwise.
  private func hasActiveIntroOffer(inSubscriptionGroup subscriptionGroupId: String?) async -> Bool {
    guard let subscriptionGroupId = subscriptionGroupId else {
      return false
    }

    let subscriptions = await MainActor.run {
      Superwall.shared.customerInfo.subscriptions
    }

    // Find active App Store subscriptions in the same subscription group with an intro offer
    return subscriptions.contains { subscription in
      subscription.store == .appStore &&
        subscription.isActive &&
        subscription.subscriptionGroupId == subscriptionGroupId &&
        subscription.offerType == .trial
    }
  }

  /// Checks if the user has ever had any of the given entitlements.
  ///
  /// This uses entitlement data from `customerInfo` which includes both active and inactive
  /// entitlements. Config-only entitlements (never purchased) have `latestProductId == nil`,
  /// while entitlements from actual transactions/redemptions have a non-nil `latestProductId`.
  /// Manually granted Superwall entitlements have `store == .superwall` without a product ID.
  /// Used for Stripe products where StoreKit subscription group checks don't apply.
  private func hasEverHadEntitlement(
    forProductEntitlements productEntitlements: Set<Entitlement>
  ) async -> Bool {
    let productEntitlementIds = Set(productEntitlements.map { $0.id })
    if productEntitlementIds.isEmpty {
      return false
    }
    let customerInfo = await MainActor.run {
      Superwall.shared.customerInfo
    }
    // If customer info hasn't loaded yet, assume the user has had the
    // entitlement to avoid falsely offering a trial.
    if customerInfo.isPlaceholder {
      return true
    }
    let entitlements = customerInfo.entitlements
    // Only consider entitlements with actual transaction history or that are
    // currently active. EntitlementProcessor adds config entitlements as
    // placeholders with latestProductId == nil when there are no transactions
    // for them. Active entitlements are also included to handle test mode,
    // where entitlements may not have a latestProductId set.
    let userEntitlementIds = Set(
      entitlements
        .filter { $0.latestProductId != nil || $0.store == .superwall || $0.isActive }
        .map { $0.id }
    )
    return !productEntitlementIds.isDisjoint(with: userEntitlementIds)
  }

  // MARK: - Stripe Trial Eligibility

  /// Checks a Stripe product for trial eligibility.
  ///
  /// Stripe products are not fetched into `productsById` (which only contains App Store products),
  /// so trial eligibility is determined separately by checking the `trialDays` property on the
  /// `StripeProduct` model against the user's entitlement history.
  private func checkStripeTrialEligibility(
    for productItem: Product,
    stripeProduct: StripeProduct,
    introOfferEligibility: IntroOfferEligibility
  ) async -> Bool {
    if introOfferEligibility == .ineligible {
      return false
    }
    guard let trialDays = stripeProduct.trialDays,
      trialDays > 0 else {
      return false
    }
    // Can't determine past subscription history without entitlements.
    if productItem.entitlements.isEmpty {
      Logger.debug(
        logLevel: .warn,
        scope: .productsManager,
        message: "Stripe product \(stripeProduct.id) has trialDays > 0 but no entitlements — skipping trial eligibility check."
      )
      return false
    }

    let hasEntitlement = await hasEverHadEntitlement(
      forProductEntitlements: productItem.entitlements
    )
    return !hasEntitlement
  }

  // MARK: - Custom Trial Eligibility

  /// Checks a custom product for trial eligibility using the cached StoreProduct data.
  private func checkCustomTrialEligibility(
    for productItem: Product,
    storeProduct: StoreProduct,
    introOfferEligibility: IntroOfferEligibility
  ) async -> Bool {
    if introOfferEligibility == .ineligible {
      return false
    }
    guard storeProduct.hasFreeTrial else {
      return false
    }
    if productItem.entitlements.isEmpty {
      Logger.debug(
        logLevel: .warn,
        scope: .productsManager,
        message: "Custom product \(productItem.id) has a free trial but no entitlements — skipping trial eligibility check."
      )
      return false
    }
    let hasEntitlement = await hasEverHadEntitlement(
      forProductEntitlements: productItem.entitlements
    )
    return !hasEntitlement
  }
}
