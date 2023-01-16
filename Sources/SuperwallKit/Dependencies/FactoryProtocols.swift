//
//  File.swift
//  
//
//  Created by Yusuf Tör on 03/01/2023.
//

import UIKit

protocol ViewControllerFactory {
  func makePaywallViewController(for paywall: Paywall) -> PaywallViewController
  func makeDebugViewController(withDatabaseId id: String?) -> DebugViewController
}

protocol RequestFactory {
  func makePaywallRequest(withId paywallId: String) -> PaywallRequest

  func makePresentationRequest(
    _ presentationInfo: PresentationInfo,
    paywallOverrides: PaywallOverrides?,
    presentingViewController: UIViewController?,
    isDebuggerLaunched: Bool?,
    isUserSubscribed: Bool?,
    isPaywallPresented: Bool
  ) -> PresentationRequest
}

protocol TriggerSessionManagerFactory {
  func makeTriggerSessionManager() -> TriggerSessionManager
}

protocol StoreKitCoordinatorFactory {
  func makeStoreKitCoordinator() -> StoreKitCoordinator
}

protocol ApiFactory {
  // swiftlint:disable implicitly_unwrapped_optional
  // TODO: Think of an alternative way such that we don't need to do this:
  var api: Api! { get }
  var storage: Storage! { get }
  var deviceHelper: DeviceHelper! { get }
  var configManager: ConfigManager! { get }
  var identityManager: IdentityManager! { get }
  // swiftlint:enable implicitly_unwrapped_optional

  func makeHeaders(
    fromRequest request: URLRequest,
    requestId: String,
    forDebugging isForDebugging: Bool
  ) -> [String: String]
}

protocol ProductPurchaserFactory {
  func makeSK1ProductPurchaser() -> ProductPurchaserSK1
}

protocol StoreTransactionFactory {
  func makeStoreTransaction(from transaction: SK1Transaction) async -> StoreTransaction

  @available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
  func makeStoreTransaction(from transaction: SK2Transaction) async -> StoreTransaction
}
