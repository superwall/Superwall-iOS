//
//  IntroOfferTokenManagerTests.swift
//  SuperwallKitTests
//
//  Created by Yusuf Tör on 07/11/2025.
//
// swiftlint:disable all

@testable import SuperwallKit
import Testing
import Foundation

struct IntroOfferTokenManagerTests {
  // MARK: - Successful Token Fetching

  @Test
  func fetchTokens_withValidParameters_storesTokens() async {
    // Given
    let network = NetworkMock(options: SuperwallOptions(), factory: DependencyContainer())
    let manager = IntroOfferTokenManager(network: network)

    let productId1 = "com.example.product1"
    let productId2 = "com.example.product2"
    let token1 = IntroOfferToken(
      token: "token1",
      expiry: Date().addingTimeInterval(3600) // 1 hour from now
    )
    let token2 = IntroOfferToken(
      token: "token2",
      expiry: Date().addingTimeInterval(7200) // 2 hours from now
    )
    let expectedTokens = [
      productId1: token1,
      productId2: token2
    ]
    network.getIntroOfferTokenResult = .success(expectedTokens)

    // When
    await manager.fetchTokens(
      introOfferEligibility: .eligible,
      paywallId: "test_paywall",
      productIds: [productId1, productId2],
      appTransactionId: "app_transaction_123"
    )

    // Then
    #expect(manager.tokens.count == 2)
    #expect(manager.tokens[productId1]?.token == "token1")
    #expect(manager.tokens[productId2]?.token == "token2")
    #expect(network.getIntroOfferTokenCallCount == 1)
  }

  // MARK: - Guard Validation

  @Test
  func fetchTokens_withAutomaticEligibility_doesNotFetchTokens() async {
    // Given
    let network = NetworkMock(options: SuperwallOptions(), factory: DependencyContainer())
    let manager = IntroOfferTokenManager(network: network)
    network.getIntroOfferTokenResult = .success([:])

    // When
    await manager.fetchTokens(
      introOfferEligibility: .automatic,
      paywallId: "test_paywall",
      productIds: ["com.example.product"],
      appTransactionId: "app_transaction_123"
    )

    // Then
    #expect(manager.tokens.isEmpty)
    #expect(network.getIntroOfferTokenCallCount == 0)
  }

  @Test
  func fetchTokens_withEmptyProductIds_doesNotFetchTokens() async {
    // Given
    let network = NetworkMock(options: SuperwallOptions(), factory: DependencyContainer())
    let manager = IntroOfferTokenManager(network: network)
    network.getIntroOfferTokenResult = .success([:])

    // When
    await manager.fetchTokens(
      introOfferEligibility: .eligible,
      paywallId: "test_paywall",
      productIds: [],
      appTransactionId: "app_transaction_123"
    )

    // Then
    #expect(manager.tokens.isEmpty)
    #expect(network.getIntroOfferTokenCallCount == 0)
  }

  @Test
  func fetchTokens_withNilAppTransactionId_doesNotFetchTokens() async {
    // Given
    let network = NetworkMock(options: SuperwallOptions(), factory: DependencyContainer())
    let manager = IntroOfferTokenManager(network: network)
    network.getIntroOfferTokenResult = .success([:])

    // When
    await manager.fetchTokens(
      introOfferEligibility: .eligible,
      paywallId: "test_paywall",
      productIds: ["com.example.product"],
      appTransactionId: nil
    )

    // Then
    #expect(manager.tokens.isEmpty)
    #expect(network.getIntroOfferTokenCallCount == 0)
  }

  @Test
  func fetchTokens_withIneligibleEligibility_fetchesTokens() async {
    // Given
    let network = NetworkMock(options: SuperwallOptions(), factory: DependencyContainer())
    let manager = IntroOfferTokenManager(network: network)

    let productId = "com.example.product"
    let token = IntroOfferToken(
      token: "token1",
      expiry: Date().addingTimeInterval(3600)
    )
    network.getIntroOfferTokenResult = .success([productId: token])

    // When
    await manager.fetchTokens(
      introOfferEligibility: .ineligible,
      paywallId: "test_paywall",
      productIds: [productId],
      appTransactionId: "app_transaction_123"
    )

    // Then
    #expect(manager.tokens.count == 1)
    #expect(network.getIntroOfferTokenCallCount == 1)
  }

  // MARK: - Token Validation

  @Test
  func getValidToken_withValidToken_returnsToken() async {
    // Given
    let network = NetworkMock(options: SuperwallOptions(), factory: DependencyContainer())
    let manager = IntroOfferTokenManager(network: network)

    let productId = "com.example.product"
    let token = IntroOfferToken(
      token: "token1",
      expiry: Date().addingTimeInterval(3600) // 1 hour from now
    )
    network.getIntroOfferTokenResult = .success([productId: token])

    await manager.fetchTokens(
      introOfferEligibility: .eligible,
      paywallId: "test_paywall",
      productIds: [productId],
      appTransactionId: "app_transaction_123"
    )

    // When
    let validToken = manager.getValidToken(for: productId)

    // Then
    #expect(validToken != nil)
    #expect(validToken?.token == "token1")
  }

  @Test
  func getValidToken_withExpiredToken_returnsNil() async {
    // Given
    let network = NetworkMock(options: SuperwallOptions(), factory: DependencyContainer())
    let manager = IntroOfferTokenManager(network: network)

    let productId = "com.example.product"
    let token = IntroOfferToken(
      token: "token1",
      expiry: Date().addingTimeInterval(-3600) // 1 hour ago (expired)
    )
    network.getIntroOfferTokenResult = .success([productId: token])

    await manager.fetchTokens(
      introOfferEligibility: .eligible,
      paywallId: "test_paywall",
      productIds: [productId],
      appTransactionId: "app_transaction_123"
    )

    // When
    let validToken = manager.getValidToken(for: productId)

    // Then
    #expect(validToken == nil)
  }

  @Test
  func getValidToken_withNonExistentProductId_returnsNil() {
    // Given
    let network = NetworkMock(options: SuperwallOptions(), factory: DependencyContainer())
    let manager = IntroOfferTokenManager(network: network)

    // When
    let validToken = manager.getValidToken(for: "non_existent_product")

    // Then
    #expect(validToken == nil)
  }

  // MARK: - Network Error Handling

  @Test
  func fetchTokens_withNetworkError_logsErrorAndDoesNotStoreTokens() async {
    // Given
    let network = NetworkMock(options: SuperwallOptions(), factory: DependencyContainer())
    let manager = IntroOfferTokenManager(network: network)
    network.getIntroOfferTokenResult = .failure(NetworkError.unknown)

    // When
    await manager.fetchTokens(
      introOfferEligibility: .eligible,
      paywallId: "test_paywall",
      productIds: ["com.example.product"],
      appTransactionId: "app_transaction_123"
    )

    // Then - tokens should remain empty after error
    #expect(manager.tokens.isEmpty)
  }

  // MARK: - Token Refresh

  @Test
  func refreshIfExpired_withNoTokens_doesNotRefresh() {
    // Given
    let network = NetworkMock(options: SuperwallOptions(), factory: DependencyContainer())
    let manager = IntroOfferTokenManager(network: network)

    // When
    manager.refreshIfExpired()

    // Then
    #expect(network.getIntroOfferTokenCallCount == 0)
  }

  @Test
  func refreshIfExpired_withValidTokens_doesNotRefresh() async {
    // Given
    let network = NetworkMock(options: SuperwallOptions(), factory: DependencyContainer())
    let manager = IntroOfferTokenManager(network: network)

    let productId = "com.example.product"
    let token = IntroOfferToken(
      token: "token1",
      expiry: Date().addingTimeInterval(3600) // 1 hour from now
    )
    network.getIntroOfferTokenResult = .success([productId: token])

    await manager.fetchTokens(
      introOfferEligibility: .eligible,
      paywallId: "test_paywall",
      productIds: [productId],
      appTransactionId: "app_transaction_123"
    )

    #expect(network.getIntroOfferTokenCallCount == 1)

    // When
    manager.refreshIfExpired()

    // Wait a bit for async task to potentially complete
    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

    // Then - should still be 1, not 2
    #expect(network.getIntroOfferTokenCallCount == 1)
  }

  @Test
  func refreshIfExpired_withExpiredTokens_refreshesTokens() async {
    // Given
    let network = NetworkMock(options: SuperwallOptions(), factory: DependencyContainer())
    let manager = IntroOfferTokenManager(network: network)

    let productId = "com.example.product"
    let expiredToken = IntroOfferToken(
      token: "expired_token",
      expiry: Date().addingTimeInterval(-3600) // 1 hour ago (expired)
    )
    network.getIntroOfferTokenResult = .success([productId: expiredToken])

    await manager.fetchTokens(
      introOfferEligibility: .eligible,
      paywallId: "test_paywall",
      productIds: [productId],
      appTransactionId: "app_transaction_123"
    )

    #expect(network.getIntroOfferTokenCallCount == 1)

    // Set up new token for refresh
    let freshToken = IntroOfferToken(
      token: "fresh_token",
      expiry: Date().addingTimeInterval(3600) // 1 hour from now
    )
    network.getIntroOfferTokenResult = .success([productId: freshToken])

    // When
    manager.refreshIfExpired()

    // Wait for async task to complete
    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

    // Then
    #expect(network.getIntroOfferTokenCallCount == 2)
    #expect(manager.tokens[productId]?.token == "fresh_token")
  }

  // MARK: - App Lifecycle Observation

  @Test
  func startObservingAppLifecycle_registersObserver() {
    // Given
    let network = NetworkMock(options: SuperwallOptions(), factory: DependencyContainer())
    let manager = IntroOfferTokenManager(network: network)

    // When
    manager.startObservingAppLifecycle()

    // Then - calling again should not add another observer (idempotent)
    manager.startObservingAppLifecycle()

    // Cleanup
    manager.stopObservingAppLifecycle()
  }

  @Test
  func stopObservingAppLifecycle_removesObserver() {
    // Given
    let network = NetworkMock(options: SuperwallOptions(), factory: DependencyContainer())
    let manager = IntroOfferTokenManager(network: network)

    manager.startObservingAppLifecycle()

    // When
    manager.stopObservingAppLifecycle()

    // Then - calling again should be safe
    manager.stopObservingAppLifecycle()
  }

  // MARK: - Parameter Storage

  @Test
  func fetchTokens_storesParametersForRefresh() async {
    // Given
    let network = NetworkMock(options: SuperwallOptions(), factory: DependencyContainer())
    let manager = IntroOfferTokenManager(network: network)

    let productId = "com.example.product"
    let expiredToken = IntroOfferToken(
      token: "expired_token",
      expiry: Date().addingTimeInterval(-3600) // 1 hour ago (expired)
    )
    network.getIntroOfferTokenResult = .success([productId: expiredToken])

    // When
    await manager.fetchTokens(
      introOfferEligibility: .eligible,
      paywallId: "test_paywall",
      productIds: [productId],
      appTransactionId: "app_transaction_123"
    )

    // Set up new token for refresh
    let freshToken = IntroOfferToken(
      token: "fresh_token",
      expiry: Date().addingTimeInterval(3600)
    )
    network.getIntroOfferTokenResult = .success([productId: freshToken])

    // When refreshing with expired tokens
    manager.refreshIfExpired()

    // Wait for async task to complete
    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

    // Then - should use stored parameters for refresh
    #expect(network.getIntroOfferTokenCallCount == 2)
    #expect(manager.tokens[productId]?.token == "fresh_token")
  }

  // MARK: - Multiple Products

  @Test
  func fetchTokens_withMultipleProducts_storesAllTokens() async {
    // Given
    let network = NetworkMock(options: SuperwallOptions(), factory: DependencyContainer())
    let manager = IntroOfferTokenManager(network: network)

    let productIds = [
      "com.example.product1",
      "com.example.product2",
      "com.example.product3"
    ]
    let tokens = [
      productIds[0]: IntroOfferToken(token: "token1", expiry: Date().addingTimeInterval(3600)),
      productIds[1]: IntroOfferToken(token: "token2", expiry: Date().addingTimeInterval(3600)),
      productIds[2]: IntroOfferToken(token: "token3", expiry: Date().addingTimeInterval(3600))
    ]
    network.getIntroOfferTokenResult = .success(tokens)

    // When
    await manager.fetchTokens(
      introOfferEligibility: .eligible,
      paywallId: "test_paywall",
      productIds: productIds,
      appTransactionId: "app_transaction_123"
    )

    // Then
    #expect(manager.tokens.count == 3)
    #expect(manager.getValidToken(for: productIds[0])?.token == "token1")
    #expect(manager.getValidToken(for: productIds[1])?.token == "token2")
    #expect(manager.getValidToken(for: productIds[2])?.token == "token3")
  }

  // MARK: - Token Expiry Edge Cases

  @Test
  func getValidToken_withExactlyExpiredToken_returnsNil() async {
    // Given
    let network = NetworkMock(options: SuperwallOptions(), factory: DependencyContainer())
    let manager = IntroOfferTokenManager(network: network)

    let productId = "com.example.product"
    let now = Date()
    let token = IntroOfferToken(
      token: "token1",
      expiry: now // Exactly now
    )
    network.getIntroOfferTokenResult = .success([productId: token])

    await manager.fetchTokens(
      introOfferEligibility: .eligible,
      paywallId: "test_paywall",
      productIds: [productId],
      appTransactionId: "app_transaction_123"
    )

    // Small delay to ensure expiry has passed
    try? await Task.sleep(nanoseconds: 1_000_000) // 0.001 seconds

    // When
    let validToken = manager.getValidToken(for: productId)

    // Then
    #expect(validToken == nil)
  }
}
