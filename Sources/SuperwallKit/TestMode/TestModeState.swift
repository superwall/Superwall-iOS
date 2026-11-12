//
//  TestModeState.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//

import Foundation

/// Whether test mode is on and, while it is, what the tester has set up.
/// Changed only by ``TestModeUpdate`` reducers on its store.
struct TestModeState {
  enum Mode {
    case inactive
    /// Everything the tester sets up lives in the session, so turning test
    /// mode off forgets it all in one step.
    case active(reason: TestModeReason, session: TestModeSession)
  }

  var mode: Mode = .inactive

  var isActive: Bool {
    session != nil
  }

  var reason: TestModeReason? {
    if case let .active(reason, _) = mode {
      return reason
    }
    return nil
  }

  var session: TestModeSession? {
    if case let .active(_, session) = mode {
      return session
    }
    return nil
  }
}

/// What the tester has set up while test mode is on.
struct TestModeSession {
  /// Products fetched from the `/v1/products` endpoint for test mode use.
  var products: [SuperwallProduct] = []

  /// Override for free trial availability.
  var freeTrialOverride: FreeTrialOverride = .useDefault

  /// The entitlements test mode keeps. The IDs, the subscription status and
  /// the customer info are all worked out from this.
  var entitlements: TestModeEntitlements = .untouched

  /// The IDs of the entitlements kept, active or not.
  var entitlementIds: Set<String> {
    Set(entitlements.kept?.map(\.id) ?? [])
  }

  /// The subscription status test mode keeps, which replaces other writes to
  /// `subscriptionStatus`. `nil` until the tester has chosen or bought
  /// something.
  var overriddenSubscriptionStatus: SubscriptionStatus? {
    guard let kept = entitlements.kept else {
      return nil
    }
    if kept.contains(where: { $0.isActive }) {
      return .active(kept)
    }
    return .inactive
  }

  /// The customer info test mode keeps, which replaces other writes to
  /// `customerInfo`. `nil` until the tester has chosen or bought something.
  var overriddenCustomerInfo: CustomerInfo? {
    guard let kept = entitlements.kept else {
      return nil
    }
    return CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: kept.sorted { $0.id < $1.id }
    )
  }

  var hasActiveEntitlement: Bool {
    entitlements.kept?.contains { $0.isActive } ?? false
  }
}

/// The entitlements test mode keeps.
enum TestModeEntitlements {
  /// The tester hasn't chosen or bought anything yet, so the SDK's own
  /// subscription status and customer info stand.
  case untouched
  /// What the tester chose or bought, which replaces the SDK's own
  /// subscription status and customer info. Can be empty.
  case kept(Set<Entitlement>)

  var kept: Set<Entitlement>? {
    if case .kept(let entitlements) = self {
      return entitlements
    }
    return nil
  }
}

/// The ways ``TestModeState`` can change. Every update other than
/// ``activated(_:)`` leaves an inactive state as it is.
enum TestModeUpdate: Reducer {
  /// Test mode turned on, or is on for a different reason. Keeps the
  /// session.
  case activated(TestModeReason)
  /// Test mode turned off. Forgets the session.
  case deactivated
  case productsLoaded([SuperwallProduct])
  /// The tester bought something with these entitlements. They're kept as
  /// subscribed, alongside the others as they were.
  case purchased(entitlementIds: Set<String>)
  /// The tester picked these entitlements and free trial override in the
  /// test mode modal.
  case settingsChosen(entitlements: Set<Entitlement>, freeTrialOverride: FreeTrialOverride)
  /// The tester picked these entitlements when restoring.
  case restored(Set<Entitlement>)
  /// A dev server drives the SDK, so every entitlement starts inactive
  /// without asking the tester.
  case defaultsApplied

  func reduce(_ state: TestModeState) -> TestModeState {
    var state = state
    switch self {
    case .activated(let reason):
      state.mode = .active(reason: reason, session: state.session ?? TestModeSession())
    case .deactivated:
      state.mode = .inactive
    case .productsLoaded(let products):
      state.changeSession { $0.products = products }
    case .purchased(let entitlementIds):
      state.changeSession { session in
        let bought = entitlementIds.map {
          Entitlement(
            id: $0,
            type: .serviceLevel,
            isActive: true,
            store: .appStore,
            state: .subscribed
          )
        }
        let others = (session.entitlements.kept ?? []).filter { !entitlementIds.contains($0.id) }
        session.entitlements = .kept(others.union(bought))
      }
    case let .settingsChosen(entitlements, freeTrialOverride):
      state.changeSession { session in
        session.entitlements = .kept(entitlements)
        session.freeTrialOverride = freeTrialOverride
      }
    case .restored(let entitlements):
      state.changeSession { $0.entitlements = .kept(entitlements) }
    case .defaultsApplied:
      state.changeSession { $0.entitlements = .kept([]) }
    }
    return state
  }
}

private extension TestModeState {
  /// Makes `change` to the session, or nothing when test mode is off.
  mutating func changeSession(_ change: (inout TestModeSession) -> Void) {
    guard case .active(let reason, var session) = mode else {
      return
    }
    change(&session)
    mode = .active(reason: reason, session: session)
  }
}
