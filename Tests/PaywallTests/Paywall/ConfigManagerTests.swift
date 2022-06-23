//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/06/2022.
//
// swiftlint:disable all

@testable import Paywall
import XCTest

@available(iOS 14.0, *)
final class ConfigManagerTests: XCTestCase {
  func test_backgroundToForeground_noConfig() {
    let storage = StorageMock()
    let network = NetworkMock()
    let configManager = ConfigManager(
      storage: storage,
      network: network
    )
    
    NotificationCenter.default.post(
      Notification(name: UIApplication.didBecomeActiveNotification)
    )
    XCTAssertFalse(network.getConfigCalled)
  }

  func test_backgroundToForeground_storedConfig() {
    let configRequest = ConfigRequest(
      id: "abc",
      completion: { _ in }
    )
    let storage = StorageMock()
    storage.configRequest = configRequest
    let network = NetworkMock()

    let configManager = ConfigManager(
      storage: storage,
      network: network
    )

    NotificationCenter.default.post(
      Notification(name: UIApplication.didBecomeActiveNotification)
    )
    XCTAssertTrue(network.getConfigCalled)
  }
}
