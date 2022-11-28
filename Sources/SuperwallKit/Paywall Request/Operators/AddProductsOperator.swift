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
  func addProducts() -> AnyPublisher<Paywall, Failure> {
    asyncMap { input in
      var input = input
      input.paywall.productsLoadingInfo.startAt = Date()
      await trackProductsLoadStart(input)
      return input
    }
    .flatMap(getProducts)
    .asyncMap { input in
      await trackProductsLoadFinish(
        paywall: input.paywall,
        event: input.request.eventData
      )
      return input
    }
    .map { $0.paywall }
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
          isFreeTrialAvailableOverride: input.request.overrides.isFreeTrial
        )
        paywall.swProducts = outcome.orderedSwProducts
        paywall.productVariables = outcome.productVariables
        paywall.swProductVariablesTemplate = outcome.swProductVariablesTemplate
        paywall.isFreeTrialAvailable = outcome.isFreeTrialAvailable

        paywall.productsLoadingInfo.endAt = Date()
        return (paywall, input.request)
      } catch {
        var input = input
        input.paywall.productsLoadingInfo.failAt = Date()
        let paywallInfo = input.paywall.getInfo(fromEvent: input.request.eventData)
        await trackProductLoadFail(paywallInfo: paywallInfo, event: input.request.eventData)
        throw error
      }
    }
    .eraseToAnyPublisher()
  }

  // MARK: - Analytics
  private func trackProductsLoadStart(_ input: PipelineData) async {
    var input = input
    input.paywall.productsLoadingInfo.startAt = Date()
    let paywallInfo = input.paywall.getInfo(fromEvent: input.request.eventData)
    let productLoadEvent = InternalSuperwallEvent.PaywallProductsLoad(
      state: .start,
      paywallInfo: paywallInfo,
      eventData: input.request.eventData
    )
    await Superwall.track(productLoadEvent)

    await SessionEventsManager.shared.triggerSession.trackProductsLoad(
      forPaywallId: paywallInfo.databaseId,
      state: .start
    )
  }

  private func trackProductLoadFail(
    paywallInfo: PaywallInfo,
    event: EventData?
  ) async {
    let productLoadEvent = InternalSuperwallEvent.PaywallProductsLoad(
      state: .fail,
      paywallInfo: paywallInfo,
      eventData: event
    )
    await Superwall.track(productLoadEvent)

    await SessionEventsManager.shared.triggerSession.trackProductsLoad(
      forPaywallId: paywallInfo.databaseId,
      state: .fail
    )
  }

  private func trackProductsLoadFinish(
    paywall: Paywall,
    event: EventData?
  ) async {
    let paywallInfo = paywall.getInfo(fromEvent: event)
    await SessionEventsManager.shared.triggerSession.trackProductsLoad(
      forPaywallId: paywallInfo.databaseId,
      state: .end
    )
    let productLoadEvent = InternalSuperwallEvent.PaywallProductsLoad(
      state: .complete,
      paywallInfo: paywallInfo,
      eventData: event
    )
    await Superwall.track(productLoadEvent)
  }
}
