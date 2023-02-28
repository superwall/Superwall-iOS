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
        event: input.request.eventData,
        sessionEventsManager: input.request.dependencyContainer.sessionEventsManager
      )
      return input
    }
    .map { $0.paywall }
    .eraseToAnyPublisher()
  }

  private func getProducts(_ input: PipelineData) -> AnyPublisher<PipelineData, Error> {
    Future {
      do {
        let result = try await input.request.dependencyContainer.storeKitManager.getProducts(
          withIds: input.paywall.productIds,
          responseProducts: input.paywall.products,
          substituting: input.request.overrides.products
        )

        var paywall = input.paywall
        paywall.products = result.products

        let outcome = await PaywallLogic.getVariablesAndFreeTrial(
          fromProducts: result.products,
          productsById: result.productsById,
          isFreeTrialAvailableOverride: input.request.overrides.isFreeTrial,
          isFreeTrialAvailable: input.request.dependencyContainer.storeKitManager.isFreeTrialAvailable(for:)
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
        let paywallInfo = input.paywall.getInfo(
          fromEvent: input.request.eventData,
          sessionEventsManager: input.request.dependencyContainer.sessionEventsManager
        )
        await trackProductLoadFail(
          paywallInfo: paywallInfo,
          event: input.request.eventData,
          sessionEventsManager: input.request.dependencyContainer.sessionEventsManager
        )
        throw error
      }
    }
    .eraseToAnyPublisher()
  }

  // MARK: - Analytics
  private func trackProductsLoadStart(_ input: PipelineData) async {
    var input = input
    input.paywall.productsLoadingInfo.startAt = Date()
    let paywallInfo = input.paywall.getInfo(
      fromEvent: input.request.eventData,
      sessionEventsManager: input.request.dependencyContainer.sessionEventsManager
    )
    let productLoadEvent = InternalSuperwallEvent.PaywallProductsLoad(
      state: .start,
      paywallInfo: paywallInfo,
      eventData: input.request.eventData
    )
    await Superwall.shared.track(productLoadEvent)

    await input.request.dependencyContainer.sessionEventsManager.triggerSession.trackProductsLoad(
      forPaywallId: paywallInfo.databaseId,
      state: .start
    )
  }

  private func trackProductLoadFail(
    paywallInfo: PaywallInfo,
    event: EventData?,
    sessionEventsManager: SessionEventsManager
  ) async {
    let productLoadEvent = InternalSuperwallEvent.PaywallProductsLoad(
      state: .fail,
      paywallInfo: paywallInfo,
      eventData: event
    )
    await Superwall.shared.track(productLoadEvent)

    await sessionEventsManager.triggerSession.trackProductsLoad(
      forPaywallId: paywallInfo.databaseId,
      state: .fail
    )
  }

  private func trackProductsLoadFinish(
    paywall: Paywall,
    event: EventData?,
    sessionEventsManager: SessionEventsManager
  ) async {
    let paywallInfo = paywall.getInfo(
      fromEvent: event,
      sessionEventsManager: sessionEventsManager
    )
    await sessionEventsManager.triggerSession.trackProductsLoad(
      forPaywallId: paywallInfo.databaseId,
      state: .end
    )
    let productLoadEvent = InternalSuperwallEvent.PaywallProductsLoad(
      state: .complete,
      paywallInfo: paywallInfo,
      eventData: event
    )
    await Superwall.shared.track(productLoadEvent)
  }
}
