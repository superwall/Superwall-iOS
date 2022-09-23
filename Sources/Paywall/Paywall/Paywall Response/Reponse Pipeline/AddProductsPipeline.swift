//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Combine
import Foundation

typealias PipelineData = (response: PaywallResponse, request: PaywallResponseRequest)

extension AnyPublisher where Output == PipelineData, Failure == Error {
  func addProducts() -> AnyPublisher<Output, Failure> {
    self
      .map { input in
        trackProductsLoadStart(
          response: input.response,
          event: input.request.eventData
        )
        return input
      }
      .flatMap(getProducts)
      .map { input in
        trackProductsLoaded(
          paywallResponse: input.response,
          event: input.request.eventData
        )
        return input
      }
      .eraseToAnyPublisher()
  }

  private func getProducts(_ input: PipelineData) -> AnyPublisher<PipelineData, Error> {
    Future {
      do {
        let result = try await StoreKitManager.shared.getProducts(
          withIds: input.response.productIds,
          responseProducts: input.response.products,
          substituting: input.request.substituteProducts
        )

        var response = input.response
        response.products = result.products

        let outcome =  PaywallResponseLogic.getVariablesAndFreeTrial(
          fromProducts: result.products,
          productsById: result.productsById,
          isFreeTrialAvailableOverride: Paywall.isFreeTrialAvailableOverride
        )
        response.swProducts = outcome.orderedSwProducts
        response.variables = outcome.variables
        response.productVariables = outcome.productVariables
        response.isFreeTrialAvailable = outcome.isFreeTrialAvailable

        if outcome.resetFreeTrialOverride {
          Paywall.isFreeTrialAvailableOverride = nil
        }

        response.productsLoadCompleteTime = Date()
        return (response, input.request)
      } catch {
        var input = input
        input.response.productsLoadFailTime = Date()
        let paywallInfo = input.response.getPaywallInfo(fromEvent: input.request.eventData)
        trackProductLoadFail(paywallInfo: paywallInfo, event: input.request.eventData)
        throw error
      }
    }
    .eraseToAnyPublisher()
  }

  // MARK: - Analytics
  private func trackProductsLoadStart(
    response: PaywallResponse,
    event: EventData?
  ) {
    var response = response
    response.productsLoadStartTime = Date()
    let paywallInfo = response.getPaywallInfo(fromEvent: event)
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
  }

  private func trackProductLoadFail(
    paywallInfo: PaywallInfo,
    event: EventData?
  ) {
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
  }

  private func trackProductsLoaded(
    paywallResponse: PaywallResponse,
    event: EventData?
  ) {
    let paywallInfo = paywallResponse.getPaywallInfo(fromEvent: event)
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
