//
//  TeardownTests.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 11/12/2025.
//

import Testing
import Foundation
@testable import SuperwallKit

@Suite("Superwall Teardown Tests")
struct TeardownTests {
  @Test("teardown resets isInitialized to false")
  func testTeardownResetsIsInitialized() async throws {
    // Configure Superwall
    _ = Superwall.configure(apiKey: "pk_e361c8a9662281f4249f2fa11d1a63854615fa80e15e7a4d")

    // Verify it's initialized
    #expect(Superwall.isInitialized == true)

    // Teardown
    Superwall.teardown()

    // Verify it's no longer initialized
    #expect(Superwall.isInitialized == false)
  }

  @Test("teardown allows reconfiguration")
  func testTeardownAllowsReconfiguration() async throws {
    // Configure Superwall
    _ = Superwall.configure(apiKey: "pk_e361c8a9662281f4249f2fa11d1a63854615fa80e15e7a4d")
    #expect(Superwall.isInitialized == true)

    // Teardown
    Superwall.teardown()
    #expect(Superwall.isInitialized == false)

    // Reconfigure with a different API key
    _ = Superwall.configure(apiKey: "test_api_key_2")

    // Verify it's initialized again
    #expect(Superwall.isInitialized == true)

    // Clean up
    Superwall.teardown()
  }

  @Test("teardown can be called multiple times safely")
  func testTeardownMultipleTimesSafely() async throws {
    // Configure Superwall
    _ = Superwall.configure(apiKey: "test_api_key")
    #expect(Superwall.isInitialized == true)

    // Teardown multiple times
    Superwall.teardown()
    #expect(Superwall.isInitialized == false)

    Superwall.teardown()
    #expect(Superwall.isInitialized == false)

    Superwall.teardown()
    #expect(Superwall.isInitialized == false)
  }

  @Test("teardown without prior configuration doesn't crash")
  func testTeardownWithoutConfiguration() async throws {
    // Ensure we start in a clean state
    Superwall.teardown()

    // This should not crash
    Superwall.teardown()

    #expect(Superwall.isInitialized == false)
  }

  @Test("teardown and reconfigure with same API key")
  func testTeardownAndReconfigureWithSameApiKey() async throws {
    let apiKey = "pk_e361c8a9662281f4249f2fa11d1a63854615fa80e15e7a4d"

    // First configuration
    _ = Superwall.configure(apiKey: apiKey)
    #expect(Superwall.isInitialized == true)

    // Verify initial state is pending (config loading in background)
    #expect(Superwall.shared.configurationStatus == .pending)

    // Teardown
    Superwall.teardown()
    #expect(Superwall.isInitialized == false)

    // Reconfigure with the same API key
    _ = Superwall.configure(apiKey: apiKey)

    // Verify it initializes again successfully
    #expect(Superwall.isInitialized == true)

    // Verify it starts in pending state again (fresh config fetch)
    #expect(Superwall.shared.configurationStatus == .pending)

    // Clean up
    Superwall.teardown()
  }
}
