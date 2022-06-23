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
    _ presentationInfo: PresentationInfo,
    completion: @escaping PaywallResponseCompletionBlock
  ) {
    do {
      let eventData = presentationInfo.eventData

      var triggerIdentifiers: TriggerResponseIdentifiers

      if let eventData = eventData,
        Paywall.shared.configManager.didFetchConfig {
        let triggerOutcome = TriggerLogic.outcome(
          forEvent: eventData,
          triggers: Storage.shared.triggers
        )

        // Confirm any triggers that the user is assigned
        if let confirmableAssignments = triggerOutcome.confirmableAssignments {
          Network.shared.confirmAssignments(confirmableAssignments)
        }

        triggerIdentifiers = try PaywallResponseLogic.getTriggerIdentifiers(
          forResult: triggerOutcome.result,
          eventData: eventData
        )
      } else {
        triggerIdentifiers = TriggerResponseIdentifiers(paywallId: presentationInfo.identifier)
      }

      let paywallRequestHash = PaywallResponseLogic.requestHash(
        identifier: triggerIdentifiers.paywallId,
        event: eventData
      )

      let paywallResponseCachingOutcome = PaywallResponseLogic.searchForPaywallResponse(
        forEvent: eventData,
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
        forEvent: eventData,
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
    triggerIdentifiers: TriggerResponseIdentifiers
  ) {
    queue.async { [weak self] in
      guard let self = self else {
        return
      }
      let responseLoadStartTime = Date()

      SessionEventsManager.shared.triggerSession.trackPaywallResponseLoad(
        forPaywallId: triggerIdentifiers.paywallId,
        state: .start
      )

      let trackedEvent = SuperwallEvent.PaywallResponseLoad(
        state: .start,
        eventData: event
      )
      Paywall.track(trackedEvent)

      Network.shared.getPaywallResponse(
        withPaywallId: triggerIdentifiers.paywallId,
        fromEvent: event
      ) { result in
        self.queue.async {
          switch result {
          case .success(var response):
            response.experiment = triggerIdentifiers.experiment
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
              withHash: paywallRequestHash,
              paywallInfo: paywallInfo,
              event: event
            )
          case .failure(let error):
            SessionEventsManager.shared.triggerSession.trackPaywallResponseLoad(
              forPaywallId: triggerIdentifiers.paywallId,
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
  }

  private func getProducts(
    from response: PaywallResponse,
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

    // add its products
    StoreKitManager.shared.getProducts(withIds: response.productIds) { [weak self] result in
      switch result {
      case .success(let productsById):
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
}
