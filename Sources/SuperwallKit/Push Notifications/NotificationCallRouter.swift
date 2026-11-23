//
//  NotificationCallRouter.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 23/11/2026.
//

import Foundation

/// Passes the app's push calls on to the configured SDK's
/// ``NotificationTokenManager``, keeping any made before
/// `Superwall.configure` until it exists.
///
/// The system hands over a token once per registration and a tap once, so one
/// that arrives before the app configures Superwall would otherwise be lost.
final class NotificationCallRouter: @unchecked Sendable {
  static let shared = NotificationCallRouter()

  private let lock = NSLock()
  private weak var manager: NotificationTokenManager?
  private var heldToken: Data?
  private var heldIsEnabled: Bool?
  private var heldOpens: [PrivateSuperwallEvents.NotificationOpen] = []

  func setPushToken(_ deviceToken: Data) {
    lock.withLock {
      guard let manager = manager else {
        heldToken = deviceToken
        return
      }
      manager.setPushToken(deviceToken)
    }
  }

  func setEnabled(_ isEnabled: Bool) {
    lock.withLock {
      guard let manager = manager else {
        heldIsEnabled = isEnabled
        return
      }
      manager.setEnabled(isEnabled)
    }
  }

  func trackOpen(_ open: PrivateSuperwallEvents.NotificationOpen) {
    lock.withLock {
      guard let manager = manager else {
        if heldOpens.count < NotificationReportingState.maxHeldOpens {
          heldOpens.append(open)
        }
        return
      }
      manager.trackOpen(open)
    }
  }

  /// Makes `manager` the one calls go to, and hands it the calls made so far.
  ///
  /// The manager only queues the work, so nothing waits with the lock held,
  /// and a call made on another thread meanwhile lands after the held ones.
  func attach(_ manager: NotificationTokenManager) {
    lock.withLock {
      self.manager = manager
      // The opt-out first, so the token is first sent with it applied.
      if let isEnabled = heldIsEnabled {
        manager.setEnabled(isEnabled)
      }
      if let token = heldToken {
        manager.setPushToken(token)
      }
      for open in heldOpens {
        manager.trackOpen(open)
      }
      heldIsEnabled = nil
      heldToken = nil
      heldOpens = []
    }
  }
}
