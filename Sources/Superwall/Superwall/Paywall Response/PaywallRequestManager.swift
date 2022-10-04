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

  func getPaywall(from request: PaywallRequest) async throws -> Paywall {
    let requestHash = PaywallResponseLogic.requestHash(
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
        let response = try await request.publisher
          .getRawResponse()
          .addProducts()
          .map { $0.response }
          .throwableAsync()

        paywallsByHash[requestHash] = response
        activeTasks[requestHash] = nil
        return response
      } catch {
        activeTasks[requestHash] = nil
        throw error
      }
    }

    activeTasks[requestHash] = task

    return try await task.value
  }
}
