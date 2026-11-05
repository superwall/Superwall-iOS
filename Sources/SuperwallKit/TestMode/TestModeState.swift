//
//  TestModeState.swift
//  SuperwallKit
//
//  Created by Superwall on 05/11/2026.
//

import Foundation

/// Holds ``TestModeState``. Test mode has no store actions: the reducers are
/// applied by ``TestModeManager``, which saves to storage once the store is
/// unlocked.
typealias TestModeStore = StateStore<Void, TestModeState>

/// Whether test mode is on and, while it is, what the tester has set up.
/// Changed only by ``TestModeUpdate`` reducers on its store.
///
/// Everything the tester sets up lives in the session, so turning test mode
/// off forgets it all in one step.
enum TestModeState {
  case inactive
  case active(reason: TestModeReason, session: TestModeSession)

  var isActive: Bool {
    if case .active = self {
      return true
    }
    return false
  }

  var reason: TestModeReason? {
    if case let .active(reason, _) = self {
      return reason
    }
    return nil
  }

  var session: TestModeSession? {
    if case let .active(_, session) = self {
      return session
    }
    return nil
  }
}

/// What the tester has set up while test mode is on.
struct TestModeSession {
  /// Products fetched from the `/v1/products` endpoint for test mode use.
  var products: [SuperwallProduct] = []

  /// The IDs of the entitlements the tester has picked or bought.
  var entitlementIds: Set<String> = []

  /// Override for free trial availability.
  var freeTrialOverride: FreeTrialOverride = .useDefault

  /// The subscription status test mode keeps. While set, other writes to
  /// `subscriptionStatus` are replaced with this value.
  var overriddenSubscriptionStatus: SubscriptionStatus?

  /// The customer info test mode keeps. While set, other writes to
  /// `customerInfo` are replaced with this value.
  var overriddenCustomerInfo: CustomerInfo?
}

/// The ways ``TestModeState`` can change. Every update other than
/// ``activate(_:)`` leaves an inactive state as it is.
enum TestModeUpdate: Reducer {
  /// Turns test mode on, or changes why it's on, keeping the session.
  case activate(TestModeReason)
  /// Turns test mode off and forgets the session.
  case deactivate
  case products([SuperwallProduct])
  case freeTrialOverride(FreeTrialOverride)
  /// Adds the entitlements of a simulated purchase to those already held, all
  /// of them subscribed.
  case purchased(entitlementIds: Set<String>)
  /// Replaces the entitlements with those the tester picked, in the modal or
  /// when restoring.
  case chose(entitlements: Set<Entitlement>)

  func reduce(_ state: TestModeState) -> TestModeState {
    switch self {
    case .activate(let reason):
      return .active(reason: reason, session: state.session ?? TestModeSession())
    case .deactivate:
      return .inactive
    case .products(let products):
      return state.changingSession { $0.products = products }
    case .freeTrialOverride(let override):
      return state.changingSession { $0.freeTrialOverride = override }
    case .purchased(let entitlementIds):
      return state.changingSession { session in
        session.entitlementIds.formUnion(entitlementIds)
        let entitlements = session.entitlementIds.map {
          Entitlement(
            id: $0,
            type: .serviceLevel,
            isActive: true,
            store: .appStore,
            state: .subscribed
          )
        }
        session.keep(Set(entitlements))
      }
    case .chose(let entitlements):
      return state.changingSession { session in
        session.entitlementIds = Set(entitlements.map { $0.id })
        session.keep(entitlements)
      }
    }
  }
}

private extension TestModeState {
  /// The state with `change` made to its session, or the same state when
  /// test mode is off.
  func changingSession(_ change: (inout TestModeSession) -> Void) -> TestModeState {
    guard case .active(let reason, var session) = self else {
      return self
    }
    change(&session)
    return .active(reason: reason, session: session)
  }
}

private extension TestModeSession {
  /// Sets the customer info and subscription status test mode keeps from
  /// `entitlements`.
  mutating func keep(_ entitlements: Set<Entitlement>) {
    overriddenCustomerInfo = CustomerInfo(
      subscriptions: [],
      nonSubscriptions: [],
      entitlements: Array(entitlements)
    )
    if entitlements.contains(where: { $0.isActive }) {
      overriddenSubscriptionStatus = .active(entitlements)
    } else {
      overriddenSubscriptionStatus = .inactive
    }
  }
}
