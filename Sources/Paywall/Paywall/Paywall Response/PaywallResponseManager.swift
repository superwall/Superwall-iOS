//
//  File.swift
//  
//
//  Created by Jake Mor on 10/19/21.
//

import Foundation
import StoreKit

typealias PaywallResponseCompletionBlock = (Result<PaywallResponse, NSError>) -> Void

final class PaywallResponseManager: NSObject {
	static let shared = PaywallResponseManager()

  private let queue = DispatchQueue(label: "PaywallRequests")
	private var cachedResponsesByIdentifier: [String: PaywallResponse] = [:]
	private var responsesByHash: [String: Result<PaywallResponse, NSError>] = [:]
	private var handlersByHash: [String: [PaywallResponseCompletionBlock]] = [:]

	func getResponse(
    from eventData: EventData? = nil,
    withIdentifiers responseIdentifiers: ResponseIdentifiers,
    substituteProducts: PaywallProducts? = nil,
    completion: @escaping PaywallResponseCompletionBlock
  ) {
    let paywallRequestHash = PaywallResponseLogic.requestHash(
      identifier: responseIdentifiers.paywallId,
      event: eventData
    )

    let paywallResponseCachingOutcome = PaywallResponseLogic.searchForPaywallResponse(
      forEvent: eventData,
      withHash: paywallRequestHash,
      identifiers: responseIdentifiers,
      hasSubstituteProducts: substituteProducts != nil,
      inResultsCache: responsesByHash,
      handlersCache: handlersByHash,
      isDebuggerLaunched: SWDebugManager.shared.isDebuggerLaunched
    )

    switch paywallResponseCachingOutcome {
    case .cachedResult(let result):
      onMain {
        completion(result)
      }
      return
    case let .enqueCompletionBlock(hash, completionBlocks):
      handlersByHash[hash] = completionBlocks + [completion]
      return
    case .setCompletionBlock(let hash):
      handlersByHash[hash] = [completion]
    }

    loadPaywall(
      forEvent: eventData,
      withHash: paywallRequestHash,
      responseIdentifiers: responseIdentifiers,
      substituteProducts: substituteProducts
    )
	}

  private func getCachedResponseOrLoad(
    paywallId: String?,
    fromEvent event: EventData?,
    completion: @escaping (Result<PaywallResponse, Error>) -> Void
  ) {
    if let paywallResponse = ConfigManager.shared.getStaticPaywallResponse(
      forPaywallId: paywallId
    ) {
      completion(.success(paywallResponse))
    } else {
      Network.shared.getPaywallResponse(
        withPaywallId: paywallId,
        fromEvent: event
      ) { result in
        self.queue.async {
          completion(result)
        }
      }
    }
  }

  private func loadPaywall(
    forEvent event: EventData?,
    withHash paywallRequestHash: String,
    responseIdentifiers: ResponseIdentifiers,
    substituteProducts: PaywallProducts?
  ) {
    queue.async { [weak self] in
      guard let self = self else {
        return
      }
      let responseLoadStartTime = Date()

      SessionEventsManager.shared.triggerSession.trackPaywallResponseLoad(
        forPaywallId: responseIdentifiers.paywallId,
        state: .start
      )

      let trackedEvent = SuperwallEvent.PaywallResponseLoad(
        state: .start,
        eventData: event
      )
      Paywall.track(trackedEvent)

      self.getCachedResponseOrLoad(
        paywallId: responseIdentifiers.paywallId,
        fromEvent: event
      ) { result in
        switch result {
        case .success(var response):
          response.experiment = responseIdentifiers.experiment
          response.responseLoadStartTime = responseLoadStartTime
          response.responseLoadCompleteTime = Date()

          let paywallInfo = response.getPaywallInfo(fromEvent: event)

          let responseLoadEvent = SuperwallEvent.PaywallResponseLoad(
            state: .complete(paywallInfo: paywallInfo),
            eventData: event
          )
          Paywall.track(responseLoadEvent)

          SessionEventsManager.shared.triggerSession.trackPaywallResponseLoad(
            forPaywallId: paywallInfo.id,
            state: .end
          )

          self.getProducts(
            from: response,
            substituteProducts: substituteProducts,
            withHash: paywallRequestHash,
            paywallInfo: paywallInfo,
            event: event
          )
        case .failure(let error):
          SessionEventsManager.shared.triggerSession.trackPaywallResponseLoad(
            forPaywallId: responseIdentifiers.paywallId,
            state: .fail
          )
          guard let errorResponse = PaywallResponseLogic.handlePaywallError(
            error,
            forEvent: event,
            withHash: paywallRequestHash,
            handlersCache: self.handlersByHash
          ) else {
            return
          }

          onMain {
            for handler in errorResponse.handlers {
              handler(.failure(errorResponse.error))
            }
          }

          // reset the handler cache
          self.handlersByHash.removeValue(forKey: paywallRequestHash)
        }
      }
    }
  }

  private func getProducts(
    from response: PaywallResponse,
    substituteProducts: PaywallProducts?,
    withHash paywallRequestHash: String,
    paywallInfo: PaywallInfo,
    event: EventData?
  ) {
    var response = response
    response.productsLoadStartTime = Date()

    let productLoadEvent = SuperwallEvent.PaywallProductsLoad(
      state: .start,
      paywallInfo: paywallInfo,
      eventData: event
    )
    Paywall.track(productLoadEvent)

    SessionEventsManager.shared.triggerSession.trackProductsLoad(
      forPaywallId: paywallInfo.id,
      state: .start
    )

    StoreKitManager.shared.getProducts(
      withIds: response.productIds,
      substituting: substituteProducts
    ) { [weak self] result in
      switch result {
      case .success(let output):
        self?.alterResponse(
          response,
          withAppleProductsById: output.productsById,
          substituteResponseProducts: output.substituteProducts,
          requestHash: paywallRequestHash,
          paywallInfo: paywallInfo,
          event: event
        )
      case .failure:
        response.productsLoadFailTime = Date()
        let paywallInfo = response.getPaywallInfo(fromEvent: event)
        let productLoadEvent = SuperwallEvent.PaywallProductsLoad(
          state: .fail,
          paywallInfo: paywallInfo,
          eventData: event
        )
        Paywall.track(productLoadEvent)

        SessionEventsManager.shared.triggerSession.trackProductsLoad(
          forPaywallId: paywallInfo.id,
          state: .fail
        )
      }
    }
  }

  private func alterResponse(
    _ response: PaywallResponse,
    withAppleProductsById productsById: [String: SKProduct],
    substituteResponseProducts: [Product],
    requestHash paywallRequestHash: String,
    paywallInfo: PaywallInfo,
    event: EventData?
  ) {
    let outcome = PaywallResponseLogic.alterResponse(
      response,
      substituteResponseProducts: substituteResponseProducts,
      productsById: productsById,
      isFreeTrialAvailableOverride: Paywall.isFreeTrialAvailableOverride
    )

    var response = outcome.response

    if outcome.resetFreeTrialOverride {
      Paywall.isFreeTrialAvailableOverride = nil
    }

      // cache the response for later if we haven't substituted products.
    if substituteResponseProducts.isEmpty {
      self.responsesByHash[paywallRequestHash] = .success(response)
    }

    // execute all the cached handlers
    if let handlers = self.handlersByHash[paywallRequestHash] {
      onMain {
        for handler in handlers {
          handler(.success(response))
        }
      }
    }

    // reset the handler cache
    self.handlersByHash.removeValue(forKey: paywallRequestHash)

    response.productsLoadCompleteTime = Date()

    let paywallInfo = response.getPaywallInfo(fromEvent: event)
    SessionEventsManager.shared.triggerSession.trackProductsLoad(
      forPaywallId: paywallInfo.id,
      state: .end
    )
    let productLoadEvent = SuperwallEvent.PaywallProductsLoad(
      state: .complete,
      paywallInfo: paywallInfo,
      eventData: event
    )
    Paywall.track(productLoadEvent)
  }
}
