//
//  File.swift
//  
//
//  Created by Jake Mor on 10/19/21.
//

import Foundation

typealias PaywallResponseCompletionBlock = (Result<PaywallResponse, NSError>) -> Void

final class PaywallResponseManager: NSObject {
	static let shared = PaywallResponseManager()

  private let queue = DispatchQueue(label: "PaywallRequests")
	private var cachedResponsesByIdentifier: [String: PaywallResponse] = [:]
	private var responsesByHash: [String: Result<PaywallResponse, NSError>] = [:]
	private var handlersByHash: [String: [PaywallResponseCompletionBlock]] = [:]

	func getResponse(
    identifier: String? = nil,
    event: EventData? = nil,
    completion: @escaping PaywallResponseCompletionBlock
  ) {
    do {
      let triggerIdentifiers = try PaywallResponseLogic.handleTriggerResponse(
        withPaywallId: identifier,
        fromEvent: event,
        didFetchConfig: Paywall.shared.didFetchConfig
      )

      let paywallRequestHash = PaywallResponseLogic.requestHash(
        identifier: triggerIdentifiers.paywallId,
        event: event
      )

      let paywallResponseCachingOutcome = PaywallResponseLogic.searchForPaywallResponse(
        forEvent: event,
        withHash: paywallRequestHash,
        identifiers: triggerIdentifiers,
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
        forEvent: event,
        withHash: paywallRequestHash,
        triggerIdentifiers: triggerIdentifiers
      )
    } catch let error as NSError {
      return completion(.failure(error))
    }
	}

  private func loadPaywall(
    forEvent event: EventData?,
    withHash paywallRequestHash: String,
    triggerIdentifiers: TriggerResponseIdentifiers?
  ) {
    queue.async { [weak self] in
      guard let self = self else {
        return
      }
      let isFromEvent = event != nil

      let responseLoadStartTime = Date()
      Paywall.track(.paywallResponseLoadStart(fromEvent: isFromEvent, event: event))

      Network.shared.paywall(
        withIdentifier: triggerIdentifiers?.paywallId,
        fromEvent: event
      ) { result in
        self.queue.async {
          switch result {
          case .success(var response):
            response.experimentId = triggerIdentifiers?.experimentId
            response.variantId = triggerIdentifiers?.variantId
            response.responseLoadStartTime = responseLoadStartTime
            response.responseLoadCompleteTime = Date()
            response.productsLoadStartTime = Date()

            Paywall.track(
              .paywallResponseLoadComplete(
                fromEvent: isFromEvent,
                event: event,
                paywallInfo: response.getPaywallInfo(fromEvent: event)
              )
            )
            Paywall.track(
              .paywallProductsLoadStart(
                fromEvent: isFromEvent,
                event: event,
                paywallInfo: response.getPaywallInfo(fromEvent: event)
              )
            )

            self.getProducts(
              from: response,
              withHash: paywallRequestHash,
              event: event
            )
          case .failure(let error):
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
  }

  private func getProducts(
    from response: PaywallResponse,
    withHash paywallRequestHash: String,
    event: EventData?
  ) {
    var response = response

    // add its products
    StoreKitManager.shared.getProducts(withIds: response.productIds) { [weak self] productsById in
      guard let self = self else {
        return
      }

      let outcome = PaywallResponseLogic.getVariablesAndFreeTrial(
        fromProducts: response.products,
        productsById: productsById,
        isFreeTrialAvailableOverride: Paywall.isFreeTrialAvailableOverride
      )

      response.variables = outcome.variables
      response.productVariables = outcome.productVariables
      response.isFreeTrialAvailable = outcome.isFreeTrialAvailable

      if outcome.resetFreeTrialOverride {
        Paywall.isFreeTrialAvailableOverride = nil
      }

      // cache the response for later
      self.responsesByHash[paywallRequestHash] = .success(response)

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
      Paywall.track(
        .paywallProductsLoadComplete(
          fromEvent: event != nil,
          event: event,
          paywallInfo: response.getPaywallInfo(fromEvent: event)
        )
      )
    }
  }
}
