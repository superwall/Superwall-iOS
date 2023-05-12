//
//  File.swift
//  
//
//  Created by Yusuf Tör on 20/01/2023.
//
// swiftlint:disable all

import XCTest
@testable import SuperwallKit
import Combine

final class CheckForPaywallResultTests: XCTestCase {
  var cancellables: [AnyCancellable] = []
  let dependencyContainer = DependencyContainer()

  func test_checkForPaywallResult_eventNotFound() {
    do {
      let output = try Superwall.shared.checkForPaywallResult(triggerResult: .eventNotFound, debugInfo: [:])
      XCTFail("Should throw")
    } catch {
      guard let error = error as? PresentationPipelineError,
        case .eventNotFound = error else {
        return XCTFail("Wrong type of error")
      }
    }
  }

  func test_checkForPaywallResult_noRuleMatch() {
    do {
      let output = try Superwall.shared.checkForPaywallResult(triggerResult: .noRuleMatch, debugInfo: [:])
      XCTFail("Should throw")
    } catch {
      guard let error = error as? PresentationPipelineError,
        case .noRuleMatch = error else {
        return XCTFail("Wrong type of error")
      }
    }
  }

  func test_checkForPaywallResult_holdout() async {
    do {
      let output = try Superwall.shared.checkForPaywallResult(triggerResult: .holdout(.stub()), debugInfo: [:])
      XCTFail("Should throw")
    } catch {
      guard let error = error as? PresentationPipelineError,
        case .holdout = error else {
        return XCTFail("Wrong type of error")
      }
    }
  }

  func test_checkForPaywallResult_error() async {
    do {
      let myError = NSError(domain: "a", code: 1)
      let output = try Superwall.shared.checkForPaywallResult(triggerResult: .error(myError), debugInfo: [:])
      XCTFail("Should throw")
    } catch {
      guard let error = error as? PresentationPipelineError,
        case .noPaywallViewController = error else {
        return XCTFail("Wrong type of error")
      }
    }
  }

  func test_checkForPaywallResult_paywall() {
    let request: PresentationRequest = .stub()
    let experiment: Experiment = .stub()
    let triggerResult: TriggerResult = .paywall(experiment)
    let debugInfo = ["test": true]
    let assignmentPipelineOutput = AssignmentPipelineOutput(
      triggerResult: triggerResult,
      debugInfo: debugInfo)

    do {
      let myError = NSError(domain: "a", code: 1)
      let result = try Superwall.shared.checkForPaywallResult(
        triggerResult: .paywall(experiment),
        debugInfo: ["test": true]
      )
      XCTAssertEqual(result.experiment, experiment)
      XCTAssertNil(result.confirmableAssignment)
      XCTAssertEqual(result.triggerResult, triggerResult)
      XCTAssertEqual(result.debugInfo["test"] as! Bool, true)
    } catch {
      XCTFail("Shouldn't throw")
    }
  }
}
