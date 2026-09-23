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

    // The local surface replaces the published paywall's bytes, products and
    // whatever settings its config.ts declares, and inherits the rest from the
    // paywall it stands in for — see Paywall.devServer(surface:url:inheriting:).
    // The synthesized cacheKey embeds the mount URL, so a moved dev server or
    // a published fallback reloads the web view instead of presenting the
    // stale page.
    let devPaywall = Paywall.devServer(
      surface: surface,
      url: mountURL,
      inheriting: paywall
    )

    Logger.debug(
      logLevel: .info,
      scope: .superwallCore,
      message: "Dev server override: paywall \(paywall.identifier) is served as local surface "
        + "\(surface.id) from \(mountURL.absoluteString)."
    )
    return devPaywall
  }

  /// Resolves a synthetic `dev:` identifier — a dev-server surface the
  /// debugger selected that has never been pushed to the dashboard — from the
  /// dev server's manifest, since the backend has nothing to fetch for it.
  ///
  /// The manifest is fetched again here rather than read from the copy the
  /// debugger took when it opened: the surface's products and presentation
  /// settings come from its config.ts, and edits made since must reach the
  /// next presentation.
  private func devServerPaywall(forId paywallId: String?) async -> Paywall? {
    guard let paywallId = paywallId else {
      return nil
    }
    guard paywallId.hasPrefix("dev:") else {
      return nil
    }
    let options = factory.makeSuperwallOptions()
    guard DevMode.isActive(options) else {
      return nil
    }
    // `dev:` identifiers only come from the debugger, so without its snapshot
    // there is nothing to present and no reason to probe for a server.
    guard let snapshot = await MainActor.run(body: {
      Superwall.shared.dependencyContainer.debugManager.devServer
    }) else {
      return nil
    }
    let fresh = await DevServerLocator.shared.locate(devServerURL: options.devServerURL)
    if let fresh = fresh {
      // The debugger's picker and any later presentation read this copy, so
      // it has to describe the same server the presentation does.
      await MainActor.run {
        Superwall.shared.dependencyContainer.debugManager.devServer = (
          base: fresh.base,
          surfaces: fresh.manifest.surfaces
        )
      }
    }
    guard let resolved = DevServerPreview.resolveSurface(
      previewIdentifier: paywallId,
      fresh: fresh,
      snapshot: snapshot
    ) else {
      return nil
    }
    return Paywall.devServer(surface: resolved.surface, url: resolved.url)
  }

  private func getPaywallResponse(
    from request: PaywallRequest
  ) async throws -> Paywall {
    let responseLoadStartTime = Date()
    let paywallId = request.responseIdentifiers.paywallId
    let placement = request.placementData
    var paywall: Paywall

    do {
      if let devPaywall = await devServerPaywall(forId: paywallId) {
        paywall = devPaywall
      } else if let staticPaywall = factory.makeStaticPaywall(
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
