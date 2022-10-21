//
//  File.swift
//  
//
//  Created by Yusuf Tör on 18/10/2022.
//

import Foundation
import StoreKit

/// Manages the swift vs objective c delegate.
@MainActor
final class SuperwallDelegateManager {
  enum InternalPurchaseResult {
    case purchased
    case cancelled
    case pending
  }

  weak var swiftDelegate: SuperwallDelegate?
  weak var objcDelegate: SuperwallDelegateObjc?

  /// Called on init of the Superwall instance via ``Superwall/Superwall/configure(apiKey:delegate:options:)-7cmf5``.
  ///
  /// We check to see if the delegates being set are non-nil because they may have been set
  /// separately to the initial Superwall.config function.
  func configure(
    swiftDelegate: SuperwallDelegate?,
    objcDelegate: SuperwallDelegateObjc?
  ) {
    if let swiftDelegate = swiftDelegate {
      self.swiftDelegate = swiftDelegate
    }
    if let objcDelegate = objcDelegate {
      self.objcDelegate = objcDelegate
    }
  }

  func purchase(
    product: SKProduct
  ) async throws -> InternalPurchaseResult {
    return try await withCheckedThrowingContinuation { continuation in
      if let swiftDelegate = swiftDelegate {
        swiftDelegate.purchase(product: product) { complete in
          switch complete {
          case .failed(let error):
            continuation.resume(throwing: error)
          case .purchased:
            continuation.resume(returning: .purchased)
          case .pending:
            continuation.resume(returning: .pending)
          case .cancelled:
            continuation.resume(returning: .cancelled)
          }
        }
      } else if let objcDelegate = objcDelegate {
        objcDelegate.purchase(product: product) { result, error in
          if let error = error {
            continuation.resume(throwing: error)
          } else {
            switch result {
            case .purchased:
              continuation.resume(returning: .purchased)
            case .pending:
              continuation.resume(returning: .pending)
            case .cancelled:
              continuation.resume(returning: .cancelled)
            case .failed:
              break
            }
          }
        }
      }
    }
  }

  func restorePurchases() async -> Bool {
    return await withCheckedContinuation { continuation in
      if let swiftDelegate = swiftDelegate {
        swiftDelegate.restorePurchases { didRestore in
          continuation.resume(returning: didRestore)
        }
      } else if let objcDelegate = objcDelegate {
        objcDelegate.restorePurchases { didRestore in
          continuation.resume(returning: didRestore)
        }
      }
    }
  }

  func isUserSubscribed() -> Bool {
    if let swiftDelegate = swiftDelegate {
      return swiftDelegate.isUserSubscribed()
    } else if let objcDelegate = objcDelegate {
      return objcDelegate.isUserSubscribed()
    }
    return false
  }

  func handleCustomPaywallAction(withName name: String) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.handleCustomPaywallAction(withName: name)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.handleCustomPaywallAction?(withName: name)
    }
  }

  func willDismissPaywall() {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.willDismissPaywall()
    } else if let objcDelegate = objcDelegate {
      objcDelegate.willDismissPaywall?()
    }
  }

  func willPresentPaywall() {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.willPresentPaywall()
    } else if let objcDelegate = objcDelegate {
      objcDelegate.willPresentPaywall?()
    }
  }

  func didDismissPaywall() {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.didDismissPaywall()
    } else if let objcDelegate = objcDelegate {
      objcDelegate.didDismissPaywall?()
    }
  }

  func didPresentPaywall() {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.didPresentPaywall()
    } else if let objcDelegate = objcDelegate {
      objcDelegate.didPresentPaywall?()
    }
  }

  func willOpenURL(url: URL) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.willOpenURL(url: url)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.willOpenURL?(url: url)
    }
  }

  func willOpenDeepLink(url: URL) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.willOpenDeepLink(url: url)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.willOpenDeepLink?(url: url)
    }
  }

  func trackAnalyticsEvent(
    withName name: String,
    params: [String: Any]
  ) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.trackAnalyticsEvent(withName: name, params: params)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.trackAnalyticsEvent?(withName: name, params: params)
    }
  }

  func handleLog(
    level: String,
    scope: String,
    message: String?,
    info: [String: Any]?,
    error: Swift.Error?
  ) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.handleLog(
        level: level,
        scope: scope,
        message: message,
        info: info,
        error: error
      )
    } else if let objcDelegate = objcDelegate {
      objcDelegate.handleLog?(
        level: level,
        scope: scope,
        message: message,
        info: info,
        error: error
      )
    }
  }
}
