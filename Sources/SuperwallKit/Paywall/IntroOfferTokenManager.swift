//
//  IntroOfferTokenManager.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 07/11/2025.
//

import Foundation
import UIKit

/// Manages intro offer eligibility tokens for StoreKit 2 purchases.
/// Handles fetching, caching, expiry checking, and automatic refreshing when app returns to foreground.
final class IntroOfferTokenManager {
  // MARK: - Nested Types

  /// Parameters needed to fetch intro offer tokens
  private struct FetchParameters {
    let introOfferEligibility: IntroOfferEligibility
    let paywallId: String
    let productIds: [String]
    let appTransactionId: String
  }

  // MARK: - Properties

  /// Cached intro offer tokens by product ID
  private(set) var tokens: [String: IntroOfferToken] = [:]

  /// Observer token for app lifecycle notifications
  private var appLifecycleObserver: NSObjectProtocol?

  /// Network dependency for fetching tokens
  private let network: Network

  /// Stored fetch parameters for automatic refresh
  private var fetchParameters: FetchParameters?

  // MARK: - Initialization

  init(network: Network) {
    self.network = network
  }

  deinit {
    stopObservingAppLifecycle()
  }

  // MARK: - Public Methods

  /// Starts observing app lifecycle events to refresh tokens when app returns to foreground
  func startObservingAppLifecycle() {
    guard appLifecycleObserver == nil else {
      return
    }

    appLifecycleObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.willEnterForegroundNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.refreshIfExpired()
    }
  }

  /// Stops observing app lifecycle events
  func stopObservingAppLifecycle() {
    if let observer = appLifecycleObserver {
      NotificationCenter.default.removeObserver(observer)
      appLifecycleObserver = nil
    }
  }

  /// Fetches intro offer eligibility tokens from the server
  ///
  /// This method handles all validation and error logging internally. If eligibility is automatic,
  /// product IDs are empty, or app transaction ID is nil, the method returns early without fetching.
  /// Network errors are logged but not thrown.
  ///
  /// - Parameters:
  ///   - introOfferEligibility: The intro offer eligibility setting from the paywall
  ///   - paywallId: The identifier of the paywall
  ///   - productIds: The product IDs that have intro offers
  ///   - appTransactionId: The app transaction ID from StoreKit (optional)
  func fetchTokens(
    introOfferEligibility: IntroOfferEligibility,
    paywallId: String,
    productIds: [String],
    appTransactionId: String?
  ) async {
    // Skip fetching if eligibility is automatic or no products/appTransactionId
    guard
      introOfferEligibility != .automatic,
      !productIds.isEmpty,
      let appTransactionId = appTransactionId
    else {
      return
    }

    // Store parameters for potential refresh
    fetchParameters = FetchParameters(
      introOfferEligibility: introOfferEligibility,
      paywallId: paywallId,
      productIds: productIds,
      appTransactionId: appTransactionId
    )

    do {
      // Convert IntroOfferEligibility to boolean
      // eligible = true, ineligible = false
      let allowIntroductoryOffer = introOfferEligibility == .eligible

      let tokensByProductId = try await network.getIntroOfferToken(
        productIds: productIds,
        appTransactionId: appTransactionId,
        allowIntroductoryOffer: allowIntroductoryOffer
      )
      tokens = tokensByProductId

      Logger.debug(
        logLevel: .debug,
        scope: .paywallViewController,
        message: "Successfully fetched \(tokensByProductId.count) intro offer token(s)"
      )
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .paywallViewController,
        message: "Failed to fetch intro offer tokens",
        error: error
      )
    }
  }

  /// Retrieves a valid (non-expired) token for the given product ID
  ///
  /// - Parameter productId: The product identifier
  /// - Returns: The token if it exists and hasn't expired, nil otherwise
  func getValidToken(for productId: String) -> IntroOfferToken? {
    guard
      let token = tokens[productId],
      token.expiry > Date()
    else {
      return nil
    }
    return token
  }

  /// Checks if any tokens are expired and refreshes them if needed
  /// This is called automatically when the app returns to foreground
  func refreshIfExpired() {
    if tokens.isEmpty {
      return
    }

    let now = Date()
    let hasExpiredTokens = tokens.values.contains { $0.expiry <= now }

    if hasExpiredTokens {
      Logger.debug(
        logLevel: .debug,
        scope: .paywallViewController,
        message: "Intro offer tokens expired, refreshing..."
      )

      // Re-fetch if we have stored parameters
      if let params = fetchParameters {
        Task {
          await fetchTokens(
            introOfferEligibility: params.introOfferEligibility,
            paywallId: params.paywallId,
            productIds: params.productIds,
            appTransactionId: params.appTransactionId
          )
        }
      }
    }
  }
}
