//
//  CustomerCenterDependencies.swift
//
//
//  Created by Jordan Morgan on 20/08/2026.
//

import Combine
import Foundation
import UIKit

protocol CustomerCenterCustomerInfoProviding: AnyObject {
  func fetchCustomerInfo() async -> CustomerInfo
  /// Reloads receipts/entitlements from StoreKit before returning fresh customer info. Use
  /// after Apple's manage-subscriptions or change-plan sheet closes: cancelling auto-renew
  /// there emits no `Transaction.updates`, so a cached read would miss the change.
  func refreshReceipts() async -> CustomerInfo
  var customerInfoPublisher: AnyPublisher<CustomerInfo, Never> { get }
}
protocol CustomerCenterProductsProviding {
  func products(for ids: Set<String>) async -> [String: ProductDisplayInfo]
}
protocol CustomerCenterRestoring {
  func restorePurchases() async -> RestorationResult
}
protocol CustomerCenterURLOpening {
  var canOpenURLs: Bool { get }
  func canOpen(_ url: URL) -> Bool
  func open(_ url: URL)
}
protocol CustomerCenterEventTracking {
  func track(_ event: Trackable) async
}
protocol CustomerCenterEnvironmentProviding {
  var appVersion: String { get }
  var osVersion: String { get }
  var deviceModel: String { get }
  var sdkVersion: String { get }
  var userId: String { get }
  var isSandbox: Bool { get }
  var appStoreURL: URL? { get }
  var webManagementURL: URL? { get }
  var isSimulator: Bool { get }
  var isAppExtension: Bool { get }
  var originalDownloadDate: Date? { get }
  var locale: Locale { get }
}

struct CustomerCenterDependencies {
  var customerInfo: CustomerCenterCustomerInfoProviding
  var products: CustomerCenterProductsProviding
  var restore: CustomerCenterRestoring
  var urlOpener: CustomerCenterURLOpening
  var tracker: CustomerCenterEventTracking
  var environment: CustomerCenterEnvironmentProviding
  var transactionLookup: StoreKitTransactionLooking
  var appStoreVersion: CustomerCenterAppStoreVersionProviding
}

enum WebManagementURLResolver {
  static func resolve(override: URL?, restoreAccessURL: URL?) -> URL? {
    if let override { return override }
    guard let restoreAccessURL else { return nil }
    guard
      let host = restoreAccessURL.host, host == "superwall.app" || host.hasSuffix(".superwall.app"),
      var components = URLComponents(url: restoreAccessURL, resolvingAgainstBaseURL: false)
    else {
      return restoreAccessURL
    }
    components.path = "/manage"
    components.query = nil
    components.fragment = nil
    return components.url ?? restoreAccessURL
  }
}

extension ProductDisplayInfo {
  /// - Parameter name: A display name from outside StoreKit — the Superwall catalogue, for a web
  ///   product StoreKit can't resolve. Ignored when `nil` or empty, leaving the usual fallbacks.
  init(_ product: StoreProduct, name: String? = nil) {
    var title = product.productIdentifier
    if #available(iOS 15.0, *), let name = product.sk2Product?.displayName, !name.isEmpty {
      title = name
    } else if let name = product.sk1Product?.localizedTitle, !name.isEmpty {
      title = name
    }
    if let name, !name.isEmpty {
      title = name
    }
    var isAutoRenewable: Bool?
    if #available(iOS 15.0, *), let type = product.sk2Product?.type {
      isAutoRenewable = type == .autoRenewable
    }
    self.init(
      productId: product.productIdentifier,
      title: title,
      localizedPrice: product.localizedPrice,
      price: product.price,
      localizedPeriod: product.subscriptionPeriod == nil ? nil : product.period,
      subscriptionGroupId: product.subscriptionGroupIdentifier,
      isAutoRenewable: isAutoRenewable
    )
  }
}

// MARK: - Live adapters

@available(iOS 15.0, *)
final class LiveCustomerInfoProvider: CustomerCenterCustomerInfoProviding {
  func fetchCustomerInfo() async -> CustomerInfo { await Superwall.shared.getCustomerInfo() }
  func refreshReceipts() async -> CustomerInfo {
    await Superwall.shared.dependencyContainer.receiptManager.loadPurchasedProducts(config: nil)
    return await Superwall.shared.getCustomerInfo()
  }
  var customerInfoPublisher: AnyPublisher<CustomerInfo, Never> { Superwall.shared.$customerInfo.eraseToAnyPublisher() }
}
@available(iOS 15.0, *)
struct LiveProductsProvider: CustomerCenterProductsProviding {
  let container: DependencyContainer

  func products(for ids: Set<String>) async -> [String: ProductDisplayInfo] {
    guard !ids.isEmpty else { return [:] }
    let products = await Superwall.shared.products(for: ids)
    var resolved = Dictionary(uniqueKeysWithValues: products.map { ($0.productIdentifier, ProductDisplayInfo($0)) })

    // StoreKit only knows App Store products, so a subscription bought on the web resolves to
    // nothing and its card falls back to showing a raw product identifier with no price. Those
    // products are in the Superwall catalogue with their price, so fill the gaps from there.
    let missing = ids.subtracting(resolved.keys)
    guard !missing.isEmpty else { return resolved }
    do {
      // Bounded deliberately. This sits on the path that leaves `.loading`, and the endpoint's
      // defaults are six retries with exponential backoff and no timeout — a failing backend
      // would otherwise hold the spinner for minutes on a screen whose prices are a nicety.
      let response = try await withCatalogueTimeout {
        try await container.network.getSuperwallProducts()
      }
      // `missing` is every id StoreKit didn't return, which includes App Store products whenever
      // a StoreKit lookup fails — `products(for:)` swallows that with `try?`. Filling those from
      // the catalogue would quote the dashboard's storefront price instead of what the customer is
      // actually charged, so restrict this to products StoreKit was never going to resolve.
      for product in response.data
      where missing.contains(product.identifier) && product.platform != .ios {
        let entitlements = Set(product.entitlements.map { Entitlement(id: $0.identifier) })
        let apiProduct = APIStoreProduct(superwallProduct: product, entitlements: entitlements)
        let storeProduct = StoreProduct(catalogProduct: apiProduct)
        resolved[product.identifier] = ProductDisplayInfo(storeProduct, name: product.name)
      }
    } catch {
      // Advisory: the cards still render, just without a price.
      Logger.debug(
        logLevel: .warn,
        scope: .customerCenter,
        message: "Couldn't load Superwall products, so web purchases will show without a price.",
        error: error
      )
    }
    return resolved
  }

  /// How long the catalogue gets before the screen gives up on prices and renders without them.
  private static let catalogueTimeout: TimeInterval = 5

  private func withCatalogueTimeout(
    _ work: @escaping () async throws -> SuperwallProductsResponse
  ) async throws -> SuperwallProductsResponse {
    try await withThrowingTaskGroup(of: SuperwallProductsResponse.self) { group in
      group.addTask { try await work() }
      group.addTask {
        try await Task.sleep(nanoseconds: UInt64(Self.catalogueTimeout * 1_000_000_000))
        throw CancellationError()
      }
      defer { group.cancelAll() }
      guard let first = try await group.next() else {
        throw CancellationError()
      }
      return first
    }
  }
}
@available(iOS 15.0, *)
struct LiveRestorer: CustomerCenterRestoring {
  func restorePurchases() async -> RestorationResult {
    await Superwall.shared.restorePurchases(presentsFailureAlert: false)
  }
}
struct LiveURLOpener: CustomerCenterURLOpening {
  var canOpenURLs: Bool { UIApplication.sharedApplication != nil }
  func canOpen(_ url: URL) -> Bool { UIApplication.sharedApplication?.canOpenURL(url) ?? false }
  func open(_ url: URL) { UIApplication.sharedApplication?.open(url) }
}
@available(iOS 15.0, *)
struct LiveEventTracker: CustomerCenterEventTracking {
  func track(_ event: Trackable) async { _ = await Superwall.shared.track(event) }
}
@available(iOS 15.0, *)
struct LiveEnvironment: CustomerCenterEnvironmentProviding {
  let container: DependencyContainer
  let webManagementOverride: URL?
  var appVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "" }
  var osVersion: String { UIDevice.current.systemVersion }
  var deviceModel: String { UIDevice.current.model }
  var sdkVersion: String { SuperwallKit.sdkVersion }
  var userId: String { Superwall.shared.userId }
  /// Deliberately `DeviceHelper`'s detection rather than `ReceiptManager.isSandboxEnvironment`
  /// directly: that static is only ever assigned inside an `#available(iOS 16.0, *)` branch, so on
  /// iOS 15 — the Customer Center's own floor — it stays nil and every sandbox check silently
  /// reads `false`. `DeviceHelper` falls back to the simulator flag and the receipt URL, and also
  /// accounts for test mode.
  var isSandbox: Bool { container.deviceHelper.isSandbox == "true" }
  var appStoreURL: URL? {
    let id = container.makeAppId() ?? ReceiptManager.appId.map(String.init)
    return id.flatMap { URL(string: "https://apps.apple.com/app/id\($0)") }
  }
  var webManagementURL: URL? {
    WebManagementURLResolver.resolve(
      override: webManagementOverride,
      restoreAccessURL: container.makeRestoreAccessURL()
    )
  }
  var isSimulator: Bool { RuntimeUtils.isSimulator }
  var isAppExtension: Bool { Bundle.main.bundlePath.hasSuffix(".appex") }
  var originalDownloadDate: Date? { container.deviceHelper.appInstallDateValue }
  var locale: Locale { Locale(identifier: container.deviceHelper.preferredLocaleIdentifier) }
}

extension CustomerCenterDependencies {
  @available(iOS 15.0, *)
  static func live(container: DependencyContainer, configuration: CustomerCenterConfiguration) -> CustomerCenterDependencies {
    CustomerCenterDependencies(
      customerInfo: LiveCustomerInfoProvider(),
      products: LiveProductsProvider(container: container),
      restore: LiveRestorer(),
      urlOpener: LiveURLOpener(),
      tracker: LiveEventTracker(),
      environment: LiveEnvironment(container: container, webManagementOverride: configuration.support.webManagementURL),
      transactionLookup: StoreKitTransactionLookup(),
      appStoreVersion: AppStoreVersionLookup()
    )
  }
}

enum RuntimeUtils {
  static var isSimulator: Bool {
    #if targetEnvironment(simulator)
    return true
    #else
    return false
    #endif
  }
}
