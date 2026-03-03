//
//  File.swift
//  
//
//  Created by Yusuf Tör on 12/05/2023.
//
// swiftlint:disable trailing_closure

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

  // swiftlint:disable:next function_body_length
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

      let outcome = await PaywallLogic.getVariablesAndFreeTrial(
        productItems: result.productItems,
        productsById: result.productsById,
        isFreeTrialAvailableOverride: request.overrides.isFreeTrial,
        isFreeTrialAvailable: { [weak self] product in
          guard let self = self else { return false }

          // Check test mode override first - it takes precedence over all other logic
          if self.factory.isTestMode {
            switch self.factory.testModeFreeTrialOverride {
            case .forceAvailable:
              return true
            case .forceUnavailable:
              return false
            case .useDefault:
              break
            }
          }

          switch paywall.introOfferEligibility {
          case .eligible:
            // Only show free trial if product has one AND user
            // doesn't have an active intro offer in the subscription group
            guard product.hasFreeTrial else {
              return false
            }
            // Stripe products don't have StoreKit subscription groups,
            // so check entitlement history instead.
            if product.product is StripeProductType {
              return await !self.hasEverHadEntitlement(for: product)
            }
            let hasActiveIntro = await self.hasActiveIntroOffer(
              inSubscriptionGroup: product.subscriptionGroupIdentifier
            )
            return !hasActiveIntro
          case .ineligible:
            return false
          case .automatic:
            if product.product is StripeProductType {
              guard product.hasFreeTrial else { return false }
              return await !self.hasEverHadEntitlement(for: product)
            }
            return await self.factory.isFreeTrialAvailable(for: product)
          }
        }
      )
      paywall.productVariables = outcome.productVariables
      paywall.isFreeTrialAvailable = outcome.isFreeTrialAvailable

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

  /// Checks if the user has ever had any of the entitlements associated with the given product.
  ///
  /// This uses entitlement data from `customerInfo` which includes both active and inactive
  /// entitlements. Config-only entitlements (never purchased) have `latestProductId == nil`,
  /// while entitlements from actual transactions/redemptions have a non-nil `latestProductId`.
  /// Manually granted Superwall entitlements have `store == .superwall` without a product ID.
  /// Used for Stripe products where StoreKit subscription group checks don't apply.
  private func hasEverHadEntitlement(for product: StoreProduct) async -> Bool {
    let productEntitlementIds = Set(product.entitlements.map { $0.id })
    guard !productEntitlementIds.isEmpty else {
      return false
    }
    let entitlements = await MainActor.run {
      Superwall.shared.customerInfo.entitlements
    }
    // Only consider entitlements with actual transaction history.
    // EntitlementProcessor adds config entitlements as placeholders with
    // latestProductId == nil when there are no transactions for them.
    let userEntitlementIds = Set(
      entitlements
        .filter { $0.latestProductId != nil || $0.store == .superwall }
        .map { $0.id }
    )
    return !productEntitlementIds.isDisjoint(with: userEntitlementIds)
  }
}
