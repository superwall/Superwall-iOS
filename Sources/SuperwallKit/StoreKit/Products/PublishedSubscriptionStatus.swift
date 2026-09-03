//
//  PublishedSubscriptionStatus.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 2026-09-03.
//

import Combine
import Foundation

/// The property wrapper behind ``Superwall/subscriptionStatus``.
///
/// Every assignment is routed through `publishSubscriptionStatus`, so the
/// stored and published value is always the merged one — subscribers never
/// see the value a writer assigned before granted entitlements and test-mode
/// overrides were applied. The projected value (`$subscriptionStatus`) replays
/// the current value to new subscribers, like `@Published`.
///
/// Public only because a public property's wrapper type has to be; nothing
/// but the projection is meant to be used. The enclosing-instance subscript
/// is the same mechanism `@Published` itself uses to reach its owner.
@propertyWrapper
public struct PublishedSubscriptionStatus {
  private var storage: SubscriptionStatus
  private let subject: CurrentValueSubject<SubscriptionStatus, Never>

  public init(wrappedValue: SubscriptionStatus) {
    storage = wrappedValue
    subject = CurrentValueSubject(wrappedValue)
  }

  @available(*, unavailable, message: "Only available on Superwall.")
  public var wrappedValue: SubscriptionStatus {
    get { fatalError("subscriptionStatus is only readable on Superwall.") }
    set { fatalError("\(newValue) can only be assigned on Superwall.") }
  }

  public var projectedValue: AnyPublisher<SubscriptionStatus, Never> {
    return subject.eraseToAnyPublisher()
  }

  public static subscript(
    _enclosingInstance superwall: Superwall,
    wrapped wrappedKeyPath: ReferenceWritableKeyPath<Superwall, SubscriptionStatus>,
    storage storageKeyPath: ReferenceWritableKeyPath<Superwall, PublishedSubscriptionStatus>
  ) -> SubscriptionStatus {
    get {
      return superwall[keyPath: storageKeyPath].storage
    }
    set {
      superwall.publishSubscriptionStatus(.developerAssignment(newValue))
    }
  }

  /// Stores a merged status without emitting it.
  mutating func store(_ merged: SubscriptionStatus) {
    storage = merged
  }

  /// Emits a stored status to subscribers.
  func emit(_ status: SubscriptionStatus) {
    subject.send(status)
  }
}
