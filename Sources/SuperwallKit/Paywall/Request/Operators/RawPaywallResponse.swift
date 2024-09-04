//
//  File.swift
//  
//
//  Created by Yusuf Tör on 12/05/2023.
//

import Foundation

extension PaywallRequestManager {
  func getRawPaywall(
    from request: PaywallRequest
  ) async throws -> Paywall {
    await trackResponseStarted(
      paywallId: request.responseIdentifiers.paywallId,
      event: request.placementData
    )
    let paywall = try await getPaywallResponse(from: request)

    let paywallInfo = paywall.getInfo(fromPlacement: request.placementData)
    await trackResponseLoaded(
      paywallInfo,
      event: request.placementData
    )

    return paywall
  }

  private func getPaywallResponse(
    from request: PaywallRequest
  ) async throws -> Paywall {
    let responseLoadStartTime = Date()
    let paywallId = request.responseIdentifiers.paywallId
    let event = request.placementData
    var paywall: Paywall

    do {
      if let staticPaywall = factory.makeStaticPaywall(
        withId: paywallId,
        isDebuggerLaunched: request.isDebuggerLaunched
      ) {
        paywall = staticPaywall
      } else {
        paywall = try await network.getPaywall(
          withId: paywallId,
          fromPlacement: event,
          retryCount: request.retryCount
        )
      }
    } catch {
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
    event: PlacementData?
  ) async {
    let trackedEvent = InternalSuperwallPlacement.PaywallLoad(
      state: .start,
      placementData: event
    )
    await Superwall.shared.track(trackedEvent)
  }

  private func trackResponseLoaded(
    _ paywallInfo: PaywallInfo,
    event: PlacementData?
  ) async {
    let responseLoadEvent = InternalSuperwallPlacement.PaywallLoad(
      state: .complete(paywallInfo: paywallInfo),
      placementData: event
    )
    await Superwall.shared.track(responseLoadEvent)
  }
}
