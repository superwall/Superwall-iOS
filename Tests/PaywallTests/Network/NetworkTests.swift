//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/06/2022.
//
// swiftlint:disable all

import XCTest
@testable import Paywall

@available(iOS 14.0, *)
final class NetworkTests: XCTestCase {
  // MARK: - Config
  func test_config_inBackground() {
    onMain {
      let urlSession = CustomURLSessionMock()
      let network = Network(urlSession: urlSession)
      let configManager = ConfigManager()
      let requestId = "abc"
      let completion: (Result<Config, Error>) -> Void = { _ in
        XCTFail("Config went ahead in background")
      }
      network.getConfig(
        withRequestId: requestId,
        completion: completion,
        applicationState: .background,
        configManager: configManager
      )
      XCTAssertFalse(urlSession.didRequest)

      let configRequest = ConfigRequest(
        id: requestId,
        completion: completion
      )
      XCTAssertEqual(configManager.configRequest, configRequest)
    }
  }

  func test_config_inForeground() {
    onMain {
      let urlSession = CustomURLSessionMock()
      let network = Network(urlSession: urlSession)
      let configManager = ConfigManager()
      let requestId = "abc"
      let completion: (Result<Config, Error>) -> Void = { _ in }
      network.getConfig(
        withRequestId: requestId,
        completion: completion,
        applicationState: .active,
        configManager: configManager
      )
      XCTAssertTrue(urlSession.didRequest)
      XCTAssertNil(configManager.configRequest)
    }
  }
}
