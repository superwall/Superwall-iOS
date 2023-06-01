//
//  File.swift
//  
//
//  Created by Yusuf Tör on 12/05/2023.
//

import Foundation

extension PaywallRequestManager {
  func getRawPaywall(
    from request: PaywallRequest,
    withHash hash: String
  ) async throws -> Paywall {
    await trackResponseStarted(
      paywallId: request.responseIdentifiers.paywallId,
      event: request.eventData
    )
    let paywall = try await getPaywallResponse(from: request, withHash: hash)

    let paywallInfo = paywall.getInfo(
      fromEvent: request.eventData,
      factory: factory
    )
    await trackResponseLoaded(
      paywallInfo,
      event: request.eventData
    )

    return paywall
  }

  private func getPaywallResponse(
    from request: PaywallRequest,
    withHash hash: String
  ) async throws -> Paywall {
    let responseLoadStartTime = Date()
    let paywallId = request.responseIdentifiers.paywallId
    let event = request.eventData
    var paywall: Paywall

    do {
      if let staticPaywall = factory.makeStaticPaywall(withId: paywallId) {
        paywall = staticPaywall
      } else {
        paywall = try await network.getPaywall(
          withId: paywallId,
          fromEvent: event
        )
      }
    } catch {
      let triggerSessionManager = factory.getTriggerSessionManager()
      await triggerSessionManager.trackPaywallResponseLoad(
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

    return paywall
  }

  // MARK: - Analytics
  private func trackResponseStarted(
    paywallId: String?,
    event: EventData?
  ) async {
    let triggerSessionManager = factory.getTriggerSessionManager()
    await triggerSessionManager.trackPaywallResponseLoad(
      forPaywallId: paywallId,
      state: .start
    )
    let trackedEvent = InternalSuperwallEvent.PaywallLoad(
      state: .start,
      eventData: event
    )
    await Superwall.shared.track(trackedEvent)
  }

  private func trackResponseLoaded(
    _ paywallInfo: PaywallInfo,
    event: EventData?
  ) async {
    let responseLoadEvent = InternalSuperwallEvent.PaywallLoad(
      state: .complete(paywallInfo: paywallInfo),
      eventData: event
    )
    await Superwall.shared.track(responseLoadEvent)

    let triggerSessionManager = factory.getTriggerSessionManager()
    await triggerSessionManager.trackPaywallResponseLoad(
      forPaywallId: paywallInfo.databaseId,
      state: .end
    )
  }
}
