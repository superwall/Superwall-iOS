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
    let urlSession = CustomURLSessionMock()
    let network = Network(urlSession: urlSession)
    let storage = StorageMock()
    let requestId = "abc"
    let completion: (Result<Config, Error>) -> Void = { _ in
      XCTFail("Config went ahead in background")
    }
    network.getConfig(
      withRequestId: requestId,
      completion: completion,
      applicationState: .background,
      storage: storage
    )
    XCTAssertFalse(urlSession.didRequest)

    let configRequest = ConfigRequest(
      id: requestId,
      completion: completion
    )
    XCTAssertEqual(storage.configRequest, configRequest)
  }

  func test_config_inForeground() {
    let urlSession = CustomURLSessionMock()
    let network = Network(urlSession: urlSession)
    let storage = StorageMock()
    let requestId = "abc"
    let completion: (Result<Config, Error>) -> Void = { _ in }
    network.getConfig(
      withRequestId: requestId,
      completion: completion,
      applicationState: .active,
      storage: storage
    )
    XCTAssertTrue(urlSession.didRequest)
    XCTAssertNil(storage.configRequest)
  }
}
