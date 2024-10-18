//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 17/10/2024.
//

import SwiftUI

final class GetPaywallManager: ObservableObject {
  @Published var userHasAccess = false
  @Published var shouldDismiss = false

  enum State {
    case loading
    case retrieved(PaywallViewController)
    case skipped(PaywallSkippedReason)
    case error(Error)
  }
  @Published var state: State = .loading

  func getPaywall(
    forEvent event: String,
    params: [String: Any]?,
    paywallOverrides: PaywallOverrides?
  ) async {
    do {
      await MainActor.run {
        state = .loading
      }
      let paywallViewController = try await Superwall.shared.getPaywall(
        forEvent: event,
        params: params,
        paywallOverrides: paywallOverrides,
        delegate: self
      )
      await MainActor.run {
        state = .retrieved(paywallViewController)
      }
    } catch let skippedReason as PaywallSkippedReason {
      await MainActor.run {
        state = .skipped(skippedReason)
      }
    } catch {
      Logger.debug(
        logLevel: .error,
        scope: .paywallPresentation,
        message: error.localizedDescription
      )
      await MainActor.run {
        state = .error(error)
      }
    }
  }
}

// - MARK: PaywallViewControllerDelegate
extension GetPaywallManager: PaywallViewControllerDelegate {
  func paywall(
    _ paywall: PaywallViewController,
    didFinishWith result: PaywallResult,
    shouldDismiss: Bool
  ) {
    if shouldDismiss {
      self.shouldDismiss.toggle()
    }

    switch result {
    case .purchased,
      .restored:
      userHasAccess.toggle()
    case .declined:
      let closeReason = paywall.info.closeReason
      let featureGating = paywall.info.featureGatingBehavior
      if closeReason != .forNextPaywall,
        featureGating == .nonGated {
        userHasAccess.toggle()
      }
    }
  }
}