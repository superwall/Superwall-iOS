//
//  File.swift
//  
//
//  Created by Jake Mor on 10/19/21.
//

import Foundation
import Combine

actor PaywallRequestManager {
  static let shared = PaywallRequestManager()
  private var activeTasks: [String: Task<Paywall, Error>] = [:]
  private var paywallsByHash: [String: Paywall] = [:]

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
      event: request.eventData
    )

    let notSubstitutingProducts = request.substituteProducts == nil
    let debuggerNotLaunched = await !SWDebugManager.shared.isDebuggerLaunched
    let shouldUseCache = notSubstitutingProducts && debuggerNotLaunched

    if var response = paywallsByHash[requestHash],
      shouldUseCache {
      response.experiment = request.responseIdentifiers.experiment
      return response
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
