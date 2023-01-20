//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/12/2022.
//


import XCTest
@testable import SuperwallKit
import Combine

final class LogPresentationOperatorTests: XCTestCase {
  var cancellables: [AnyCancellable] = []

  func test_debugInfo() async {
    let expectation = expectation(description: "Got identity")

    CurrentValueSubject(PresentationRequest
      .stub()
      .setting(\.injections.logger, to: LoggerMock.self))
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .logPresentation("Test")
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { value in
          XCTAssertTrue(LoggerMock.debugCalled)
          expectation.fulfill()
        }
      )
      .store(in: &cancellables)

    wait(for: [expectation], timeout: 0.1)
  }
}
