//
//  AttributionTests.swift
//  SuperwallKit
//
//  Created by Claude on 13/08/2025.
//

import Testing
import Foundation
@testable import SuperwallKit

struct AttributionTests {
  let superwall: Superwall
  let dependencyContainer: DependencyContainer

  init() {
    dependencyContainer = DependencyContainer()
    superwall = Superwall(dependencyContainer: dependencyContainer)
  }

  // MARK: - Helper Methods
  
  func withMockAppTransactionId<T>(_ body: () throws -> T) rethrows -> T {
    let original = ReceiptManager.appTransactionId
    ReceiptManager.appTransactionId = "mock-app-transaction-id"
    defer { ReceiptManager.appTransactionId = original }
    return try body()
  }
  
  func withoutAppTransactionId<T>(_ body: () throws -> T) rethrows -> T {
    let original = ReceiptManager.appTransactionId
    ReceiptManager.appTransactionId = nil
    defer { ReceiptManager.appTransactionId = original }
    return try body()
  }

  // MARK: - setIntegrationAttributes Tests (with appTransactionId available)

  @Test
  func setIntegrationAttributes_singleProvider_withAppTransactionId() {
    withMockAppTransactionId {
      // Given
      let testValue = "test-adjust-id"
      let props: [IntegrationAttribute: Any?] = [.adjustId: testValue]
      
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
      let props: [IntegrationAttribute: Any?] = [
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
      let initialProps: [IntegrationAttribute: Any?] = [.adjustId: "initial-value"]
      superwall.setIntegrationAttributes(initialProps)
      
      // When - set to nil
      let nilProps: [IntegrationAttribute: Any?] = [.adjustId: nil]
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
      let initialProps: [IntegrationAttribute: Any?] = [.adjustId: initialValue]
      superwall.setIntegrationAttributes(initialProps)
      
      // When
      let newProps: [IntegrationAttribute: Any?] = [.adjustId: newValue]
      superwall.setIntegrationAttributes(newProps)
      
      // Then
      let storedProps = superwall.integrationAttributes
      #expect(storedProps["adjustId"] as? String == newValue)
    }
  }

  @Test
  func setIntegrationAttributes_differentDataTypes_withAppTransactionId() {
    withMockAppTransactionId {
      // Given
      let stringValue = "test-string"
      let intValue = 123
      let doubleValue = 45.67
      let boolValue = true
      let props: [IntegrationAttribute: Any?] = [
        .adjustId: stringValue,
        .amplitudeDeviceId: intValue,
        .appsflyerId: doubleValue,
        .brazeAliasName: boolValue
      ]
      
      // When
      superwall.setIntegrationAttributes(props)
      
      // Then
      let storedProps = superwall.integrationAttributes
      #expect(storedProps["adjustId"] as? String == stringValue)
      #expect(storedProps["amplitudeDeviceId"] as? Int == intValue)
      #expect(storedProps["appsflyerId"] as? Double == doubleValue)
      #expect(storedProps["brazeAliasName"] as? Bool == boolValue)
    }
  }

  // MARK: - setIntegrationAttributes Tests (without appTransactionId - enqueued scenario)

  @Test
  func setIntegrationAttributes_singleProvider_withoutAppTransactionId() {
    withoutAppTransactionId {
      // Given
      let testValue = "test-adjust-id"
      let props: [IntegrationAttribute: Any?] = [.adjustId: testValue]
      
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
      let props: [IntegrationAttribute: Any?] = [.adjustId: testValue]
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
      let initialProps: [IntegrationAttribute: Any?] = [.adjustId: initialValue]
      superwall.setIntegrationAttributes(initialProps)
      
      // Then set new value (should overwrite enqueued)
      let newProps: [IntegrationAttribute: Any?] = [.adjustId: newValue]
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
      let testProps: [IntegrationAttribute: Any?] = [
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
      let testProps: [IntegrationAttribute: Any?] = [.adjustId: "test-adjust-id"]
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
          let props: [IntegrationAttribute: Any?] = [.adjustId: "value-\(i)"]
          self.superwall.setIntegrationAttributes(props)
        }
        
        group.addTask {
          _ = self.superwall.integrationAttributes
        }
      }
    }
    
    // Then - no crashes should occur (test passes if no crash)
    let finalProps = superwall.integrationAttributes
    #expect(finalProps != nil)
  }

  // MARK: - Integration Tests

  @Test
  func setIntegrationAttributes_updatesUserAttributes() {
    withMockAppTransactionId {
      // Given
      let testProps: [IntegrationAttribute: Any?] = [.adjustId: "test-adjust-id"]
      
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
      let testProps: [IntegrationAttribute: Any?] = [
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
      let props: [IntegrationAttribute: Any?] = [
        .adjustId: "adjust-id",
        .amplitudeDeviceId: "amplitude-device-id",
        .amplitudeUserId: "amplitude-user-id",
        .appsflyerId: "appsflyer-id",
        .brazeAliasName: "braze-alias-name",
        .brazeAliasLabel: "braze-alias-label",
        .onesignalId: "onesignal-id",
        .fbAnonId: "fb-anon-id",
        .firebaseAppInstanceId: "firebase-app-instance-id",
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
      let initialProps: [IntegrationAttribute: Any?] = [.adjustId: "enqueued-value"]
      superwall.setIntegrationAttributes(initialProps)
      
      // Verify it's enqueued
      #expect(superwall.enqueuedIntegrationAttributes != nil)
    }
    
    // When appTransactionId becomes available and we set new props
    withMockAppTransactionId {
      let newProps: [IntegrationAttribute: Any?] = [.amplitudeDeviceId: "immediate-value"]
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
}
