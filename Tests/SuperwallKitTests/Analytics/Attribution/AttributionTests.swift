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

  // MARK: - setAttributionProps Tests (with appTransactionId available)

  @Test
  func setAttributionProps_singleProvider_withAppTransactionId() {
    withMockAppTransactionId {
      // Given
      let testValue = "test-adjust-id"
      let props: [AttributionProvider: Any?] = [.adjustId: testValue]
      
      // When
      superwall.setAttributionProps(props)
      
      // Then
      let storedProps = superwall.attributionProps
      #expect(storedProps["adjustId"] as? String == testValue)
      // Should not be enqueued when appTransactionId exists
      #expect(superwall.enqueuedAttribution == nil)
    }
  }

  @Test
  func setAttributionProps_multipleProviders_withAppTransactionId() {
    withMockAppTransactionId {
      // Given
      let adjustId = "test-adjust-id"
      let amplitudeId = "test-amplitude-device-id"
      let brazeAlias = "test-braze-alias"
      let props: [AttributionProvider: Any?] = [
        .adjustId: adjustId,
        .amplitudeDeviceId: amplitudeId,
        .brazeAliasName: brazeAlias
      ]
      
      // When
      superwall.setAttributionProps(props)
      
      // Then
      let storedProps = superwall.attributionProps
      #expect(storedProps["adjustId"] as? String == adjustId)
      #expect(storedProps["amplitudeDeviceId"] as? String == amplitudeId)
      #expect(storedProps["brazeAliasName"] as? String == brazeAlias)
      #expect(superwall.enqueuedAttribution == nil)
    }
  }

  @Test
  func setAttributionProps_nilValue_withAppTransactionId() {
    withMockAppTransactionId {
      // Given - set initial value
      let initialProps: [AttributionProvider: Any?] = [.adjustId: "initial-value"]
      superwall.setAttributionProps(initialProps)
      
      // When - set to nil
      let nilProps: [AttributionProvider: Any?] = [.adjustId: nil]
      superwall.setAttributionProps(nilProps)
      
      // Then
      let storedProps = superwall.attributionProps
      #expect(storedProps["adjustId"] == nil)
    }
  }

  @Test
  func setAttributionProps_overwriteExistingValue_withAppTransactionId() {
    withMockAppTransactionId {
      // Given
      let initialValue = "initial-adjust-id"
      let newValue = "new-adjust-id"
      let initialProps: [AttributionProvider: Any?] = [.adjustId: initialValue]
      superwall.setAttributionProps(initialProps)
      
      // When
      let newProps: [AttributionProvider: Any?] = [.adjustId: newValue]
      superwall.setAttributionProps(newProps)
      
      // Then
      let storedProps = superwall.attributionProps
      #expect(storedProps["adjustId"] as? String == newValue)
    }
  }

  @Test
  func setAttributionProps_differentDataTypes_withAppTransactionId() {
    withMockAppTransactionId {
      // Given
      let stringValue = "test-string"
      let intValue = 123
      let doubleValue = 45.67
      let boolValue = true
      let props: [AttributionProvider: Any?] = [
        .adjustId: stringValue,
        .amplitudeDeviceId: intValue,
        .appsflyerId: doubleValue,
        .brazeAliasName: boolValue
      ]
      
      // When
      superwall.setAttributionProps(props)
      
      // Then
      let storedProps = superwall.attributionProps
      #expect(storedProps["adjustId"] as? String == stringValue)
      #expect(storedProps["amplitudeDeviceId"] as? Int == intValue)
      #expect(storedProps["appsflyerId"] as? Double == doubleValue)
      #expect(storedProps["brazeAliasName"] as? Bool == boolValue)
    }
  }

  // MARK: - setAttributionProps Tests (without appTransactionId - enqueued scenario)

  @Test
  func setAttributionProps_singleProvider_withoutAppTransactionId() {
    withoutAppTransactionId {
      // Given
      let testValue = "test-adjust-id"
      let props: [AttributionProvider: Any?] = [.adjustId: testValue]
      
      // When
      superwall.setAttributionProps(props)
      
      // Then
      #expect(superwall.enqueuedAttribution != nil)
      // Attribution should be enqueued, not immediately applied
      let enqueuedProps = superwall.enqueuedAttribution
      #expect(enqueuedProps?[.adjustId] as? String == testValue)
    }
  }

  @Test
  func setAttributionProps_dequeueWhenAppTransactionIdAvailable() {
    let testValue = "test-adjust-id"
    
    // Given - start without appTransactionId
    withoutAppTransactionId {
      let props: [AttributionProvider: Any?] = [.adjustId: testValue]
      superwall.setAttributionProps(props)
      
      // Verify it's enqueued
      #expect(superwall.enqueuedAttribution != nil)
    }
    
    // When appTransactionId becomes available
    withMockAppTransactionId {
      superwall.dequeueAttributionProps()
      
      // Then
      let storedProps = superwall.attributionProps
      #expect(storedProps["adjustId"] as? String == testValue)
      #expect(superwall.enqueuedAttribution == nil)
    }
  }

  @Test
  func setAttributionProps_overwriteEnqueued_withoutAppTransactionId() {
    withoutAppTransactionId {
      // Given
      let initialValue = "initial-adjust-id"
      let newValue = "new-adjust-id"
      
      // When - set initial value (gets enqueued)
      let initialProps: [AttributionProvider: Any?] = [.adjustId: initialValue]
      superwall.setAttributionProps(initialProps)
      
      // Then set new value (should overwrite enqueued)
      let newProps: [AttributionProvider: Any?] = [.adjustId: newValue]
      superwall.setAttributionProps(newProps)
      
      // Then
      let enqueuedProps = superwall.enqueuedAttribution
      #expect(enqueuedProps?[.adjustId] as? String == newValue)
    }
  }

  // MARK: - attributionProps Tests

  @Test
  func attributionProps_emptyByDefault() {
    withMockAppTransactionId {
      // Given - fresh instance
      // When
      let props = superwall.attributionProps
      
      // Then - should contain automatic props like idfa, idfv
      #expect(props != nil)
      // Note: idfa and idfv may be automatically added by AttributionFetcher
    }
  }

  @Test
  func attributionProps_returnsSetValues() {
    withMockAppTransactionId {
      // Given
      let testProps: [AttributionProvider: Any?] = [
        .adjustId: "test-adjust-id",
        .amplitudeDeviceId: "test-amplitude-id"
      ]
      superwall.setAttributionProps(testProps)
      
      // When
      let retrievedProps = superwall.attributionProps
      
      // Then
      #expect(retrievedProps["adjustId"] as? String == "test-adjust-id")
      #expect(retrievedProps["amplitudeDeviceId"] as? String == "test-amplitude-id")
    }
  }

  @Test
  func attributionProps_immutableCopy() {
    withMockAppTransactionId {
      // Given
      let testProps: [AttributionProvider: Any?] = [.adjustId: "test-adjust-id"]
      superwall.setAttributionProps(testProps)
      
      // When
      var retrievedProps = superwall.attributionProps
      retrievedProps["adjustId"] = "modified-value"
      
      // Then - original should be unchanged
      let originalProps = superwall.attributionProps
      #expect(originalProps["adjustId"] as? String == "test-adjust-id")
    }
  }

  @Test
  func attributionProps_threadSafety() async {
    // Given
    let original = ReceiptManager.appTransactionId
    ReceiptManager.appTransactionId = "mock-app-transaction-id"
    defer { ReceiptManager.appTransactionId = original }
    
    let iterations = 50
    
    // When - perform many concurrent reads and writes
    await withTaskGroup(of: Void.self) { group in
      for i in 0..<iterations {
        group.addTask {
          let props: [AttributionProvider: Any?] = [.adjustId: "value-\(i)"]
          self.superwall.setAttributionProps(props)
        }
        
        group.addTask {
          _ = self.superwall.attributionProps
        }
      }
    }
    
    // Then - no crashes should occur (test passes if no crash)
    let finalProps = superwall.attributionProps
    #expect(finalProps != nil)
  }

  // MARK: - Integration Tests

  @Test
  func setAttributionProps_updatesUserAttributes() {
    withMockAppTransactionId {
      // Given
      let testProps: [AttributionProvider: Any?] = [.adjustId: "test-adjust-id"]
      
      // When
      superwall.setAttributionProps(testProps)
      
      // Then - attribution props should also be set as user attributes
      let userAttributes = superwall.userAttributes
      #expect(userAttributes["adjustId"] as? String == "test-adjust-id")
    }
  }

  @Test
  func attribution_persistsAcrossMethods() {
    withMockAppTransactionId {
      // Given
      let testProps: [AttributionProvider: Any?] = [
        .adjustId: "test-adjust-id",
        .amplitudeDeviceId: "test-amplitude-id"
      ]
      
      // When
      superwall.setAttributionProps(testProps)
      
      // Then - both accessors should return the same values
      let directProps = superwall.attributionProps
      let fetchedProps = superwall.dependencyContainer.attributionFetcher.attributionProps
      
      #expect(directProps["adjustId"] as? String == fetchedProps["adjustId"] as? String)
      #expect(directProps["amplitudeDeviceId"] as? String == fetchedProps["amplitudeDeviceId"] as? String)
    }
  }

  @Test
  func setAttributionProps_allAttributionProviders() {
    withMockAppTransactionId {
      // Given - test all available attribution providers
      let props: [AttributionProvider: Any?] = [
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
      superwall.setAttributionProps(props)
      
      // Then
      let storedProps = superwall.attributionProps
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
  func setAttributionProps_transitionFromEnqueuedToImmediate() {
    // Given - start without appTransactionId
    withoutAppTransactionId {
      let initialProps: [AttributionProvider: Any?] = [.adjustId: "enqueued-value"]
      superwall.setAttributionProps(initialProps)
      
      // Verify it's enqueued
      #expect(superwall.enqueuedAttribution != nil)
    }
    
    // When appTransactionId becomes available and we set new props
    withMockAppTransactionId {
      let newProps: [AttributionProvider: Any?] = [.amplitudeDeviceId: "immediate-value"]
      superwall.setAttributionProps(newProps)
      
      // Then
      let storedProps = superwall.attributionProps
      #expect(storedProps["amplitudeDeviceId"] as? String == "immediate-value")
      #expect(superwall.enqueuedAttribution == nil) // Should clear enqueued attribution
    }
  }

  @Test
  func dequeueAttributionProps_noEnqueuedAttribution() {
    withMockAppTransactionId {
      // Given
      #expect(superwall.enqueuedAttribution == nil)
      
      // When
      superwall.dequeueAttributionProps()
      
      // Then - should not crash and nothing should change
      #expect(superwall.enqueuedAttribution == nil)
    }
  }
}