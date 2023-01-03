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
    isDebuggerLaunched: Bool,
    isUserSubscribed: Bool,
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
  var api: Api! { get }
  var storage: Storage! { get }
  var deviceHelper: DeviceHelper! { get }
  var configManager: ConfigManager! { get }
  var identityManager: IdentityManager! { get }

  func makeHeaders(
    fromRequest request: URLRequest,
    requestId: String,
    forDebugging isForDebugging: Bool
  ) -> [String: String]
}

protocol StoreTransactionFactory {
  @available(iOS 15.0, *)
  func makeStoreTransaction(from transaction: SK2Transaction) async -> StoreTransaction
  func makeStoreTransaction(from transaction: SK1Transaction) async -> StoreTransaction
}
