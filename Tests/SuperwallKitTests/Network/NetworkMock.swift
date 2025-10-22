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
}
