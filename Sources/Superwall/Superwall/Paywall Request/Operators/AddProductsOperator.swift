//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Combine
import Foundation

typealias PipelineData = (paywall: Paywall, request: PaywallRequest)

extension AnyPublisher where Output == PipelineData, Failure == Error {
  func addProducts() -> AnyPublisher<Output, Failure> {
    map { input in
      trackProductsLoadStart(
        paywall: input.paywall,
        event: input.request.eventData
      )
      return input
    }
    .flatMap(getProducts)
    .map { input in
      trackProductsLoadFinish(
        paywall: input.paywall,
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
          withIds: input.paywall.productIds,
          responseProducts: input.paywall.products,
          substituting: input.request.substituteProducts
        )

        var paywall = input.paywall
        paywall.products = result.products

        let outcome = PaywallLogic.getVariablesAndFreeTrial(
          fromProducts: result.products,
          productsById: result.productsById,
          isFreeTrialAvailableOverride: Superwall.isFreeTrialAvailableOverride
        )
        paywall.swProducts = outcome.orderedSwProducts
        paywall.productVariables = outcome.productVariables
        paywall.swProductVariablesTemplate = outcome.swProductVariablesTemplate
        paywall.isFreeTrialAvailable = outcome.isFreeTrialAvailable

        if outcome.resetFreeTrialOverride {
          Superwall.isFreeTrialAvailableOverride = nil
        }

        paywall.productsLoadingInfo.endAt = Date()
        return (paywall, input.request)
      } catch {
        var input = input
        input.paywall.productsLoadingInfo.failAt = Date()
        let paywallInfo = input.paywall.getInfo(fromEvent: input.request.eventData)
        trackProductLoadFail(paywallInfo: paywallInfo, event: input.request.eventData)
        throw error
      }
    }
    .eraseToAnyPublisher()
  }

  // MARK: - Analytics
  private func trackProductsLoadStart(
    paywall: Paywall,
    event: EventData?
  ) {
    var paywall = paywall
    paywall.productsLoadingInfo.startAt = Date()
    let paywallInfo = paywall.getInfo(fromEvent: event)
    let productLoadEvent = InternalSuperwallEvent.PaywallProductsLoad(
      state: .start,
      paywallInfo: paywallInfo,
      eventData: event
    )
    Superwall.track(productLoadEvent)

    SessionEventsManager.shared.triggerSession.trackProductsLoad(
      forPaywallId: paywallInfo.databaseId,
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
    Superwall.track(productLoadEvent)

    SessionEventsManager.shared.triggerSession.trackProductsLoad(
      forPaywallId: paywallInfo.databaseId,
      state: .fail
    )
  }

  private func trackProductsLoadFinish(
    paywall: Paywall,
    event: EventData?
  ) {
    let paywallInfo = paywall.getInfo(fromEvent: event)
    SessionEventsManager.shared.triggerSession.trackProductsLoad(
      forPaywallId: paywallInfo.databaseId,
      state: .end
    )
    let productLoadEvent = InternalSuperwallEvent.PaywallProductsLoad(
      state: .complete,
      paywallInfo: paywallInfo,
      eventData: event
    )
    Superwall.track(productLoadEvent)
  }
}
