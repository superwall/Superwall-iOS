//
//  CatalogueTimeoutTests.swift
//
//
//  Created by Yusuf Tör on 15/10/2026.
//

import Testing
import Foundation
@testable import SuperwallKit

@Suite("Catalogue timeout")
struct CatalogueTimeoutTests {
  /// The live request retries in a task of its own, which cancellation doesn't reach. Waiting for
  /// it to wind down would keep the cards on placeholders through the whole retry schedule.
  @Test("gives up on time even when the request ignores cancellation")
  func givesUpOnTime() async {
    let started = Date()
    await #expect(throws: CancellationError.self) {
      try await LiveProductsProvider.withCatalogueTimeout(seconds: 0.1) {
        // A separate task, like the retrying request: cancelling the caller doesn't stop it.
        try await Task {
          try await Task.sleep(nanoseconds: 3_000_000_000)
          return SuperwallProductsResponse(data: [])
        }.value
      }
    }
    #expect(Date().timeIntervalSince(started) < 1.5, "waited for the request instead of the timeout")
  }

  @Test("hands back an answer that arrives in time")
  func returnsAnAnswerInTime() async throws {
    let response = try await LiveProductsProvider.withCatalogueTimeout(seconds: 2) {
      SuperwallProductsResponse(data: [])
    }
    #expect(response.data.isEmpty)
  }

  @Test("passes on the request's own error")
  func passesOnTheRequestsError() async {
    await #expect(throws: URLError.self) {
      try await LiveProductsProvider.withCatalogueTimeout(seconds: 2) {
        throw URLError(.notConnectedToInternet)
      }
    }
  }
}
