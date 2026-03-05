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

    do {
      let result = try await storeKitManager.getProducts(
        forPaywall: paywall,
        placement: request.placementData,
        substituting: request.overrides.products,
        isTestMode: factory.isTestMode
      )

      paywall.products = result.productItems

      let outcome = PaywallLogic.getProductVariables(
        productItems: result.productItems,
        productsById: result.productsById
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

  /// Recalculates `isFreeTrialAvailable` for a paywall.
  ///
  /// This is called both for freshly loaded paywalls and cached paywalls to ensure
  /// trial eligibility reflects the user's current entitlement/subscription state.
  func refreshFreeTrialAvailability(
    for paywall: Paywall,
    request: PaywallRequest
  ) async -> Paywall {
    var paywall = paywall

    // Test mode overrides take highest precedence
    if factory.isTestMode {
      switch factory.testModeFreeTrialOverride {
      case .forceAvailable:
        paywall.isFreeTrialAvailable = true
        return paywall
      case .forceUnavailable:
        paywall.isFreeTrialAvailable = false
        return paywall
      case .useDefault:
        break
      }
    }

    // If a developer override is set, use it directly
    if let override = request.overrides.isFreeTrial {
      paywall.isFreeTrialAvailable = override
      return paywall
    }

    // Check App Store products
    let productsById = await storeKitManager.productsById
    var isFreeTrialAvailable = false

    for productItem in paywall.products {
      guard let storeProduct = productsById[productItem.id] else {
        continue
      }

      isFreeTrialAvailable = await checkAppStoreTrialEligibility(
        for: storeProduct,
        introOfferEligibility: paywall.introOfferEligibility
      )
      if isFreeTrialAvailable {
        break
      }
    }

    paywall.isFreeTrialAvailable = isFreeTrialAvailable

    // Check Stripe products for trial eligibility (they're not in productsById
    // so the loop above skips them)
    if !paywall.isFreeTrialAvailable {
      paywall.isFreeTrialAvailable = await checkStripeTrialEligibility(
        productItems: paywall.products,
        introOfferEligibility: paywall.introOfferEligibility
      )
    }

    return paywall
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

  /// Checks Stripe products for trial eligibility.
  ///
  /// Stripe products are not fetched into `productsById` (which only contains App Store products),
  /// so `getVariablesAndFreeTrial` skips them. This method handles Stripe trial eligibility
  /// separately by checking the `trialDays` property on the `StripeProduct` model.
  private func checkStripeTrialEligibility(
    productItems: [Product],
    introOfferEligibility: IntroOfferEligibility
  ) async -> Bool {
    if introOfferEligibility == .ineligible {
      return false
    }

    for productItem in productItems {
      guard case .stripe(let stripeProduct) = productItem.type else {
        continue
      }
      guard let trialDays = stripeProduct.trialDays else {
        continue
      }
      guard trialDays > 0 else {
        continue
      }
      // Can't determine past subscription history without entitlements.
      if productItem.entitlements.isEmpty {
        continue
      }

      let hasEntitlement = await hasEverHadEntitlement(
        forProductEntitlements: productItem.entitlements
      )
      if !hasEntitlement {
        return true
      }
    }
    return false
  }
}
