//
//  TestModeAction.swift
//  SuperwallKit
//
//  Created by Superwall on 06/11/2026.
//

import Foundation

typealias TestModeStore = StateStore<TestModeContext, TestModeState>

/// Everything test mode actions need. ``TestModeManager`` provides it in the
/// SDK, and tests provide a fake that records the calls.
protocol TestModeContext: AnyObject {
  var store: TestModeStore { get }

  /// Forgets the tester's saved choices and the saved record of an active
  /// test subscription.
  func clearSavedSettings()

  /// Saves whether the tester's choice includes an active entitlement, so the
  /// next launch doesn't take it for a real subscription.
  func saveHasActiveSubscription(_ hasActiveSubscription: Bool)

  /// Sends the customer info and subscription status test mode keeps to the
  /// rest of the SDK, after the sends queued before it. They're read when the
  /// send runs, so nothing is sent if test mode has turned off by then.
  func publishOverrides()

  /// Hands the subscription status and customer info back to the rest of the
  /// SDK once test mode has turned off, after the sends queued before it.
  /// Nothing is sent if test mode has turned back on by then.
  func publishTestModeEnded()
}

/// The state before and after an action, read in the same locked step.
struct TestModeChange {
  let before: TestModeState
  let after: TestModeState

  var justActivated: Bool {
    !before.isActive && after.isActive
  }

  var justDeactivated: Bool {
    before.isActive && !after.isActive
  }
}

/// Everything that changes test mode. Actions run with the store locked, and
/// changes made while test mode is off are dropped, along with their side
/// effects.
enum TestModeAction: StoreAction {
  /// A config was checked: test mode is on for `reason`, or off when it's
  /// `nil`.
  case evaluated(TestModeReason?)
  case productsLoaded([SuperwallProduct])
  /// The tester bought a product with these entitlements.
  case purchased(entitlementIds: Set<String>)
  /// The tester closed the test mode modal with these choices.
  case modalClosed(entitlements: Set<Entitlement>, freeTrialOverride: FreeTrialOverride)
  /// The tester picked these entitlements when restoring.
  case restored(Set<Entitlement>)
  /// A dev server drives the SDK, so every entitlement starts inactive.
  case defaultsApplied

  func execute(in context: TestModeContext) -> TestModeChange {
    let store = context.store
    let before = store.state

    switch self {
    case .evaluated(let reason):
      if let reason {
        store.update(TestModeUpdate.activated(reason))
      } else {
        store.update(TestModeUpdate.deactivated)
        context.clearSavedSettings()
        if before.isActive {
          context.publishTestModeEnded()
        }
      }
    case .productsLoaded(let products):
      store.update(TestModeUpdate.productsLoaded(products))
    case .purchased(let entitlementIds):
      if !before.isActive {
        break
      }
      store.update(TestModeUpdate.purchased(entitlementIds: entitlementIds))
      context.publishOverrides()
    case let .modalClosed(entitlements, freeTrialOverride):
      if !before.isActive {
        // The modal saves the tester's choices as it closes, so forget them
        // again: test mode turned off while it was open.
        context.clearSavedSettings()
        break
      }
      store.update(
        TestModeUpdate.settingsChosen(entitlements: entitlements, freeTrialOverride: freeTrialOverride)
      )
      context.saveHasActiveSubscription(entitlements.contains { $0.isActive })
      context.publishOverrides()
    case .restored(let entitlements):
      if !before.isActive {
        break
      }
      store.update(TestModeUpdate.restored(entitlements))
      context.publishOverrides()
    case .defaultsApplied:
      if !before.isActive {
        break
      }
      store.update(TestModeUpdate.defaultsApplied)
      context.saveHasActiveSubscription(false)
      context.publishOverrides()
    }

    return TestModeChange(before: before, after: store.state)
  }
}
