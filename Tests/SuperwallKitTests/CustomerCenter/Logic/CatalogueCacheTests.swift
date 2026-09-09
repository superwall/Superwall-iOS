//
//  CatalogueCacheTests.swift
//
//
//  Created by Jordan Morgan on 09/09/2026.
//

import Testing
import Foundation
@testable import SuperwallKit

@Suite("Catalogue cache")
struct CatalogueCacheTests {
  private func response() -> SuperwallProductsResponse {
    let json = #"{"data":[],"object":"list","has_more":false}"#
    // swiftlint:disable:next force_try
    return try! JSONDecoder().decode(SuperwallProductsResponse.self, from: Data(json.utf8))
  }

  /// The reason this exists: `apply(customerInfo:refetchProducts:)` runs on load, on every restore
  /// and after every sheet dismissal, and all four call sites refetch.
  @available(iOS 15.0, *)
  @Test("a second visit inside the window doesn't refetch")
  func cachesWithinTheWindow() async throws {
    var clock = Date(timeIntervalSince1970: 1_000_000)
    let cache = CatalogueCache { clock }
    var fetches = 0

    _ = try await cache.products { fetches += 1; return response() }
    clock = clock.addingTimeInterval(CatalogueCache.ttl - 1)
    _ = try await cache.products { fetches += 1; return response() }

    #expect(fetches == 1)
  }

  @available(iOS 15.0, *)
  @Test("the cache expires, so a price edit shows up")
  func expiresAfterTheWindow() async throws {
    var clock = Date(timeIntervalSince1970: 1_000_000)
    let cache = CatalogueCache { clock }
    var fetches = 0

    _ = try await cache.products { fetches += 1; return response() }
    clock = clock.addingTimeInterval(CatalogueCache.ttl + 1)
    _ = try await cache.products { fetches += 1; return response() }

    #expect(fetches == 2)
  }

  /// A failed load must not be remembered: the cards render without prices and the next `apply`
  /// should try again, rather than serving the failure for five minutes.
  @available(iOS 15.0, *)
  @Test("a failure isn't cached")
  func doesNotCacheFailures() async throws {
    struct Boom: Error {}
    let cache = CatalogueCache()
    var fetches = 0

    await #expect(throws: Boom.self) {
      _ = try await cache.products { fetches += 1; throw Boom() }
    }
    _ = try await cache.products { fetches += 1; return response() }

    #expect(fetches == 2)
  }
}
