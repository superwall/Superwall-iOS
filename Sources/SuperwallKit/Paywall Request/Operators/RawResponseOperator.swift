//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Combine
import Foundation

extension AnyPublisher where Output == PaywallRequest, Failure == Error {
  func getRawPaywall() -> AnyPublisher<PipelineData, Failure> {
    asyncMap { request in
      await trackResponseStarted(
        paywallId: request.responseIdentifiers.paywallId,
        event: request.eventData
      )
      return request
    }
    .flatMap(getCachedResponseOrLoad)
    .asyncMap {
      let paywallInfo = $0.paywall.getInfo(fromEvent: $0.request.eventData)
      await trackResponseLoaded(
        paywallInfo,
        event: $0.request.eventData
      )
      return $0
    }
    .eraseToAnyPublisher()
  }

  private func getCachedResponseOrLoad(
    _ request: PaywallRequest
  ) -> AnyPublisher<(paywall: Paywall, request: PaywallRequest), Error> {
    Future {
      let responseLoadStartTime = Date()
      let paywallId = request.responseIdentifiers.paywallId
      let event = request.eventData
      var paywall: Paywall

      do {
        if let staticPaywall = ConfigManager.shared.getStaticPaywall(withId: paywallId) {
          paywall = staticPaywall
        } else {
          paywall = try await Network.shared.getPaywall(
            withId: paywallId,
            fromEvent: event
          )
        }
      } catch {
        await SessionEventsManager.shared.triggerSession.trackPaywallResponseLoad(
          forPaywallId: request.responseIdentifiers.paywallId,
          state: .fail
        )
        let errorResponse = PaywallLogic.handlePaywallError(
          error,
          forEvent: event
        )
        throw errorResponse
      }

      paywall.experiment = request.responseIdentifiers.experiment
      paywall.responseLoadingInfo.startAt = responseLoadStartTime
      paywall.responseLoadingInfo.endAt = Date()

      return (paywall, request)
    }
    .eraseToAnyPublisher()
  }

  // MARK: - Analytics
  private func trackResponseStarted(
    paywallId: String?,
    event: EventData?
  ) async {
    await SessionEventsManager.shared.triggerSession.trackPaywallResponseLoad(
      forPaywallId: paywallId,
      state: .start
    )
    let trackedEvent = InternalSuperwallEvent.PaywallLoad(
      state: .start,
      eventData: event
    )
    await Superwall.track(trackedEvent)
  }

  private func trackResponseLoaded(
    _ paywallInfo: PaywallInfo,
    event: EventData?
  ) async {
    let responseLoadEvent = InternalSuperwallEvent.PaywallLoad(
      state: .complete(paywallInfo: paywallInfo),
      eventData: event
    )
    await Superwall.track(responseLoadEvent)

    await SessionEventsManager.shared.triggerSession.trackPaywallResponseLoad(
      forPaywallId: paywallInfo.databaseId,
      state: .end
    )
  }
}
