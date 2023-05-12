//
//  File.swift
//  
//
//  Created by Yusuf Tör on 05/12/2022.
//

import XCTest
@testable import SuperwallKit
import Combine

final class CheckDebuggerPresentationTests: XCTestCase {
  var cancellables: [AnyCancellable] = []

  func test_checkDebuggerPresentation_debuggerNotLaunched() {
    let request = PresentationRequest.stub()
      .setting(\.flags.isDebuggerLaunched, to: false)

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.isInverted = true
    statePublisher.sink { state in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)

    do {
      try Superwall.shared.checkDebuggerPresentation(request, statePublisher)
    } catch {
      XCTFail("Shouldn't have thrown")
    }

    wait(for: [stateExpectation], timeout: 0.1)
  }

  func test_checkDebuggerPresentation_debuggerLaunched_presentingOnDebugger() async {
    let dependencyContainer = DependencyContainer()
    let debugViewController = await dependencyContainer.makeDebugViewController(withDatabaseId: "abc")
    let request = PresentationRequest.stub()
      .setting(\.flags.isDebuggerLaunched, to: true)
      .setting(\.presenter, to: debugViewController)

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    stateExpectation.isInverted = true
    statePublisher.sink { state in
      stateExpectation.fulfill()
    }
    .store(in: &cancellables)

    do {
      try Superwall.shared.checkDebuggerPresentation(request, statePublisher)
    } catch {
      XCTFail("Shouldn't have thrown")
    }

    await fulfillment(of: [stateExpectation], timeout: 0.1)
  }

  func test_checkDebuggerPresentation_debuggerLaunched_notPresentingOnDebugger() {
    let request = PresentationRequest.stub()
      .setting(\.flags.isDebuggerLaunched, to: true)
      .setting(\.presenter, to: nil)

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    let stateExpectation = expectation(description: "Output a state")
    statePublisher.sink { state in
      switch state {
      case .presentationError(let error):
        if (error as NSError).code == 101 {
          stateExpectation.fulfill()
        }
      default:
        break
      }
    }
    .store(in: &cancellables)

    let debuggerPresentation = expectation(description: "Output a state")
    do {
      try Superwall.shared.checkDebuggerPresentation(request, statePublisher)
      XCTFail("Should have thrown")
    } catch {
      debuggerPresentation.fulfill()
    }

    wait(for: [debuggerPresentation, stateExpectation], timeout: 0.1)
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
    let debugger = await DebugViewController()
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
