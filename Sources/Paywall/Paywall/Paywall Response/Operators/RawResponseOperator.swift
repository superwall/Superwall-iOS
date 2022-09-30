//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Combine
import Foundation

extension AnyPublisher where Output == PaywallRequest, Failure == Error {
  func getRawResponse() -> AnyPublisher<PipelineData, Failure> {
    map { request in
      trackResponseStarted(
        paywallId: request.responseIdentifiers.paywallId,
        event: request.eventData
      )
      return request
    }
    .flatMap(getCachedResponseOrLoad)
    .map {
      let paywallInfo = $0.response.getPaywallInfo(fromEvent: $0.request.eventData)
      trackResponseLoaded(
        paywallInfo,
        event: $0.request.eventData
      )
      return $0
    }
    .eraseToAnyPublisher()
  }

  private func getCachedResponseOrLoad(
    _ request: PaywallRequest
  ) -> AnyPublisher<(response: PaywallResponse, request: PaywallRequest), Error> {
    Future {
      let responseLoadStartTime = Date()
      let paywallId = request.responseIdentifiers.paywallId
      let event = request.eventData
      var response: PaywallResponse

      do {
        if let paywallResponse = ConfigManager.shared.getStaticPaywallResponse(forPaywallId: paywallId) {
          response = paywallResponse
        } else {
          response = try await Network.shared.getPaywallResponse(
            withPaywallId: paywallId,
            fromEvent: event
          )
        }
      } catch {
        SessionEventsManager.shared.triggerSession.trackPaywallResponseLoad(
          forPaywallId: request.responseIdentifiers.paywallId,
          state: .fail
        )
        let errorResponse = PaywallResponseLogic.handlePaywallError(
          error,
          forEvent: event
        )
        throw errorResponse
      }

      response.experiment = request.responseIdentifiers.experiment
      response.responseLoadStartTime = responseLoadStartTime
      response.responseLoadCompleteTime = Date()

      return (response, request)
    }
    .eraseToAnyPublisher()
  }

  // MARK: - Analytics
  private func trackResponseStarted(
    paywallId: String?,
    event: EventData?
  ) {
    SessionEventsManager.shared.triggerSession.trackPaywallResponseLoad(
      forPaywallId: paywallId,
      state: .start
    )
    let trackedEvent = InternalSuperwallEvent.PaywallResponseLoad(
      state: .start,
      eventData: event
    )
    Paywall.track(trackedEvent)
  }

  private func trackResponseLoaded(
    _ paywallInfo: PaywallInfo,
    event: EventData?
  ) {
    let responseLoadEvent = InternalSuperwallEvent.PaywallResponseLoad(
      state: .complete(paywallInfo: paywallInfo),
      eventData: event
    )
    Paywall.track(responseLoadEvent)

    SessionEventsManager.shared.triggerSession.trackPaywallResponseLoad(
      forPaywallId: paywallInfo.id,
      state: .end
    )
  }
}
