//
//  File 2.swift
//  
//
//  Created by Yusuf Tör on 27/06/2024.
//

import Foundation

protocol SWWebViewLoadingDelegate: AnyObject {
  func loadWebView(
    with url: URL
  ) async throws
}

final class SWWebViewLoadingHandler {
  weak var loadingDelegate: SWWebViewLoadingDelegate?
  weak var webViewDelegate: (SWWebViewDelegate & PaywallMessageHandlerDelegate)?
  var didFailToLoad = false

  func load(
    attempts: Int = 0,
    maxAttempts: Int,
    attemptedURLs: [URL] = [],
    endpoints: [WebViewEndpoint]
  ) async -> Bool {
    guard let delegate = loadingDelegate else {
      didFailToLoad = true
      return false
    }
    var endpoints = endpoints

    guard attempts < maxAttempts else {
      await trackWebViewLoadFailure(WebViewError.exceededAttempts, urls: attemptedURLs)
      didFailToLoad = true
      return false
    }
    guard let url = SWWebViewLogic.chooseURL(from: endpoints) else {
      await trackWebViewLoadFailure(WebViewError.noEndpoints, urls: [])
      didFailToLoad = true
      return false
    }

    do {
      try await delegate.loadWebView(with: url)
      didFailToLoad = false
      return true
    } catch {
      if let invalidURLIndex = endpoints.firstIndex(where: { $0.url == url }) {
        await trackWebViewLoadFailure(error, urls: [url])

        endpoints.remove(at: invalidURLIndex)
        if endpoints.isEmpty {
          await trackWebViewLoadFailure(error, urls: attemptedURLs)
          didFailToLoad = true
          return false
        }

        await trackWebViewLoadFallback(error)

        return await load(
          attempts: attempts + 1,
          maxAttempts: maxAttempts,
          attemptedURLs: attemptedURLs + [url],
          endpoints: endpoints
        )
      }
    }
    return false
  }

  private func trackWebViewLoadFailure(
    _ error: Error,
    urls: [URL],
    at failAt: Date = Date()
  ) async {
    webViewDelegate?.paywall.webviewLoadingInfo.failAt = failAt

    guard let paywallInfo = webViewDelegate?.info else {
      return
    }

    let trackedEvent = InternalSuperwallEvent.PaywallWebviewLoad(
      state: .fail(error, urls),
      paywallInfo: paywallInfo
    )
    await Superwall.shared.track(trackedEvent)
  }

  private func trackWebViewLoadFallback(
    _ error: Error
  ) async {
    guard let paywallInfo = webViewDelegate?.info else {
      return
    }

    let trackedEvent = InternalSuperwallEvent.PaywallWebviewLoad(
      state: .fallback,
      paywallInfo: paywallInfo
    )
    await Superwall.shared.track(trackedEvent)
  }
}
