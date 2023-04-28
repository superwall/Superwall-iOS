//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/01/2023.
//

import UIKit
import Combine

protocol ViewControllerFactory: AnyObject {
  @MainActor
  func makePaywallViewController(
    for paywall: Paywall,
    withCache cache: PaywallViewControllerCache?
  ) -> PaywallViewController
  func makeDebugViewController(withDatabaseId id: String?) -> DebugViewController
}

protocol CacheFactory: AnyObject {
  func makeCache() -> PaywallViewControllerCache
}

protocol VariablesFactory: AnyObject {
  func makeJsonVariables(
    productVariables: [ProductVariable]?,
    params: JSON?
  ) async -> JSON
}

protocol RequestFactory: AnyObject {
  func makePaywallRequest(
    eventData: EventData?,
    responseIdentifiers: ResponseIdentifiers,
    overrides: PaywallRequest.Overrides?
  ) -> PaywallRequest

  func makePresentationRequest(
    _ presentationInfo: PresentationInfo,
    paywallOverrides: PaywallOverrides?,
    presenter: UIViewController?,
    isDebuggerLaunched: Bool?,
    subscriptionStatus: AnyPublisher<SubscriptionStatus, Never>?,
    isPaywallPresented: Bool
  ) -> PresentationRequest
}

protocol RuleAttributesFactory: AnyObject {
  func makeRuleAttributes() async -> RuleAttributes
}

protocol TriggerSessionManagerFactory: AnyObject {
  func makeTriggerSessionManager() -> TriggerSessionManager
}

protocol StoreKitCoordinatorFactory: AnyObject {
  func makeStoreKitCoordinator() -> StoreKitCoordinator
}

protocol IdentityInfoFactory: AnyObject {
  func makeIdentityInfo() async -> IdentityInfo
}

protocol LocaleIdentifierFactory: AnyObject {
  func makeLocaleIdentifier() -> String?
}

protocol DeviceInfoFactory: AnyObject {
  func makeDeviceInfo() -> DeviceInfo
}

protocol ApiFactory: AnyObject {
  // TODO: Think of an alternative way such that we don't need to do this:
  // swiftlint:disable implicitly_unwrapped_optional
  var api: Api! { get }
  var storage: Storage! { get }
  var deviceHelper: DeviceHelper! { get }
  var configManager: ConfigManager! { get }
  var identityManager: IdentityManager! { get }
  // swiftlint:enable implicitly_unwrapped_optional

  func makeHeaders(
    fromRequest request: URLRequest,
    isForDebugging: Bool,
    requestId: String
  ) async -> [String: String]
}

protocol ProductPurchaserFactory: AnyObject {
  func makeSK1ProductPurchaser() -> ProductPurchaserSK1
}

protocol StoreTransactionFactory: AnyObject {
  func makeStoreTransaction(from transaction: SK1Transaction) async -> StoreTransaction

  @available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  func makeStoreTransaction(from transaction: SK2Transaction) async -> StoreTransaction
}

protocol PurchaseManagerFactory: AnyObject {
  func makePurchaseManager() -> PurchaseManager
}
