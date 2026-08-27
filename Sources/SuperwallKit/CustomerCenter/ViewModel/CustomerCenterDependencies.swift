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
  init(_ product: StoreProduct) {
    // No store gave us a name, so tidy the identifier rather than showing it raw. Applies to web
    // products (whose payload carries no name at all) and to any store product with an empty one.
    var title = ProductTitleFormatter.displayTitle(forIdentifier: product.productIdentifier)
    if #available(iOS 15.0, *), let name = product.sk2Product?.displayName, !name.isEmpty {
      title = name
    } else if let name = product.sk1Product?.localizedTitle, !name.isEmpty {
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
      let response = try await container.network.getSuperwallProducts()
      for product in response.data where missing.contains(product.identifier) {
        let entitlements = Set(product.entitlements.map { Entitlement(id: $0.identifier) })
        let apiProduct = APIStoreProduct(superwallProduct: product, entitlements: entitlements)
        let storeProduct = StoreProduct(catalogProduct: apiProduct)
        resolved[product.identifier] = ProductDisplayInfo(storeProduct)
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
  var isSandbox: Bool { ReceiptManager.isSandboxEnvironment ?? false }
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
