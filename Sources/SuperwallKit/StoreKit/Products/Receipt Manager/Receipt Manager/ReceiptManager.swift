//
//  File.swift
//
//
//  Created by Yusuf Tör on 24/03/2022.
//

import Foundation
import StoreKit

protocol ReceiptDelegate: AnyObject {
  func syncSubscriptionStatus(purchases: Set<Purchase>) async
}

struct Purchase: Hashable {
  let id: String
  let isActive: Bool
  let purchaseDate: Date
}

actor ReceiptManager {
  typealias Factory = ConfigStateFactory & HasExternalPurchaseControllerFactory

  private var receiptRefreshCompletion: ((Bool) -> Void)?
  private unowned let productsManager: ProductsManager
  private weak var receiptDelegate: ReceiptDelegate?
  private let storeKitVersion: SuperwallOptions.StoreKitVersion
  private let shouldBypassAppTransactionCheck: Bool
  private let manager: ReceiptManagerType
  private let delegateWrapper: ReceiptRefreshDelegateWrapper
  private unowned let factory: Factory
  private unowned let storage: Storage
  /// Subscription group IDs the user currently has an active subscription in. Computed
  /// during `loadPurchasedProducts` from the active purchases and their fetched products,
  /// so it works for both StoreKit 1 and StoreKit 2. Used to suppress free trials on
  /// upgrades/crossgrades/downgrades, which Apple won't apply an intro offer to.
  private var activeSubscriptionGroupIds: Set<String>
  static var appTransactionId: String?
  static var appId: UInt64?
  /// Set from `AppTransaction.shared` when available (iOS 16+).
  /// `true` means sandbox, `false` means production, `nil` means not yet determined.
  static var isSandboxEnvironment: Bool?

  init(
    storeKitVersion: SuperwallOptions.StoreKitVersion,
    shouldBypassAppTransactionCheck: Bool,
    productsManager: ProductsManager,
    receiptManager: ReceiptManagerType? = nil, // For testing
    receiptDelegate: ReceiptDelegate?,
    factory: Factory,
    storage: Storage,
    activeSubscriptionGroupIds: Set<String> = [] // For testing
  ) {
    self.storeKitVersion = storeKitVersion
    self.shouldBypassAppTransactionCheck = shouldBypassAppTransactionCheck
    self.productsManager = productsManager
    self.factory = factory
    self.storage = storage
    self.activeSubscriptionGroupIds = activeSubscriptionGroupIds

    if let receiptManager = receiptManager {
      self.manager = receiptManager
    } else if #available(iOS 15.0, *),
      storeKitVersion == .storeKit2 {
      self.manager = Self.versionedManager(storeKitVersion: storeKitVersion)
    } else {
      self.manager = SK1ReceiptManager()
    }
    self.receiptDelegate = receiptDelegate
    self.delegateWrapper = ReceiptRefreshDelegateWrapper()
    self.delegateWrapper.receiptManager = self

    Task {
      await setAppTransactionId()
    }
  }

  static func versionedManager(
    storeKitVersion: SuperwallOptions.StoreKitVersion
  ) -> ReceiptManagerType {
    if #available(iOS 15.0, *),
      storeKitVersion == .storeKit2 {
      return SK2ReceiptManager()
    } else {
      return SK1ReceiptManager()
    }
  }

  func getTransactionReceipts() async -> [TransactionReceipt] {
    await manager.transactionReceipts
  }

  private func setAppTransactionId() async {
    #if compiler(>=6.1)
    if #available(iOS 16.0, *),
      !shouldBypassAppTransactionCheck,
      !ProcessInfo.processInfo.arguments.contains("SUPERWALL_UNIT_TESTS") {
      if let result = try? await AppTransaction.shared {
        switch result {
        case .verified(let transaction),
          .unverified(let transaction, _):
          Self.appTransactionId = transaction.appTransactionID
          Self.appId = transaction.appID
          Self.isSandboxEnvironment = transaction.environment == .sandbox || transaction.environment == .xcode
          if Superwall.isInitialized {
            registerAppTransactionIdIfNeeded()
            Superwall.shared.dequeueIntegrationAttributes()
          }
        }
      }
    }
    #endif
  }

  private func registerAppTransactionIdIfNeeded() {
    // Check if already sent
    if storage.get(AppTransactionIdSent.self) == true {
      return
    }

    // Don't register if app transaction ID is nil
    guard Self.appTransactionId != nil else {
      return
    }

    Task {
      // Call redeem with existing codes (or empty if none)
      // This will send the app transaction ID to the backend
      await Superwall.shared.dependencyContainer.webEntitlementRedeemer.redeem(.existingCodes)

      // Mark as sent
      storage.save(true, forType: AppTransactionIdSent.self)
    }
  }

  func getExperimentalDeviceProperties() async -> [String: Any] {
    async let periodType = manager.latestSubscriptionPeriodType?.rawValue
    async let state = manager.latestSubscriptionState?.rawValue
    async let willAutoRenew = manager.latestSubscriptionWillAutoRenew

    let (unwrappedPeriodType, unwrappedState, unwrappedWillAutoRenew) = await (periodType, state, willAutoRenew)

    var values: [String: Any] = [:]

    if let periodType = unwrappedPeriodType {
      values["latestSubscriptionPeriodType"] = periodType
    }

    if let state = unwrappedState {
      values["latestSubscriptionState"] = state
    }

    if let willAutoRenew = unwrappedWillAutoRenew {
      values["latestSubscriptionWillAutoRenew"] = willAutoRenew
    }
    return values
  }

  /// Loads purchased products from the receipt, storing the purchased subscription group identifiers, purchases and active purchases.
  func loadPurchasedProducts(config: Config?) async {
    let resolvedConfig: Config?

    if let config = config {
      resolvedConfig = config
    } else {
      let configState = factory.makeConfigState()
      do {
        resolvedConfig = try await configState
          .compactMap { $0.getConfig() }
          .throwableAsync()
      } catch {
        return
      }
    }

    guard let config = resolvedConfig else {
      // Neither input config nor config from state is available
      return
    }

    // Each product id has a set of entitlements
    let configEntitlementsByProductId = ConfigLogic.extractEntitlements(from: config)

    // Get device snapshot
    let onDeviceSnapshot = await manager.loadPurchases(serverEntitlementsByProductId: configEntitlementsByProductId)

    // Save device-only CustomerInfo to storage for use when merging with web entitlements
    storage.save(onDeviceSnapshot.customerInfo, forType: LatestDeviceCustomerInfo.self)

    // Merge with web customer info if available
    let baseCustomerInfo: CustomerInfo
    if let latestRedeemResponse = storage.get(LatestRedeemResponse.self) {
      baseCustomerInfo = onDeviceSnapshot.customerInfo.merging(with: latestRedeemResponse.customerInfo)
    } else {
      baseCustomerInfo = onDeviceSnapshot.customerInfo
    }

    // If using an external purchase controller, preserve entitlements that came from it
    // (The external controller's active entitlements won't necessarily be in device data)
    let mergedCustomerInfo: CustomerInfo
    if factory.makeHasExternalPurchaseController() {
      let currentCustomerInfo = await MainActor.run { Superwall.shared.customerInfo }

      // Get entitlements that are only in current CustomerInfo (i.e., from external controller)
      // by filtering out anything that matches device or web entitlements by ID
      let deviceAndWebEntitlementIds = Set(baseCustomerInfo.entitlements.map { $0.id })
      let externalOnlyEntitlements = currentCustomerInfo.entitlements.filter { entitlement in
        // Keep external entitlement if it's not already in device/web
        !deviceAndWebEntitlementIds.contains(entitlement.id)
      }

      // Merge external controller entitlements with device + web
      let allEntitlements = baseCustomerInfo.entitlements + externalOnlyEntitlements
      let finalEntitlements = Entitlement.mergePrioritized(allEntitlements)

      mergedCustomerInfo = CustomerInfo(
        subscriptions: baseCustomerInfo.subscriptions,
        nonSubscriptions: baseCustomerInfo.nonSubscriptions,
        entitlements: finalEntitlements.sorted { $0.id < $1.id }
      )
    } else {
      mergedCustomerInfo = baseCustomerInfo
    }

    await MainActor.run {
      Superwall.shared.customerInfo = mergedCustomerInfo
    }

    Superwall.shared.entitlements.setEntitlementsFromConfig(mergedCustomerInfo.entitlementsByProductId)

    await receiptDelegate?.syncSubscriptionStatus(purchases: onDeviceSnapshot.purchases)

    // Refresh from this load's snapshot first, so the active-group state never describes a
    // previous load: the transactions carry the group (StoreKit 2) without the fetch below.
    // (Apple-ID-scoped, so an identity change / `reset()` doesn't require clearing it.)
    activeSubscriptionGroupIds = computeActiveSubscriptionGroupIds(from: onDeviceSnapshot, storeProducts: [])

    let purchasedProductIds = Set(onDeviceSnapshot.purchases.map { $0.id })

    guard let storeProducts = try? await productsManager.products(
      identifiers: purchasedProductIds,
      forPaywall: nil,
      placement: nil
    ) else {
      return
    }

    // A successful fetch enriches the set with product-derived groups (StoreKit 1's source).
    activeSubscriptionGroupIds = computeActiveSubscriptionGroupIds(from: onDeviceSnapshot, storeProducts: storeProducts)

    await manager.loadIntroOfferEligibility(forProducts: storeProducts)
  }

  /// Determines whether a free trial will actually be granted when the user purchases `storeProduct`.
  ///
  /// Stricter than raw `isEligibleForIntroOffer` (which only reflects whether the customer ever
  /// *consumed* an intro in the group): Apple doesn't apply intro offers to upgrades, crossgrades,
  /// or downgrades, so we also require no active subscription in the product's group. Once the
  /// existing subscription lapses, a fresh purchase is eligible again.
  func isFreeTrialAvailable(for storeProduct: StoreProduct) async -> Bool {
    let isEligibleForIntroOffer = await manager.isEligibleForIntroOffer(storeProduct)
    if !isEligibleForIntroOffer {
      return false
    }

    // Non-subscription products have no subscription group, so the
    // upgrade/crossgrade/downgrade rule doesn't apply.
    guard let subscriptionGroupId = storeProduct.subscriptionGroupIdentifier else {
      return true
    }

    // `activeSubscriptionGroupIds` is populated in `loadPurchasedProducts`, which always
    // completes before a paywall opens (config is only marked retrieved after it runs,
    // and presentation waits for config), so this reflects current subscription state.
    return !activeSubscriptionGroupIds.contains(subscriptionGroupId)
  }

  /// Determines whether the user is subscribed to the given product id.
  func isSubscribed(to productId: String) async -> Bool {
    return await manager.purchases
      .filter { $0.id == productId }
      .sorted { $0.purchaseDate > $1.purchaseDate }
      .first?
      .isActive == true
  }

  func getActiveProductIds() async -> Set<String> {
    return await Set(
      manager.purchases
      .filter(\.isActive)
      .map(\.id)
    )
  }

  /// This refreshes the device receipt.
  ///
  /// - Warning: This will prompt the user to log in, so only do this on
  /// when restoring or after purchasing.
  func refreshSK1Receipt() async {
    guard storeKitVersion == .storeKit1 else {
      return
    }
    Logger.debug(
      logLevel: .debug,
      scope: .receipts,
      message: "Refreshing receipts"
    )

    // Don't need the result at the moment.
    _ = await withCheckedContinuation { continuation in
      let refresh = SKReceiptRefreshRequest()
      refresh.delegate = delegateWrapper
      refresh.start()
      receiptRefreshCompletion = { completed in
        continuation.resume(returning: completed)
      }
    }
  }

  func receiptRefreshDidFinish(request: SKRequest) {
    guard request is SKReceiptRefreshRequest else {
      return
    }
    Logger.debug(
      logLevel: .debug,
      scope: .transactions,
      message: "Receipt refresh request finished.",
      info: ["request": request]
    )

    receiptRefreshCompletion?(true)

    request.cancel()
  }

  func receiptRefreshDidFail(
    request: SKRequest,
    error: Error
  ) {
    guard request is SKReceiptRefreshRequest else {
      return
    }
    Logger.debug(
      logLevel: .error,
      scope: .transactions,
      message: "Receipt refresh request failed.",
      info: ["request": request],
      error: error
    )
    receiptRefreshCompletion?(false)

    request.cancel()
  }
}

/// Subscription group IDs the user currently has an active subscription in, unioned from two
/// sources so none is dropped: snapshot transactions (StoreKit 2 carries the group ID, so this
/// survives a delisted product) and active purchases' fetched-product groups (StoreKit 1's only
/// source). File-scoped so it doesn't count toward the actor body length.
func computeActiveSubscriptionGroupIds(
  from snapshot: PurchaseSnapshot,
  storeProducts: Set<StoreProduct>
) -> Set<String> {
  let transactionGroupIds = snapshot.customerInfo.subscriptions
    .filter { $0.isActive }
    .compactMap { $0.subscriptionGroupId }

  let activeProductIds = Set(snapshot.purchases.filter { $0.isActive }.map { $0.id })
  let productGroupIds = storeProducts
    .filter { activeProductIds.contains($0.productIdentifier) }
    .compactMap { $0.subscriptionGroupIdentifier }

  return Set(transactionGroupIds).union(productGroupIds)
}

final class ReceiptRefreshDelegateWrapper: NSObject, SKRequestDelegate {
  weak var receiptManager: ReceiptManager?

  func requestDidFinish(_ request: SKRequest) {
    Task {
      await receiptManager?.receiptRefreshDidFinish(request: request)
    }
  }

  func request(_ request: SKRequest, didFailWithError error: Error) {
    Task {
      await receiptManager?.receiptRefreshDidFail(
        request: request,
        error: error
      )
    }
  }
}
