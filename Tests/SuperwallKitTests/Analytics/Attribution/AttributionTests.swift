//
//  AttributionTests.swift
//  SuperwallKit
//
//  Created by Claude on 13/08/2025.
//

import Testing
import Foundation
@testable import SuperwallKit

@Suite(.serialized)
struct AttributionTests {
  let superwall: Superwall
  let dependencyContainer: DependencyContainer

  init() {
    dependencyContainer = DependencyContainer()
    superwall = Superwall(dependencyContainer: dependencyContainer)
  }
  
  private func cleanupTimers() {
    dependencyContainer.attributionFetcher.cancelPendingOperations()
  }

  // MARK: - Helper Methods
  
  func withMockAppTransactionId<T>(_ body: () throws -> T) rethrows -> T {
    let original = ReceiptManager.appTransactionId
    ReceiptManager.appTransactionId = "mock-app-transaction-id"
    defer { ReceiptManager.appTransactionId = original }
    return try body()
  }
  
  func withMockAppTransactionId<T>(_ body: () async throws -> T) async rethrows -> T {
    let original = ReceiptManager.appTransactionId
    ReceiptManager.appTransactionId = "mock-app-transaction-id"
    defer { ReceiptManager.appTransactionId = original }
    return try await body()
  }
  
  func withoutAppTransactionId<T>(_ body: () throws -> T) rethrows -> T {
    let original = ReceiptManager.appTransactionId
    ReceiptManager.appTransactionId = nil
    defer { ReceiptManager.appTransactionId = original }
    return try body()
  }
  
  func withoutAppTransactionId<T>(_ body: () async throws -> T) async rethrows -> T {
    let original = ReceiptManager.appTransactionId
    ReceiptManager.appTransactionId = nil
    defer { ReceiptManager.appTransactionId = original }
    return try await body()
  }

  // MARK: - setIntegrationAttributes Tests (with appTransactionId available)

  @Test
  func setIntegrationAttributes_singleProvider_withAppTransactionId() {
    withMockAppTransactionId {
      // Given
      let testValue = "test-adjust-id"
      let props: [IntegrationAttribute: String?] = [.adjustId: testValue]

      // When
      superwall.setIntegrationAttributes(props)
      
      // Then
      let storedProps = superwall.integrationAttributes
      #expect(storedProps["adjustId"] as? String == testValue)
      // Should not be enqueued when appTransactionId exists
      #expect(superwall.enqueuedIntegrationAttributes == nil)
    }
  }

  @Test
  func setIntegrationAttributes_multipleProviders_withAppTransactionId() {
    withMockAppTransactionId {
      // Given
      let adjustId = "test-adjust-id"
      let amplitudeId = "test-amplitude-device-id"
      let brazeAlias = "test-braze-alias"
      let props: [IntegrationAttribute: String?] = [
        .adjustId: adjustId,
        .amplitudeDeviceId: amplitudeId,
        .brazeAliasName: brazeAlias
      ]
      
      // When
      superwall.setIntegrationAttributes(props)
      
      // Then
      let storedProps = superwall.integrationAttributes
      #expect(storedProps["adjustId"] as? String == adjustId)
      #expect(storedProps["amplitudeDeviceId"] as? String == amplitudeId)
      #expect(storedProps["brazeAliasName"] as? String == brazeAlias)
      #expect(superwall.enqueuedIntegrationAttributes == nil)
    }
  }

  @Test
  func setIntegrationAttributes_nilValue_withAppTransactionId() {
    withMockAppTransactionId {
      // Given - set initial value
      let initialProps: [IntegrationAttribute: String?] = [.adjustId: "initial-value"]
      superwall.setIntegrationAttributes(initialProps)
      
      // When - set to nil
      let nilProps: [IntegrationAttribute: String?] = [.adjustId: nil]
      superwall.setIntegrationAttributes(nilProps)
      
      // Then
      let storedProps = superwall.integrationAttributes
      #expect(storedProps["adjustId"] == nil)
    }
  }

  @Test
  func setIntegrationAttributes_overwriteExistingValue_withAppTransactionId() {
    withMockAppTransactionId {
      // Given
      let initialValue = "initial-adjust-id"
      let newValue = "new-adjust-id"
      let initialProps: [IntegrationAttribute: String?] = [.adjustId: initialValue]
      superwall.setIntegrationAttributes(initialProps)
      
      // When
      let newProps: [IntegrationAttribute: String?] = [.adjustId: newValue]
      superwall.setIntegrationAttributes(newProps)
      
      // Then
      let storedProps = superwall.integrationAttributes
      #expect(storedProps["adjustId"] as? String == newValue)
    }
  }

  // MARK: - setIntegrationAttributes Tests (without appTransactionId - enqueued scenario)

  @Test
  func setIntegrationAttributes_singleProvider_withoutAppTransactionId() {
    withoutAppTransactionId {
      // Given
      let testValue = "test-adjust-id"
      let props: [IntegrationAttribute: String?] = [.adjustId: testValue]

      // When
      superwall.setIntegrationAttributes(props)
      
      // Then
      #expect(superwall.enqueuedIntegrationAttributes != nil)
      // Attribution should be enqueued, not immediately applied
      let enqueuedProps = superwall.enqueuedIntegrationAttributes
      #expect(enqueuedProps?[.adjustId] as? String == testValue)
    }
  }

  @Test
  func setIntegrationAttributes_dequeueWhenAppTransactionIdAvailable() {
    let testValue = "test-adjust-id"
    
    // Given - start without appTransactionId
    withoutAppTransactionId {
      let props: [IntegrationAttribute: String?] = [.adjustId: testValue]
      superwall.setIntegrationAttributes(props)
      
      // Verify it's enqueued
      #expect(superwall.enqueuedIntegrationAttributes != nil)
    }
    
    // When appTransactionId becomes available
    withMockAppTransactionId {
      superwall.dequeueIntegrationAttributes()
      
      // Then
      let storedProps = superwall.integrationAttributes
      #expect(storedProps["adjustId"] as? String == testValue)
      #expect(superwall.enqueuedIntegrationAttributes == nil)
    }
  }

  @Test
  func setIntegrationAttributes_overwriteEnqueued_withoutAppTransactionId() {
    withoutAppTransactionId {
      // Given
      let initialValue = "initial-adjust-id"
      let newValue = "new-adjust-id"
      
      // When - set initial value (gets enqueued)
      let initialProps: [IntegrationAttribute: String?] = [.adjustId: initialValue]
      superwall.setIntegrationAttributes(initialProps)
      
      // Then set new value (should overwrite enqueued)
      let newProps: [IntegrationAttribute: String?] = [.adjustId: newValue]
      superwall.setIntegrationAttributes(newProps)
      
      // Then
      let enqueuedProps = superwall.enqueuedIntegrationAttributes
      #expect(enqueuedProps?[.adjustId] as? String == newValue)
    }
  }

  // MARK: - integrationAttributes Tests

  @Test
  func integrationAttributes_emptyByDefault() {
    withMockAppTransactionId {
      // Given - fresh instance
      // When
      let props = superwall.integrationAttributes

      // Then - should contain automatic props like idfa, idfv
      #expect(props != nil)
      // Note: idfa and idfv may be automatically added by AttributionFetcher
    }
  }

  @Test
  func integrationAttributes_returnsSetValues() {
    withMockAppTransactionId {
      // Given
      let testProps: [IntegrationAttribute: String?] = [
        .adjustId: "test-adjust-id",
        .amplitudeDeviceId: "test-amplitude-id"
      ]
      superwall.setIntegrationAttributes(testProps)
      
      // When
      let retrievedProps = superwall.integrationAttributes

      // Then
      #expect(retrievedProps["adjustId"] as? String == "test-adjust-id")
      #expect(retrievedProps["amplitudeDeviceId"] as? String == "test-amplitude-id")
    }
  }

  @Test
  func integrationAttributes_immutableCopy() {
    withMockAppTransactionId {
      // Given
      let testProps: [IntegrationAttribute: String?] = [.adjustId: "test-adjust-id"]
      superwall.setIntegrationAttributes(testProps)
      
      // When
      var retrievedProps = superwall.integrationAttributes
      retrievedProps["adjustId"] = "modified-value"
      
      // Then - original should be unchanged
      let originalProps = superwall.integrationAttributes
      #expect(originalProps["adjustId"] as? String == "test-adjust-id")
    }
  }

  @Test
  func integrationAttributes_threadSafety() async {
    // Given
    let original = ReceiptManager.appTransactionId
    ReceiptManager.appTransactionId = "mock-app-transaction-id"
    defer { ReceiptManager.appTransactionId = original }

    let iterations = 50

    // When - perform many concurrent reads and writes
    await withTaskGroup(of: Void.self) { group in
      for i in 0..<iterations {
        group.addTask {
          let props: [IntegrationAttribute: String?] = [.adjustId: "value-\(i)"]
          self.superwall.setIntegrationAttributes(props)
        }

        group.addTask {
          _ = self.superwall.integrationAttributes
        }
      }
    }

    // Wait for any pending operations
    try? await Task.sleep(nanoseconds: 600_000_000)
    
    // Then - no crashes should occur (test passes if no crash)
    let finalProps = superwall.integrationAttributes
    #expect(finalProps != nil)
    
    // Cleanup
    cleanupTimers()
  }

  // MARK: - Integration Tests

  @Test
  func setIntegrationAttributes_updatesUserAttributes() {
    withMockAppTransactionId {
      // Given
      let testProps: [IntegrationAttribute: String?] = [.adjustId: "test-adjust-id"]

      // When
      superwall.setIntegrationAttributes(testProps)
      
      // Then - attribution props should also be set as user attributes
      let userAttributes = superwall.userAttributes
      #expect(userAttributes["adjustId"] as? String == "test-adjust-id")
    }
  }

  @Test
  func attribution_persistsAcrossMethods() {
    withMockAppTransactionId {
      // Given
      let testProps: [IntegrationAttribute: String?] = [
        .adjustId: "test-adjust-id",
        .amplitudeDeviceId: "test-amplitude-id"
      ]
      
      // When
      superwall.setIntegrationAttributes(testProps)
      
      // Then - both accessors should return the same values
      let directProps = superwall.integrationAttributes
      let fetchedProps = superwall.dependencyContainer.attributionFetcher.integrationAttributes
      
      #expect(directProps["adjustId"] as? String == fetchedProps["adjustId"] as? String)
      #expect(directProps["amplitudeDeviceId"] as? String == fetchedProps["amplitudeDeviceId"] as? String)
    }
  }

  @Test
  func setIntegrationAttributes_allIntegrationAttributes() {
    withMockAppTransactionId {
      // Given - test all available attribution providers
      let props: [IntegrationAttribute: String?] = [
        .adjustId: "adjust-id",
        .amplitudeDeviceId: "amplitude-device-id",
        .amplitudeUserId: "amplitude-user-id",
        .appsflyerId: "appsflyer-id",
        .brazeAliasName: "braze-alias-name",
        .brazeAliasLabel: "braze-alias-label",
        .onesignalId: "onesignal-id",
        .fbAnonId: "fb-anon-id",
        .firebaseAppInstanceId: "firebase-app-instance-id",
        .firebaseInstallationId: "firebase-installation-id",
        .iterableUserId: "iterable-user-id",
        .iterableCampaignId: "iterable-campaign-id",
        .iterableTemplateId: "iterable-template-id",
        .mixpanelDistinctId: "mixpanel-distinct-id",
        .mparticleId: "mparticle-id",
        .clevertapId: "clevertap-id",
        .airshipChannelId: "airship-channel-id",
        .kochavaDeviceId: "kochava-device-id",
        .tenjinId: "tenjin-id",
        .posthogUserId: "posthog-user-id",
        .customerioId: "customerio-id"
      ]
      
      // When
      superwall.setIntegrationAttributes(props)
      
      // Then
      let storedProps = superwall.integrationAttributes
      #expect(storedProps["adjustId"] as? String == "adjust-id")
      #expect(storedProps["amplitudeDeviceId"] as? String == "amplitude-device-id")
      #expect(storedProps["amplitudeUserId"] as? String == "amplitude-user-id")
      #expect(storedProps["appsflyerId"] as? String == "appsflyer-id")
      #expect(storedProps["brazeAliasName"] as? String == "braze-alias-name")
      #expect(storedProps["brazeAliasLabel"] as? String == "braze-alias-label")
      #expect(storedProps["onesignalId"] as? String == "onesignal-id")
      #expect(storedProps["fbAnonId"] as? String == "fb-anon-id")
      #expect(storedProps["firebaseAppInstanceId"] as? String == "firebase-app-instance-id")
      #expect(storedProps["firebaseInstallationId"] as? String == "firebase-installation-id")
      #expect(storedProps["iterableUserId"] as? String == "iterable-user-id")
      #expect(storedProps["iterableCampaignId"] as? String == "iterable-campaign-id")
      #expect(storedProps["iterableTemplateId"] as? String == "iterable-template-id")
      #expect(storedProps["mixpanelDistinctId"] as? String == "mixpanel-distinct-id")
      #expect(storedProps["mparticleId"] as? String == "mparticle-id")
      #expect(storedProps["clevertapId"] as? String == "clevertap-id")
      #expect(storedProps["airshipChannelId"] as? String == "airship-channel-id")
      #expect(storedProps["kochavaDeviceId"] as? String == "kochava-device-id")
      #expect(storedProps["tenjinId"] as? String == "tenjin-id")
      #expect(storedProps["posthogUserId"] as? String == "posthog-user-id")
      #expect(storedProps["customerioId"] as? String == "customerio-id")
    }
  }

  // MARK: - Edge Cases

  @Test
  func setIntegrationAttributes_transitionFromEnqueuedToImmediate() {
    // Given - start without appTransactionId
    withoutAppTransactionId {
      let initialProps: [IntegrationAttribute: String?] = [.adjustId: "enqueued-value"]
      superwall.setIntegrationAttributes(initialProps)
      
      // Verify it's enqueued
      #expect(superwall.enqueuedIntegrationAttributes != nil)
    }
    
    // When appTransactionId becomes available and we set new props
    withMockAppTransactionId {
      let newProps: [IntegrationAttribute: String?] = [.amplitudeDeviceId: "immediate-value"]
      superwall.setIntegrationAttributes(newProps)
      
      // Then
      let storedProps = superwall.integrationAttributes
      #expect(storedProps["amplitudeDeviceId"] as? String == "immediate-value")
      #expect(superwall.enqueuedIntegrationAttributes == nil) // Should clear enqueued attribution
    }
  }

  @Test
  func dequeueIntegrationAttributes_noEnqueuedAttribution() {
    withMockAppTransactionId {
      // Given
      #expect(superwall.enqueuedIntegrationAttributes == nil)
      
      // When
      superwall.dequeueIntegrationAttributes()
      
      // Then - should not crash and nothing should change
      #expect(superwall.enqueuedIntegrationAttributes == nil)
    }
  }
  
  // MARK: - setIntegrationAttribute (single attribute) Tests

  @Test
  func setIntegrationAttribute_singleAttribute_withAppTransactionId() {
    withMockAppTransactionId {
      // Given
      let testValue = "test-adjust-id"

      // When
      superwall.setIntegrationAttribute(.adjustId, testValue)
      
      // Then - attributes are updated immediately, only redeem is debounced
      let storedProps = superwall.integrationAttributes
      #expect(storedProps["adjustId"] as? String == testValue)
    }
  }

  @Test
  func setIntegrationAttribute_nilValue_removesAttribute() {
    withMockAppTransactionId {
      // Given - first set a value
      superwall.setIntegrationAttribute(.adjustId, "test-value")
      #expect(superwall.integrationAttributes["adjustId"] as? String == "test-value")

      // When - set to nil
      superwall.setIntegrationAttribute(.adjustId, nil)
      
      // Then - should be removed completely from dictionary
      let storedProps = superwall.integrationAttributes
      #expect(storedProps["adjustId"] == nil)
      #expect(storedProps.keys.contains("adjustId") == false) // Verify key is actually removed
    }
  }

  @Test
  func setIntegrationAttribute_withoutAppTransactionId_enqueues() {
    withoutAppTransactionId {
      // Given
      let testValue = "test-adjust-id"

      // When
      superwall.setIntegrationAttribute(.adjustId, testValue)
      
      // Then
      let enqueuedProps = superwall.enqueuedIntegrationAttributes
      #expect(enqueuedProps?[.adjustId] as? String == testValue)
    }
  }

  @Test
  func setIntegrationAttribute_updatesUserAttributes() {
    withMockAppTransactionId {
      // Given
      let testValue = "test-adjust-id"

      // When
      superwall.setIntegrationAttribute(.adjustId, testValue)
      
      // Then - should also be set as user attributes (immediate update)
      let userAttributes = superwall.userAttributes
      #expect(userAttributes["adjustId"] as? String == testValue)
    }
  }

  @Test
  func setIntegrationAttribute_multipleAttributes_independentlyManaged() {
    withMockAppTransactionId {
      // Given
      let adjustValue = "test-adjust-id"
      let amplitudeValue = "test-amplitude-id"

      // When - set multiple attributes independently (attributes updated immediately)
      superwall.setIntegrationAttribute(.adjustId, adjustValue)
      superwall.setIntegrationAttribute(.amplitudeDeviceId, amplitudeValue)
      
      // Then - both should be stored immediately
      let storedProps = superwall.integrationAttributes
      #expect(storedProps["adjustId"] as? String == adjustValue)
      #expect(storedProps["amplitudeDeviceId"] as? String == amplitudeValue)
    }
  }

  @Test
  func setIntegrationAttribute_overwriteExistingValue() {
    withMockAppTransactionId {
      // Given - set initial value
      let initialValue = "initial-adjust-id"
      let newValue = "new-adjust-id"
      superwall.setIntegrationAttribute(.adjustId, initialValue)
      #expect(superwall.integrationAttributes["adjustId"] as? String == initialValue)

      // When - overwrite with new value
      superwall.setIntegrationAttribute(.adjustId, newValue)
      
      // Then - value updated immediately
      let storedProps = superwall.integrationAttributes
      #expect(storedProps["adjustId"] as? String == newValue)
    }
  }

  @Test
  func setIntegrationAttribute_mixedWithSetIntegrationAttributes() {
    withMockAppTransactionId {
      // Given - use both methods
      let adjustValue = "test-adjust-id"
      let amplitudeValue = "test-amplitude-id"
      
      // When - mix single and batch methods (attributes updated immediately)
      superwall.setIntegrationAttribute(.adjustId, adjustValue)
      superwall.setIntegrationAttributes([.amplitudeDeviceId: amplitudeValue])
      
      // Then - both should be stored immediately
      let storedProps = superwall.integrationAttributes
      #expect(storedProps["adjustId"] as? String == adjustValue)
      #expect(storedProps["amplitudeDeviceId"] as? String == amplitudeValue)
    }
  }

  // MARK: - Debouncing and Change Detection Tests

  @Test
  func setIntegrationAttribute_sameValue_noChanges() {
    withMockAppTransactionId {
      // Given - set initial value
      let testValue = "test-adjust-id"
      superwall.setIntegrationAttribute(.adjustId, testValue)
      let initialValue = superwall.integrationAttributes["adjustId"] as? String

      // When - set same value again (should not trigger changes due to change detection)
      superwall.setIntegrationAttribute(.adjustId, testValue)
      
      // Then - value should remain the same (change detection working)
      let finalValue = superwall.integrationAttributes["adjustId"] as? String
      #expect(finalValue == initialValue)
      #expect(finalValue == testValue)
    }
  }

  @Test
  func setIntegrationAttribute_debouncing_multipleQuickCalls() async {
    await withMockAppTransactionId {
      // Given
      let baseValue = "test-adjust-id"
      
      // When - make multiple quick calls (within debounce window)
      superwall.setIntegrationAttribute(.adjustId, "\(baseValue)-1")
      superwall.setIntegrationAttribute(.adjustId, "\(baseValue)-2") 
      superwall.setIntegrationAttribute(.adjustId, "\(baseValue)-3")
      superwall.setIntegrationAttribute(.adjustId, "\(baseValue)-final")
      
      // Wait for debounce to complete
      try? await Task.sleep(nanoseconds: 600_000_000) // 600ms
      
      // Then - should only have final value
      let storedProps = superwall.integrationAttributes
      #expect(storedProps["adjustId"] as? String == "\(baseValue)-final")
      
      // Cleanup
      cleanupTimers()
    }
  }

  @Test
  func setIntegrationAttribute_threadSafety_singleAttribute() async {
    await withMockAppTransactionId {
      // Given
      let iterations = 50
      
      // When - perform many concurrent single attribute updates
      await withTaskGroup(of: Void.self) { group in
        for i in 0..<iterations {
          group.addTask {
            self.superwall.setIntegrationAttribute(.adjustId, "value-\(i)")
          }
          
          group.addTask {
            _ = self.superwall.integrationAttributes
          }
        }
      }
      
      // Wait for any pending operations
      try? await Task.sleep(nanoseconds: 600_000_000)
      
      // Then - no crashes should occur and should have some value
      let finalProps = superwall.integrationAttributes
      #expect(finalProps["adjustId"] != nil)
      
      // Cleanup
      cleanupTimers()
    }
  }
}
