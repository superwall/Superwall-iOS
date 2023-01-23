//
//  File.swift
//  
//
//  Created by Jake Mor on 10/19/21.
//

import Foundation
import Combine

actor PaywallRequestManager {
  unowned let storeKitManager: StoreKitManager

  // swiftlint:disable implicitly_unwrapped_optional
  unowned var deviceHelper: DeviceHelper!
  // swiftlint:enable implicitly_unwrapped_optional

  private var activeTasks: [String: Task<Paywall, Error>] = [:]
  private var paywallsByHash: [String: Paywall] = [:]

  init(storeKitManager: StoreKitManager) {
    self.storeKitManager = storeKitManager
  }

  func postInit(deviceHelper: DeviceHelper) {
    self.deviceHelper = deviceHelper
  }

  ///  Gets a paywall from a given request.
  ///
  ///  If a request for the same paywall is already in progress, it suspends until the request returns.
  ///
  ///  - Parameters:
  ///     - request: A request to get a paywall.
  ///  - Returns A paywall.
  func getPaywall(from request: PaywallRequest) async throws -> Paywall {
    let requestHash = PaywallLogic.requestHash(
      identifier: request.responseIdentifiers.paywallId,
      event: request.eventData,
      locale: deviceHelper.locale
    )

    let notSubstitutingProducts = request.overrides.products == nil
    let debuggerNotLaunched = !request.injections.debugManager.isDebuggerLaunched
    let shouldUseCache = notSubstitutingProducts && debuggerNotLaunched

    if var paywall = paywallsByHash[requestHash],
      shouldUseCache {
      // Calculate whether there's a free trial available
      if let primaryProduct = paywall.products.first(where: { $0.type == .primary }),
        let storeProduct = storeKitManager.productsById[primaryProduct.id] {
        let isFreeTrialAvailable = storeKitManager.isFreeTrialAvailable(for: storeProduct)
        paywall.isFreeTrialAvailable = isFreeTrialAvailable
      }
      paywall.experiment = request.responseIdentifiers.experiment
      return paywall
    }

    if let existingTask = activeTasks[requestHash] {
      return try await existingTask.value
    }

    let task = Task<Paywall, Error> {
      do {
        let paywall = try await request.publisher
          .getRawPaywall()
          .addProducts()
          .throwableAsync()

        paywallsByHash[requestHash] = paywall
        activeTasks[requestHash] = nil
        return paywall
      } catch {
        activeTasks[requestHash] = nil
        throw error
      }
    }

    activeTasks[requestHash] = task

    return try await task.value
  }
}
