//
//  File.swift
//
//
//  Created by Yusuf Tör on 05/12/2022.
//

import Foundation
import Testing
@testable import SuperwallKit
import Combine

@Suite(.serialized)
final class CheckDebuggerPresentationTests {
  var cancellables: [AnyCancellable] = []

  @Test func checkDebuggerPresentation_debuggerNotLaunched() async {
    let request = PresentationRequest.stub()
      .setting(\.flags.isDebuggerLaunched, to: false)

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    var stateReceived = false
    statePublisher.sink { state in
      stateReceived = true
    }
    .store(in: &cancellables)

    do {
      try Superwall.shared.checkDebuggerPresentation(
        request: request,
        paywallStatePublisher: statePublisher
      )
    } catch {
      Issue.record("Shouldn't have thrown")
    }

    try? await Task.sleep(nanoseconds: 100_000_000)
    #expect(!stateReceived)
  }

  @Test func checkDebuggerPresentation_debuggerLaunched_presentingOnDebugger() async {
    let dependencyContainer = DependencyContainer()
    let debugViewController = await dependencyContainer.makeDebugViewController(withDatabaseId: "abc")
    let request = PresentationRequest.stub()
      .setting(\.flags.isDebuggerLaunched, to: true)
      .setting(\.presenter, to: debugViewController)

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    var stateReceived = false
    statePublisher.sink { state in
      stateReceived = true
    }
    .store(in: &cancellables)

    do {
      try Superwall.shared.checkDebuggerPresentation(
        request: request,
        paywallStatePublisher: statePublisher
      )
    } catch {
      Issue.record("Shouldn't have thrown")
    }

    try? await Task.sleep(nanoseconds: 100_000_000)
    #expect(!stateReceived)
  }

  @Test func checkDebuggerPresentation_debuggerLaunched_notPresentingOnDebugger() async {
    let request = PresentationRequest.stub()
      .setting(\.flags.isDebuggerLaunched, to: true)
      .setting(\.presenter, to: nil)

    let statePublisher = PassthroughSubject<PaywallState, Never>()
    var stateReceived = false
    var receivedErrorCode: Int?
    statePublisher.sink { state in
      switch state {
      case .presentationError(let error):
        stateReceived = true
        receivedErrorCode = (error as NSError).code
      default:
        break
      }
    }
    .store(in: &cancellables)

    var didThrow = false
    do {
      try Superwall.shared.checkDebuggerPresentation(
        request: request,
        paywallStatePublisher: statePublisher
      )
      Issue.record("Should have thrown")
    } catch {
      didThrow = true
    }

    try? await Task.sleep(nanoseconds: 100_000_000)
    #expect(didThrow)
    #expect(stateReceived)
    #expect(receivedErrorCode == 101)
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
