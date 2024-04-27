//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/01/2023.
//

import UIKit
import Combine
import SystemConfiguration
import StoreKit

protocol ViewControllerFactory: AnyObject {
  @MainActor
  func makePaywallViewController(
    for paywall: Paywall,
    withCache cache: PaywallViewControllerCache?,
    withPaywallArchivalManager archivalManager: PaywallArchivalManager?,
    delegate: PaywallViewControllerDelegateAdapter?
  ) -> PaywallViewController

  func makeDebugViewController(withDatabaseId id: String?) -> DebugViewController
}

protocol CacheFactory: AnyObject {
  func makeCache() -> PaywallViewControllerCache
}

protocol PaywallArchivalManagerFactory: AnyObject {
  func makePaywallArchivalManager() -> PaywallArchivalManager
}

protocol VariablesFactory: AnyObject {
  func makeJsonVariables(
    products: [ProductVariable]?,
    computedPropertyRequests: [ComputedPropertyRequest],
    event: EventData?
  ) async -> JSON
}

protocol RequestFactory: AnyObject {
  func makePaywallRequest(
    eventData: EventData?,
    responseIdentifiers: ResponseIdentifiers,
    overrides: PaywallRequest.Overrides?,
    isDebuggerLaunched: Bool,
    presentationSourceType: String?,
    retryCount: Int
  ) -> PaywallRequest

  func makePresentationRequest(
    _ presentationInfo: PresentationInfo,
    paywallOverrides: PaywallOverrides?,
    presenter: UIViewController?,
    isDebuggerLaunched: Bool?,
    subscriptionStatus: AnyPublisher<SubscriptionStatus, Never>?,
    isPaywallPresented: Bool,
    type: PresentationRequestType
  ) -> PresentationRequest
}

protocol RuleAttributesFactory: AnyObject {
  func makeRuleAttributes(
    forEvent event: EventData?,
    withComputedProperties computedPropertyRequests: [ComputedPropertyRequest]
  ) async -> JSON
}

protocol FeatureFlagsFactory: AnyObject {
  func makeFeatureFlags() -> FeatureFlags?
}

protocol ComputedPropertyRequestsFactory: AnyObject {
  func makeComputedPropertyRequests() -> [ComputedPropertyRequest]
}

protocol TriggerSessionManagerFactory: AnyObject {
  func makeTriggerSessionManager() -> TriggerSessionManager
  func getTriggerSessionManager() -> TriggerSessionManager
}

protocol ConfigManagerFactory: AnyObject {
  func makeStaticPaywall(
    withId paywallId: String?,
    isDebuggerLaunched: Bool
  ) -> Paywall?
}

protocol IdentityInfoFactory: AnyObject {
  func makeIdentityInfo() async -> IdentityInfo
}

protocol LocaleIdentifierFactory: AnyObject {
  func makeLocaleIdentifier() -> String?
}

protocol DeviceHelperFactory: AnyObject {
  func makeDeviceInfo() -> DeviceInfo
  func makeIsSandbox() -> Bool
  func makeSessionDeviceAttributes() async -> [String: Any]
}

protocol HasExternalPurchaseControllerFactory: AnyObject {
  func makeHasExternalPurchaseController() -> Bool
}

struct DummyDecodable: Decodable {}

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

  func makeDefaultComponents(
    host: EndpointHost
  ) -> ApiHostConfig
}

protocol StoreTransactionFactory: AnyObject {
  func makeStoreTransaction(from transaction: SK1Transaction) async -> StoreTransaction

  @available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  func makeStoreTransaction(from transaction: SK2Transaction) async -> StoreTransaction
}

protocol OptionsFactory: AnyObject {
  func makeSuperwallOptions() -> SuperwallOptions
}

protocol TriggerFactory: AnyObject {
  func makeTriggers() -> Set<String>
}

protocol PurchasedTransactionsFactory {
  func makePurchasingCoordinator() -> PurchasingCoordinator
  func purchase(product: SKProduct) async -> PurchaseResult
  func restorePurchases() async -> RestorationResult
}

protocol UserAttributesEventFactory {
  func makeUserAttributesEvent() -> InternalSuperwallEvent.Attributes
}

protocol ReceiptFactory {
  func loadPurchasedProducts() async -> Set<StoreProduct>?
  func refreshReceipt() async
  func isFreeTrialAvailable(for product: StoreProduct) async -> Bool
}
