//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/05/2022.
//

import UIKit
@testable import Paywall

final class NetworkMock: Network {
  var sentSessionEvents: SessionEventsRequest?
  var getConfigCalled = false
  var assignmentsConfirmed = false
  var assignments: [Assignment] = []
  var configReturnValue: Result<Config, Error> = .success(.stub())

  override func sendSessionEvents(_ session: SessionEventsRequest) {
    sentSessionEvents = session
  }

  override func getConfig(
    withRequestId requestId: String,
    completion: @escaping (Result<Config, Error>) -> Void,
    applicationState: UIApplication.State? = UIApplication.shared.applicationState,
    configManager: ConfigManager = .shared
  ) {
    getConfigCalled = true
    completion(configReturnValue)
  }

  override func confirmAssignments(_ confirmableAssignments: ConfirmableAssignments) {
    assignmentsConfirmed = true
  }

  override func getAssignments(completion: @escaping (Result<[Assignment], Error>) -> Void) {
    completion(.success(assignments))
  }
}
