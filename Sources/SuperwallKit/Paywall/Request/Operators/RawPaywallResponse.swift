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
      placement: request.placementData
    )
    var paywall = try await getPaywallResponse(from: request)
    if !request.isDebuggerLaunched {
      paywall = await applyDevServerOverrideIfNeeded(to: paywall)
    }
    paywall.presentationId = UUID().uuidString

    let paywallInfo = paywall.getInfo(fromPlacement: request.placementData)
    await trackResponseLoaded(
      paywallInfo,
      placement: request.placementData
    )

    return paywall
  }

  func applyDevServerOverrideIfNeeded(to paywall: Paywall) async -> Paywall {
    let options = factory.makeSuperwallOptions()
    guard DevMode.isActive(options) else {
      return paywall
    }
    guard
      let location = await DevServerLocator.shared.locate(devServerURL: options.devServerURL),
      let surface = location.manifest.surface(forPaywallDatabaseId: paywall.databaseId),
      let mountURL = location.manifest.mountURL(for: surface, base: location.base)
    else {
      return paywall
    }

    var paywall = paywall
    paywall.url = mountURL
    // A changed cacheKey is what makes an already-cached view controller
    // reload its web view; without it a moved dev server or a published
    // fallback would present the stale page.
    paywall.cacheKey = "dev:\(paywall.cacheKey):\(mountURL.absoluteString)"
    paywall.urlConfig = WebViewURLConfig(
      endpoints: [
        WebViewEndpoint(
          url: mountURL,
          timeout: 15,
          percentage: 100
        )
      ],
      maxAttempts: 1
    )
    paywall.manifest = nil

    Logger.debug(
      logLevel: .info,
      scope: .superwallCore,
      message: "Dev server override: paywall \(paywall.identifier) renders from \(mountURL.absoluteString)."
    )
    return paywall
  }

  private func getPaywallResponse(
    from request: PaywallRequest
  ) async throws -> Paywall {
    let responseLoadStartTime = Date()
    let paywallId = request.responseIdentifiers.paywallId
    let placement = request.placementData
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
          fromPlacement: placement,
          retryCount: request.retryCount
        )
      }
    } catch {
      let errorResponse = PaywallLogic.handlePaywallError(
        error,
        forPlacement: placement
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
    placement: PlacementData?
  ) async {
    let paywallLoad = InternalSuperwallEvent.PaywallLoad(
      state: .start,
      placementData: placement
    )
    await Superwall.shared.track(paywallLoad)
  }

  private func trackResponseLoaded(
    _ paywallInfo: PaywallInfo,
    placement: PlacementData?
  ) async {
    let paywallLoad = InternalSuperwallEvent.PaywallLoad(
      state: .complete(paywallInfo: paywallInfo),
      placementData: placement
    )
    await Superwall.shared.track(paywallLoad)
  }
}
