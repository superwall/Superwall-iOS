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
  unowned let storeKitManager: StoreKitManager
  unowned let network: Network
  unowned let factory: Factory

  private var activeTasks: [String: Task<Paywall, Error>] = [:]
  private var paywallsByHash: [String: Paywall] = [:]
  typealias Factory = DeviceHelperFactory
    & TriggerSessionManagerFactory
    & ConfigManagerFactory

  init(
    storeKitManager: StoreKitManager,
    network: Network,
    factory: Factory
  ) {
    self.storeKitManager = storeKitManager
    self.network = network
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
      locale: deviceInfo.locale,
      paywallProducts: request.overrides.products
    )

    if var paywall = paywallsByHash[requestHash],
      !request.isDebuggerLaunched {
      paywall.experiment = request.responseIdentifiers.experiment
      return paywall
    }

    if let existingTask = activeTasks[requestHash] {
      return try await existingTask.value
    }

    let task = Task<Paywall, Error> {
      do {
        let rawPaywall = try await getRawPaywall(from: request)
        let paywallWithProducts = try await addProducts(to: rawPaywall, request: request)

        saveRequestHash(
          requestHash,
          paywall: paywallWithProducts,
          isDebuggerLaunched: request.isDebuggerLaunched
        )

        return paywallWithProducts
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
    isDebuggerLaunched: Bool
  ) {
    activeTasks[requestHash] = nil
    if !isDebuggerLaunched {
      paywallsByHash[requestHash] = paywall
    }
  }
}
