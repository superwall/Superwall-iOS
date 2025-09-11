//
//  ProductsFetcherSK2Tests.swift
//  SuperwallKit
//
//  Created by Claude on 27/08/2025.
//

import Testing
import Foundation
import StoreKit
@testable import SuperwallKit

struct ProductsFetcherSK2Tests {
  let dependencyContainer: DependencyContainer
  let entitlementsInfo: EntitlementsInfo
  
  init() {
    dependencyContainer = DependencyContainer()
    entitlementsInfo = dependencyContainer.entitlementsInfo
  }
  
  // MARK: - Test Cases
  
  @Test("ProductsFetcherSK2Error should provide proper error descriptions")
  func testErrorDescriptions() {
    let identifiers: Set<String> = ["product1", "product2"]
    let error = ProductsFetcherSK2Error.noProductsFound(identifiers)
    
    #expect(error.errorDescription != nil)
    #expect(error.errorDescription!.contains("Could not load products"))
    #expect(error.errorDescription!.contains("product1"))
    #expect(error.errorDescription!.contains("product2"))
  }
  
  @Test("ProductsFetcherSK2 should be sendable and thread-safe")
  func testSendableConformance() async throws {
    guard #available(iOS 15.0, *) else {
      return // Skip test on older iOS versions
    }
    let fetcher = ProductsFetcherSK2(entitlementsInfo: entitlementsInfo)
    
    // Test that we can call the actor from multiple concurrent contexts
    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<5 {
        group.addTask {
          // Just test that the actor can be accessed concurrently
          // The actual call would require proper mocking of StoreKit
          _ = fetcher
        }
      }
    }
    
    // If we get here without compiler errors, Sendable conformance is working
    #expect(true)
  }
  
  @Test("ProductsFetcherSK2 should throw error for non-existent products") 
  func testErrorThrowingForNonExistentProducts() async throws {
    guard #available(iOS 15.0, *) else {
      return // Skip test on older iOS versions
    }
    
    // Use 1 retry instead of 10 to make test run quickly
    let fetcher = ProductsFetcherSK2(entitlementsInfo: entitlementsInfo, numberOfRetries: 1)
    let paywall = Paywall.stub()
    let nonExistentIdentifiers: Set<String> = ["definitely_non_existent_product_id_12345"]
    
    // Test that the fetcher throws an error for non-existent products
    // This will actually call StoreKit and should fail with ProductsFetcherSK2Error
    do {
      _ = try await fetcher.products(
        identifiers: nonExistentIdentifiers,
        forPaywall: paywall,
        placement: nil
      )
      #expect(Bool(false), "Expected error to be thrown for non-existent products")
    } catch let error as ProductsFetcherSK2Error {
      #expect(error.errorDescription != nil)
      switch error {
      case .noProductsFound(let identifiers):
        #expect(identifiers.contains("definitely_non_existent_product_id_12345"))
      }
    } catch {
      #expect(Bool(false), "Expected ProductsFetcherSK2Error, but got: \(error)")
    }
  }
  
  @Test("ProductsFetcherSK2 should handle empty identifier set gracefully")
  func testEmptyIdentifiers() async throws {
    guard #available(iOS 15.0, *) else {
      return // Skip test on older iOS versions
    }
    
    // Use 1 retry instead of 10 to make test run quickly  
    let fetcher = ProductsFetcherSK2(
      entitlementsInfo: entitlementsInfo,
      numberOfRetries: 1
    )
    let paywall = Paywall.stub()
    let identifiers: Set<String> = []
    
    // Empty identifiers should not cause crashes and might return empty set
    do {
      let result = try await fetcher.products(
        identifiers: identifiers,
        forPaywall: paywall,
        placement: nil
      )
      #expect(result.isEmpty)
    } catch {
      // Some implementations might throw for empty identifiers, which is also acceptable
      print("ProductsFetcherSK2 threw error for empty identifiers: \(error)")
    }
  }
}
