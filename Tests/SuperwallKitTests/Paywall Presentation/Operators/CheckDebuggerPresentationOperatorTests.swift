//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/12/2022.
//

import XCTest
@testable import SuperwallKit
import Combine

final class CheckDebuggerPresentationOperatorTests: XCTestCase {
  var cancellables: [AnyCancellable] = []

  func test_checkDebuggerPresentation_debuggerNotLaunched() async {
    let request = PresentationRequest.stub()
      .setting(\.injections.isDebuggerLaunched, to: false)
    
    let debugInfo: [String: Any] = [:]

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.isInverted = true
    statePublisher.sink { state in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)

    let continuePipelineExpectation = expectation(description: "Continued Pipeline")
    CurrentValueSubject((request, debugInfo))
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .checkDebuggerPresentation(statePublisher)
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { output in
          continuePipelineExpectation.fulfill()
        }
      )
      .store(in: &cancellables)

    wait(for: [continuePipelineExpectation, stateExpectation], timeout: 0.1)
  }

  func test_checkDebuggerPresentation_debuggerLaunched_presentingOnDebugger() async {
    let request = PresentationRequest.stub()
      .setting(\.injections.isDebuggerLaunched, to: true)
      .setting(\.presentingViewController, to: await SWDebugViewController())

    let debugInfo: [String: Any] = [:]

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.isInverted = true
    statePublisher.sink { state in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)

    let continuePipelineExpectation = expectation(description: "Continued Pipeline")
    CurrentValueSubject((request, debugInfo))
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .checkDebuggerPresentation(statePublisher)
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { output in
          continuePipelineExpectation.fulfill()
        }
      )
      .store(in: &cancellables)

    wait(for: [continuePipelineExpectation, stateExpectation], timeout: 0.1)
  }

  func test_checkDebuggerPresentation_debuggerLaunched_notPresentingOnDebugger() async {
    let request = PresentationRequest.stub()
      .setting(\.injections.isDebuggerLaunched, to: true)
      .setting(\.presentingViewController, to: nil)

    let debugInfo: [String: Any] = [:]

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    statePublisher.sink { state in
      switch state {
      case .skipped(let reason):
        switch reason {
        case .error(let error):
          if (error as NSError).code == 101 {
            stateExpectation.fulfill()
          }
        default:
          break
        }
      default:
        break
      }
    }
    .store(in: &cancellables)

    let continuePipelineExpectation = expectation(description: "Continued Pipeline")

    CurrentValueSubject((request, debugInfo))
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
      .checkDebuggerPresentation(statePublisher)
      .eraseToAnyPublisher()
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .failure:
            continuePipelineExpectation.fulfill()
          default:
            break
          }
        },
        receiveValue: { output in
          XCTFail()
        }
      )
      .store(in: &cancellables)

    wait(for: [continuePipelineExpectation, stateExpectation], timeout: 0.1)
  }

  /*



    let identifier = "abc"
    let request = PresentationRequest(
      presentationInfo: .fromIdentifier(identifier, freeTrialOverride: false),
      injections: .init(
        isDebuggerLaunched: true,
        isUserSubscribed: false
      )
    )

    publisher = Superwall.shared.internallyPresent(request)

    let expectation = expectation(description: "Called publisher")

    publisher.sink { state in
      switch state {
      case .skipped(let reason):
        switch reason {
        case .error(let error):
          if (error as NSError).code == 101 {
            expectation.fulfill()
          }
        default:
          break
        }
      default:
        break
      }
    }
    .store(in: &cancellables)

    IdentityManager.shared.didSetIdentity()
    await suspend()

    wait(for: [expectation], timeout: 0.1)
  }

  func test_checkDebuggerPresentation_presentingOnDebugger() async {
    let identifier = "abc"
    let debugger = await SWDebugViewController()
    let request = PresentationRequest(
      presentationInfo: .fromIdentifier(identifier, freeTrialOverride: false),
      presentingViewController: debugger,
      injections: .init(
        isDebuggerLaunched: true,
        isUserSubscribed: false
      )
    )

    publisher = Superwall.shared.internallyPresent(request)

    let expectation = expectation(description: "Called publisher")
    expectation.isInverted = true

    publisher.sink { state in
      switch state {
      case .skipped(let reason):
        switch reason {
        case .error(let error):
          if (error as NSError).code == 101 {
            expectation.fulfill()
          }
        default:
          break
        }
      default:
        break
      }
    }
    .store(in: &cancellables)

    IdentityManager.shared.didSetIdentity()
    await suspend()

    wait(for: [expectation], timeout: 0.1)
  }*/
}
