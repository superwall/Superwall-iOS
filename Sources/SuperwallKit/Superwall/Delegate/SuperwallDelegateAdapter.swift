//
//  File.swift
//  
//
//  Created by Yusuf Tör on 18/10/2022.
//

import Foundation
import StoreKit

/// An adapter between the internal SDK and the public swift/objective c delegate.
@MainActor
final class SuperwallDelegateAdapter {
  var hasDelegate: Bool {
    return swiftDelegate != nil || objcDelegate != nil
  }
  enum InternalPurchaseResult {
    case purchased
    case cancelled
    case pending
  }
  weak var swiftDelegate: SuperwallDelegate?
  weak var objcDelegate: SuperwallDelegateObjc?

  /// Called on init of the Superwall instance via ``SuperwallKit/Superwall/configure(apiKey:delegate:options:)-7doe5``.
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
    if let swiftDelegate = swiftDelegate {
      let result = await swiftDelegate.purchase(product: product)
      switch result {
      case .cancelled:
        return .cancelled
      case .purchased:
        return .purchased
      case .pending:
        return .pending
      case .failed(let error):
        throw error
      }
    } else if let objcDelegate = objcDelegate {
      return try await withCheckedThrowingContinuation { continuation in
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
    return .cancelled
  }

  func restorePurchases() async -> Bool {
    if let swiftDelegate = swiftDelegate {
      return await swiftDelegate.restorePurchases()
    } else if let objcDelegate = objcDelegate {
      return await withCheckedContinuation { continuation in
        objcDelegate.restorePurchases { didRestore in
          continuation.resume(returning: didRestore)
        }
      }
    }
    return false
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

  func didTrackSuperwallEvent(_ info: SuperwallEventInfo) {
    if let swiftDelegate = swiftDelegate {
      swiftDelegate.didTrackSuperwallEvent(info)
    } else if let objcDelegate = objcDelegate {
      objcDelegate.didTrackSuperwallEventInfo?(info)
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
