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
  var redeemEntitlementsResponse: RedeemResponse?
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
    if let redeemEntitlementsResponse = redeemEntitlementsResponse {
      return redeemEntitlementsResponse
    } else if let redeemError = redeemError {
      throw redeemError
    }
    throw NetworkError.unknown
  }
}
