//
//  File.swift
//  
//
//  Created by Jake Mor on 10/19/21.
//

import Foundation
import Combine

/// Actor responsible for handling all paywall requests.
actor PaywallRequestManager {
  private unowned let storeKitManager: StoreKitManager
  private unowned let factory: DeviceInfoFactory

  private var activeTasks: [String: Task<Paywall, Error>] = [:]
  private var paywallsByHash: [String: Paywall] = [:]

  init(
    storeKitManager: StoreKitManager,
    factory: DeviceInfoFactory
  ) {
    self.storeKitManager = storeKitManager
    self.factory = factory
  }

  ///  Gets a paywall from a given request.
  ///
  ///  If a request for the same paywall is already in progress, it suspends until the request returns.
  ///
  ///  - Parameters:
  ///     - request: A request to get a paywall.
  ///  - Returns A paywall.
  func getPaywall(from request: PaywallRequest) async throws -> Paywall {
    let deviceInfo = factory.makeDeviceInfo()
    let requestHash = PaywallLogic.requestHash(
      identifier: request.responseIdentifiers.paywallId,
      event: request.eventData,
      locale: deviceInfo.locale
    )

    let notSubstitutingProducts = request.overrides.products == nil
    let debuggerNotLaunched = !request.dependencyContainer.debugManager.isDebuggerLaunched
    let shouldUseCache = notSubstitutingProducts && debuggerNotLaunched

    if var paywall = paywallsByHash[requestHash],
      shouldUseCache {
      // Calculate whether there's a free trial available
#warning("change this!")
      if let primaryProduct = paywall.products.first(where: { $0.type == .primary }),
        let storeProduct = await storeKitManager.productsById[primaryProduct.id] {
        let isFreeTrialAvailable = await storeKitManager.isFreeTrialAvailable(for: storeProduct)
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

        saveRequestHash(
          requestHash,
          paywall: paywall,
          shouldUseCache: shouldUseCache
        )

        return paywall
      } catch {
        activeTasks[requestHash] = nil
        throw error
      }
    }

    activeTasks[requestHash] = task

    return try await task.value
  }

  private func saveRequestHash(
    _ requestHash: String,
    paywall: Paywall,
    shouldUseCache: Bool
  ) {
    guard shouldUseCache else {
      return
    }
    paywallsByHash[requestHash] = paywall
    activeTasks[requestHash] = nil
  }


}
