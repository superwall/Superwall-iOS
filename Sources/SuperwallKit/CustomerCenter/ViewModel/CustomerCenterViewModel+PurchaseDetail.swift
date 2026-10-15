//
//  CustomerCenterViewModel+PurchaseDetail.swift
//
//
//  Created by Jordan Morgan on 11/09/2026.
//

import Foundation

// MARK: - What the purchase detail screen shows below the card

extension CustomerCenterViewModel {
  /// Why a detail screen has no actions, when it has none. Every subscription row opens its
  /// detail screen — that is the rule, and it holds whether or not there is anything left to do —
  /// so the screen has to say something true when the resolver comes back empty, and what is
  /// true depends on the purchase.
  enum DetailEmptyState: Equatable {
    /// Nothing is left to do: the subscription is revoked or lapsed, the member isn't the one
    /// paying, or a comped grant has no page to send anyone to.
    case nothingToDo
    /// The customer is still paying for this, from a store this SDK can't drive — the Play Store
    /// on an iOS client, or a developer's own system. Telling them there is nothing to manage
    /// would be false; telling them where to manage it is the `webManageUnavailable` precedent.
    /// `storeLabelKey` names the store when there is a name for it.
    case managedElsewhere(storeLabelKey: String?)
  }

  /// What the detail screen opened for `opened` shows now.
  struct DetailContent: Equatable {
    /// The purchase as it stands in ``purchases``, or as it was when the screen opened if it's
    /// no longer listed.
    let purchase: PurchasePresentation
    /// `nil` when there are actions to show; otherwise which sentence to show instead.
    let emptyState: DetailEmptyState?
  }

  /// Looks `opened` up again in ``purchases`` rather than trusting the copy the screen was built
  /// with.
  ///
  /// A screen pushed onto the host's navigation controller is its own hosting controller, and
  /// keeps whatever it was handed when it was pushed. Cancelling in Apple's sheet refreshes
  /// ``purchases``, but that copy would still say "Renews on" and still offer to cancel.
  ///
  /// When the purchase is no longer listed — a restore under another account, say — the screen
  /// keeps showing the card it opened with, but offers nothing to do with it: there is no longer
  /// anything behind it to act on.
  func detailContent(for opened: PurchasePresentation) -> DetailContent {
    guard let current = purchases.first(where: { $0.id == opened.id }) else {
      return DetailContent(purchase: opened, emptyState: .nothingToDo)
    }
    return DetailContent(purchase: current, emptyState: detailEmptyState(for: current))
  }

  /// Whether the detail screen for `purchase` has anything to act on.
  func hasActions(for purchase: PurchasePresentation) -> Bool {
    !paths(for: purchase, isScreenLevel: false).isEmpty
  }

  /// `nil` when the detail screen has actions to show; otherwise which sentence to show instead.
  func detailEmptyState(for purchase: PurchasePresentation) -> DetailEmptyState? {
    if hasActions(for: purchase) { return nil }
    // A lifetime grant is excluded on purpose: nothing renews, so there is nothing to manage
    // anywhere — the same guard the resolver applies to change-plan. Sending its owner to the
    // Play Store to "manage this subscription" would point at a renewal that doesn't exist.
    let isLive = purchase.isActive && purchase.badge != .revoked && purchase.badge != .lifetime
    let isDrivable: Bool = [.appStore, .stripe, .paddle, .superwall].contains(purchase.store)
    guard isLive, !isDrivable else { return .nothingToDo }
    // Only a store with a real name fills the sentence. `.other` and `.custom` carry the label
    // "Other", and "manage this subscription through Other" is worse than the generic line.
    switch purchase.store {
    case .playStore: return .managedElsewhere(storeLabelKey: purchase.storeLabelKey)
    default: return .managedElsewhere(storeLabelKey: nil)
    }
  }
}
