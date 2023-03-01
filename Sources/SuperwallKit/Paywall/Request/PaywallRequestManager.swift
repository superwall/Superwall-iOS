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
      locale: deviceInfo.locale,
      paywallProducts: request.overrides.products
    )

    let debuggerNotLaunched = !request.dependencyContainer.debugManager.isDebuggerLaunched

    if var paywall = paywallsByHash[requestHash],
      debuggerNotLaunched {
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
          debuggerNotLaunched: debuggerNotLaunched
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
    debuggerNotLaunched: Bool
  ) {
    guard debuggerNotLaunched else {
      return
    }
    paywallsByHash[requestHash] = paywall
    activeTasks[requestHash] = nil
  }
}
