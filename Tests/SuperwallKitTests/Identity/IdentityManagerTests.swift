//
//  IdentityManagerTests.swift
//
//
//  Created by Superwall on 02/12/2024.
//
// swiftlint:disable all

import Testing
import Foundation
@testable import SuperwallKit

struct IdentityManagerTests {
  @Test
  func mergeUserAttributesAndNotify_callsNotifyCallback() async throws {
    // Given
    let dependencyContainer = DependencyContainer()
    var notifiedAttributes: [String: Any]?

    let identityManager = IdentityManager(
      deviceHelper: dependencyContainer.deviceHelper,
      storage: dependencyContainer.storage,
      configManager: dependencyContainer.configManager,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      notifyUserChange: { attributes in
        notifiedAttributes = attributes
      }
    )

    // When
    identityManager.mergeUserAttributesAndNotify(["testKey": "testValue"])

    // Then - wait for async operation
    try await Task.sleep(nanoseconds: 500_000_000)

    #expect(notifiedAttributes != nil, "notifyUserChange should have been called")
    #expect(notifiedAttributes?["testKey"] as? String == "testValue")
  }

  @Test
  func mergeUserAttributes_doesNotCallNotifyCallback() async throws {
    // Given
    let dependencyContainer = DependencyContainer()
    var notifyCallCount = 0

    let identityManager = IdentityManager(
      deviceHelper: dependencyContainer.deviceHelper,
      storage: dependencyContainer.storage,
      configManager: dependencyContainer.configManager,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      notifyUserChange: { _ in
        notifyCallCount += 1
      }
    )

    // When
    identityManager.mergeUserAttributes(["testKey": "testValue"])

    // Then - wait for async operation
    try await Task.sleep(nanoseconds: 500_000_000)

    #expect(notifyCallCount == 0, "notifyUserChange should NOT have been called for regular mergeUserAttributes")
  }

  @Test
  func mergeUserAttributesAndNotify_mergesAttributesCorrectly() async throws {
    // Given
    let dependencyContainer = DependencyContainer()
    var notifiedAttributes: [String: Any]?

    let identityManager = IdentityManager(
      deviceHelper: dependencyContainer.deviceHelper,
      storage: dependencyContainer.storage,
      configManager: dependencyContainer.configManager,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      notifyUserChange: { attributes in
        notifiedAttributes = attributes
      }
    )

    // First set some initial attributes
    identityManager.mergeUserAttributes(["existingKey": "existingValue"])
    try await Task.sleep(nanoseconds: 300_000_000)

    // When - add new attributes via mergeUserAttributesAndNotify
    identityManager.mergeUserAttributesAndNotify(["newKey": "newValue"])
    try await Task.sleep(nanoseconds: 300_000_000)

    // Then - callback should receive merged attributes
    #expect(notifiedAttributes != nil)
    #expect(notifiedAttributes?["existingKey"] as? String == "existingValue")
    #expect(notifiedAttributes?["newKey"] as? String == "newValue")
  }
}
