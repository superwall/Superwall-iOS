//
//  File.swift
//  
//
//  Created by Jake Mor on 10/19/21.
//

import Foundation
import StoreKit
import os

typealias PaywallResponseCompletionBlock = (Result<PaywallResponse, NSError>) -> Void

actor PaywallResponseManager {
	static let shared = PaywallResponseManager()

  // private let queue = DispatchQueue(label: "PaywallRequests")
	private var activeTasks: [String: Task<PaywallResponse, Error>] = [:]
	// private var responsesByHash: [String: Result<PaywallResponse, NSError>] = [:]
	// private var handlersByHash: [String: [PaywallResponseCompletionBlock]] = [:]

  func getResponse(
    from eventData: EventData? = nil,
    withIdentifiers responseIdentifiers: ResponseIdentifiers,
    substituteProducts: PaywallProducts? = nil
  ) async throws -> PaywallResponse {
    let paywallRequestHash = PaywallResponseLogic.requestHash(
      identifier: responseIdentifiers.paywallId,
      event: eventData
    )

    // TODO: Handle the following:
    //!hasSubstituteProducts,
   // !isDebuggerLaunched
    if let existingTask = activeTasks[paywallRequestHash] {
      var response = try await existingTask.value
      response.experiment = responseIdentifiers.experiment
      return response
    }

    let task = Task<PaywallResponse, Error> {
      do {
        let response = try await loadPaywall(
          forEvent: eventData,
          withHash: paywallRequestHash,
          responseIdentifiers: responseIdentifiers,
          substituteProducts: substituteProducts
        )
        activeTasks[paywallRequestHash] = nil
        return response
      } catch {
        activeTasks[paywallRequestHash] = nil
        throw error
      }
    }

    return try await task.value
  }





//
//
//
//
//
//  @available(*, renamed: "getResponse(from:withIdentifiers:substituteProducts:)")
//  func getResponse(
//    from eventData: EventData? = nil,
//    withIdentifiers responseIdentifiers: ResponseIdentifiers,
//    substituteProducts: PaywallProducts? = nil,
//    completion: @escaping PaywallResponseCompletionBlock
//  ) {
//    let paywallRequestHash = PaywallResponseLogic.requestHash(
//      identifier: responseIdentifiers.paywallId,
//      event: eventData
//    )
//
//    let paywallResponseCachingOutcome = PaywallResponseLogic.searchForPaywallResponse(
//      forEvent: eventData,
//      withHash: paywallRequestHash,
//      identifiers: responseIdentifiers,
//      hasSubstituteProducts: substituteProducts != nil,
//      inResultsCache: responsesByHash,
//      handlersCache: handlersByHash,
//      isDebuggerLaunched: SWDebugManager.shared.isDebuggerLaunched
//    )
//
//    switch paywallResponseCachingOutcome {
//    case .cachedResult(let result):
//      onMain {
//        completion(result)
//      }
//      return
//    case let .enqueCompletionBlock(hash, completionBlocks):
//      handlersByHash[hash] = completionBlocks + [completion]
//      return
//    case .setCompletionBlock(let hash):
//      handlersByHash[hash] = [completion]
//    }
//
//    loadPaywall(
//      forEvent: eventData,
//      withHash: paywallRequestHash,
//      responseIdentifiers: responseIdentifiers,
//      substituteProducts: substituteProducts
//    )
//  }
//
//  func getResponse(
//    from eventData: EventData? = nil,
//    withIdentifiers responseIdentifiers: ResponseIdentifiers,
//    substituteProducts: PaywallProducts? = nil) async throws -> PaywallResponse {
//    return try await withCheckedThrowingContinuation { continuation in
//      getResponse(from: eventData, withIdentifiers: responseIdentifiers, substituteProducts: substituteProducts) { result in
//        continuation.resume(with: result)
//      }
//    }
//  }

  private func getCachedResponseOrLoad(
    paywallId: String?,
    fromEvent event: EventData?
  ) async throws -> PaywallResponse {
    if let paywallResponse = ConfigManager.shared.getStaticPaywallResponse(forPaywallId: paywallId) {
      return paywallResponse
    } else {
      return try await Network.shared.getPaywallResponse(
        withPaywallId: paywallId,
        fromEvent: event
      )
    }
  }

  private func loadPaywall(
    forEvent event: EventData?,
    withHash paywallRequestHash: String,
    responseIdentifiers: ResponseIdentifiers,
    substituteProducts: PaywallProducts?
  ) async throws -> PaywallResponse {
    let responseLoadStartTime = Date()

    SessionEventsManager.shared.triggerSession.trackPaywallResponseLoad(
      forPaywallId: responseIdentifiers.paywallId,
      state: .start
    )
    let trackedEvent = InternalSuperwallEvent.PaywallResponseLoad(
      state: .start,
      eventData: event
    )
    Paywall.track(trackedEvent)

    do {
      var response = try await getCachedResponseOrLoad(
        paywallId: responseIdentifiers.paywallId,
        fromEvent: event
      )

      response.experiment = responseIdentifiers.experiment
      response.responseLoadStartTime = responseLoadStartTime
      response.responseLoadCompleteTime = Date()

      let paywallInfo = response.getPaywallInfo(fromEvent: event)

      let responseLoadEvent = InternalSuperwallEvent.PaywallResponseLoad(
        state: .complete(paywallInfo: paywallInfo),
        eventData: event
      )
      Paywall.track(responseLoadEvent)

      SessionEventsManager.shared.triggerSession.trackPaywallResponseLoad(
        forPaywallId: paywallInfo.id,
        state: .end
      )

      response = try await getProducts(
        from: response,
        substituteProducts: substituteProducts,
        withHash: paywallRequestHash,
        paywallInfo: paywallInfo,
        event: event
      )

      return response
    } catch {
      SessionEventsManager.shared.triggerSession.trackPaywallResponseLoad(
        forPaywallId: responseIdentifiers.paywallId,
        state: .fail
      )
      let errorResponse = PaywallResponseLogic.handlePaywallError(
        error,
        forEvent: event
      )
      throw errorResponse
    }
  }

  private func getProducts(
    from response: PaywallResponse,
    substituteProducts: PaywallProducts?,
    withHash paywallRequestHash: String,
    paywallInfo: PaywallInfo,
    event: EventData?
  ) async throws -> PaywallResponse {
    var response = response
    response.productsLoadStartTime = Date()

    let productLoadEvent = InternalSuperwallEvent.PaywallProductsLoad(
      state: .start,
      paywallInfo: paywallInfo,
      eventData: event
    )
    Paywall.track(productLoadEvent)

    SessionEventsManager.shared.triggerSession.trackProductsLoad(
      forPaywallId: paywallInfo.id,
      state: .start
    )

    do {
      let result = try await StoreKitManager.shared.getProducts(
        withIds: response.productIds,
        responseProducts: response.products,
        substituting: substituteProducts
      )

      return alteredResponse(
        response,
        withAppleProductsById: result.productsById,
        products: result.products,
        isNotSubstitutingProducts: substituteProducts == nil,
        requestHash: paywallRequestHash,
        paywallInfo: paywallInfo,
        event: event
      )
    } catch {
      response.productsLoadFailTime = Date()
      let paywallInfo = response.getPaywallInfo(fromEvent: event)
      let productLoadEvent = InternalSuperwallEvent.PaywallProductsLoad(
        state: .fail,
        paywallInfo: paywallInfo,
        eventData: event
      )
      Paywall.track(productLoadEvent)

      SessionEventsManager.shared.triggerSession.trackProductsLoad(
        forPaywallId: paywallInfo.id,
        state: .fail
      )

      // TODO: This wasn't thrown before - it just died out. Check the reasoning behind this, if any
      throw error
    }
  }

  private func alteredResponse(
    _ response: PaywallResponse,
    withAppleProductsById productsById: [String: SKProduct],
    products: [Product],
    isNotSubstitutingProducts: Bool,
    requestHash paywallRequestHash: String,
    paywallInfo: PaywallInfo,
    event: EventData?
  ) -> PaywallResponse {
    let outcome = PaywallResponseLogic.alterResponse(
      response,
      products: products,
      productsById: productsById,
      isFreeTrialAvailableOverride: Paywall.isFreeTrialAvailableOverride
    )

    var response = outcome.response

    if outcome.resetFreeTrialOverride {
      Paywall.isFreeTrialAvailableOverride = nil
    }

    /*
     TODO: ADD IN SUBSTITUTION OF PRODUCTS
      // cache the response for later if we haven't substituted products.
    if isNotSubstitutingProducts {
      self.responsesByHash[paywallRequestHash] = .success(response)
    }
     */

    return response


    response.productsLoadCompleteTime = Date()

    let paywallInfo = response.getPaywallInfo(fromEvent: event)
    SessionEventsManager.shared.triggerSession.trackProductsLoad(
      forPaywallId: paywallInfo.id,
      state: .end
    )
    let productLoadEvent = InternalSuperwallEvent.PaywallProductsLoad(
      state: .complete,
      paywallInfo: paywallInfo,
      eventData: event
    )
    Paywall.track(productLoadEvent)
  }
}
