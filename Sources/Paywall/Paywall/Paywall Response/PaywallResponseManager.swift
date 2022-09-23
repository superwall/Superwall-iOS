//
//  File.swift
//  
//
//  Created by Jake Mor on 10/19/21.
//

import Foundation
import Combine

actor PaywallResponseManager {
  static let shared = PaywallResponseManager()
  private var activeTasks: [String: Task<PaywallResponse, Error>] = [:]
  private var paywallResponsesByHash: [String: PaywallResponse] = [:]

  func getResponse(from request: PaywallResponseRequest) async throws -> PaywallResponse {
    let paywallRequestHash = PaywallResponseLogic.requestHash(
      identifier: request.responseIdentifiers.paywallId,
      event: request.eventData
    )

    let notSubstitutingProducts = request.substituteProducts == nil
    let debuggerNotLaunched = await !SWDebugManager.shared.isDebuggerLaunched
    let shouldUseCache = notSubstitutingProducts && debuggerNotLaunched

    if let existingTask = activeTasks[paywallRequestHash] {
      return try await existingTask.value
    }

    let task = Task<PaywallResponse, Error> {
      if var response = paywallResponsesByHash[paywallRequestHash],
        shouldUseCache {
        response.experiment = request.responseIdentifiers.experiment
        activeTasks[paywallRequestHash] = nil
        return response
      }

      do {
        let response = try await request.publisher
          .getRawResponse()
          .addProducts()
          .map { $0.response }
          .throwableAsync()

        paywallResponsesByHash[paywallRequestHash] = response
        activeTasks[paywallRequestHash] = nil
        return response
      } catch {
        activeTasks[paywallRequestHash] = nil
        throw error
      }
    }

    activeTasks[paywallRequestHash] = task

    return try await task.value
  }
}
