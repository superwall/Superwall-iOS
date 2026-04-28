//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/05/2022.
//

import UIKit
import Combine
@testable import SuperwallKit

final class NetworkMock: Network {
  var sentSessionEvents: SessionEventsRequest?
  var getConfigCalled = false
  var assignmentsConfirmed = false
  var assignments: [PostbackAssignment] = []
  var configReturnValue: Result<Config, Error> = .success(.stub())
  var getWebEntitlementsResponse: RedeemResponse?
  var getEntitlementsResponse: EntitlementsResponse?
  var redeemError: Error?
  var redeemRequest: RedeemRequest?
  var pollRedemptionResultRequest: PollRedemptionResultRequest?
  var pollRedemptionResultResponses: [Result<RedeemResponse, Error>] = []
  var getIntroOfferTokenResult: Result<[String: IntroOfferToken], Error>?
  var getIntroOfferTokenCallCount = 0
  var redeemDelay: TimeInterval = 0
  var redeemCallCount = 0
  var pollRedemptionResultCallCount = 0
  var onRedeemEntitlements: (() -> Void)?
  var onPollRedemptionResult: (() -> Void)?

  override func sendSessionEvents(_ session: SessionEventsRequest) async {
    sentSessionEvents = session
  }

  @MainActor
  override func getConfig(
    injectedApplicationStatePublisher: (AnyPublisher<UIApplication.State, Never>)? = nil,
    maxRetry: Int? = nil,
    isRetryingCallback: ((Int) -> Void)? = nil,
    timeout: Seconds? = nil
  ) async throws -> Config {
    getConfigCalled = true

    switch configReturnValue {
    case .success(let success):
      return success
    case .failure(let failure):
      throw failure
    }
  }

  override func confirmAssignment(_ assignment: Assignment) async -> Assignment {
    assignmentsConfirmed = true
    assignment.markAsSent()
    return assignment
  }

  override func getAssignments() async throws -> [PostbackAssignment] {
    return assignments
  }

  override func redeemEntitlements(request: RedeemRequest) async throws -> RedeemResponse {
    redeemRequest = request
    redeemCallCount += 1
    onRedeemEntitlements?()

    if redeemDelay > 0 {
      try? await Task.sleep(nanoseconds: UInt64(redeemDelay * 1_000_000_000))
    }

    if let getWebEntitlementsResponse = getWebEntitlementsResponse {
      return getWebEntitlementsResponse
    } else if let redeemError = redeemError {
      throw redeemError
    }
    throw NetworkError.unknown
  }

  override func getEntitlements(
    appUserId: String?,
    deviceId: String
  ) async throws -> EntitlementsResponse {
    if let getEntitlementsResponse = getEntitlementsResponse {
      return getEntitlementsResponse
    } else if let redeemError = redeemError {
      throw redeemError
    }
    throw NetworkError.unknown
  }

  override func pollRedemptionResult(request: PollRedemptionResultRequest) async throws -> RedeemResponse {
    pollRedemptionResultRequest = request
    pollRedemptionResultCallCount += 1
    onPollRedemptionResult?()

    if !pollRedemptionResultResponses.isEmpty {
      let result = pollRedemptionResultResponses.removeFirst()
      switch result {
      case .success(let response):
        return response
      case .failure(let error):
        throw error
      }
    }

    if let getWebEntitlementsResponse {
      return getWebEntitlementsResponse
    }
    if let redeemError {
      throw redeemError
    }
    throw NetworkError.unknown
  }

  override func getIntroOfferToken(
    productIds: [String],
    appTransactionId: String,
    allowIntroductoryOffer: Bool
  ) async throws -> [String: IntroOfferToken] {
    getIntroOfferTokenCallCount += 1
    if let result = getIntroOfferTokenResult {
      switch result {
      case .success(let tokens):
        return tokens
      case .failure(let error):
        throw error
      }
    }
    throw NetworkError.unknown
  }
}
