//
//  SurveyManagerTests.swift
//  
//
//  Created by Yusuf Tör on 31/07/2023.
//

import XCTest
@testable import SuperwallKit

@available(iOS 14.0, *)
@MainActor
final class SurveyManagerTests: XCTestCase {
  func test_presentSurveyIfAvailable_paywallDeclined() {
    let survey = Survey.stub()
    let expectation = expectation(description: "called completion block")
    let dependencyContainer = DependencyContainer()

    let messageHandler = PaywallMessageHandler(
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      factory: dependencyContainer
    )
    let webView = SWWebView(
      isMac: false,
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      messageHandler: messageHandler
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      paywallManager: dependencyContainer.paywallManager,
      webView: webView,
      cache: nil
    )

    SurveyManager.presentSurveyIfAvailable(
      survey,
      using: paywallVc,
      loadingState: .ready,
      shouldShow: false,
      isDebuggerLaunched: false,
      paywallInfo: .stub(),
      storage: StorageMock(),
      factory: dependencyContainer,
      completion: { result in
        XCTAssertEqual(result, .noShow)
        expectation.fulfill()
      }
    )
    wait(for: [expectation])
  }

  func test_presentSurveyIfAvailable_surveyNil() {
    let expectation = expectation(description: "called completion block")
    let dependencyContainer = DependencyContainer()

    let messageHandler = PaywallMessageHandler(
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      factory: dependencyContainer
    )
    let webView = SWWebView(
      isMac: false,
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      messageHandler: messageHandler
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      paywallManager: dependencyContainer.paywallManager,
      webView: webView,
      cache: nil
    )

    SurveyManager.presentSurveyIfAvailable(
      nil,
      using: paywallVc,
      loadingState: .ready,
      shouldShow: true,
      isDebuggerLaunched: false,
      paywallInfo: .stub(),
      storage: StorageMock(),
      factory: dependencyContainer,
      completion: { result in
        XCTAssertEqual(result, .noShow)
        expectation.fulfill()
      }
    )
    wait(for: [expectation])
  }

  func test_presentSurveyIfAvailable_loadingState_loadingPurchase() {
    let expectation = expectation(description: "called completion block")
    expectation.isInverted = true
    let dependencyContainer = DependencyContainer()

    let messageHandler = PaywallMessageHandler(
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      factory: dependencyContainer
    )
    let webView = SWWebView(
      isMac: false,
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      messageHandler: messageHandler
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      paywallManager: dependencyContainer.paywallManager,
      webView: webView,
      cache: nil
    )

    SurveyManager.presentSurveyIfAvailable(
      .stub(),
      using: paywallVc,
      loadingState: .loadingPurchase,
      shouldShow: true,
      isDebuggerLaunched: false,
      paywallInfo: .stub(),
      storage: StorageMock(),
      factory: dependencyContainer,
      completion: { result in
        XCTAssertEqual(result, .show)
        expectation.fulfill()
      }
    )
    wait(for: [expectation], timeout: 0.2)
  }

  func test_presentSurveyIfAvailable_loadingState_loadingURL() {
    let expectation = expectation(description: "called completion block")
    let dependencyContainer = DependencyContainer()

    let messageHandler = PaywallMessageHandler(
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      factory: dependencyContainer
    )
    let webView = SWWebView(
      isMac: false,
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      messageHandler: messageHandler
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      paywallManager: dependencyContainer.paywallManager,
      webView: webView,
      cache: nil
    )

    SurveyManager.presentSurveyIfAvailable(
      .stub(),
      using: paywallVc,
      loadingState: .loadingURL,
      shouldShow: true,
      isDebuggerLaunched: false,
      paywallInfo: .stub(),
      storage: StorageMock(),
      factory: dependencyContainer,
      completion: { result in
        XCTAssertEqual(result, .noShow)
        expectation.fulfill()
      }
    )
    wait(for: [expectation])
  }

  func test_presentSurveyIfAvailable_loadingState_manualLoading() {
    let expectation = expectation(description: "called completion block")
    let dependencyContainer = DependencyContainer()

    let messageHandler = PaywallMessageHandler(
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      factory: dependencyContainer
    )
    let webView = SWWebView(
      isMac: false,
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      messageHandler: messageHandler
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      paywallManager: dependencyContainer.paywallManager,
      webView: webView,
      cache: nil
    )

    SurveyManager.presentSurveyIfAvailable(
      .stub(),
      using: paywallVc,
      loadingState: .manualLoading,
      shouldShow: true,
      isDebuggerLaunched: false,
      paywallInfo: .stub(),
      storage: StorageMock(),
      factory: dependencyContainer,
      completion: { result in
        XCTAssertEqual(result, .noShow)
        expectation.fulfill()
      }
    )
    wait(for: [expectation])
  }

  func test_presentSurveyIfAvailable_loadingState_unknown() {
    let expectation = expectation(description: "called completion block")
    let dependencyContainer = DependencyContainer()

    let messageHandler = PaywallMessageHandler(
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      factory: dependencyContainer
    )
    let webView = SWWebView(
      isMac: false,
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      messageHandler: messageHandler
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      paywallManager: dependencyContainer.paywallManager,
      webView: webView,
      cache: nil
    )

    SurveyManager.presentSurveyIfAvailable(
      .stub(),
      using: paywallVc,
      loadingState: .unknown,
      shouldShow: true,
      isDebuggerLaunched: false,
      paywallInfo: .stub(),
      storage: StorageMock(),
      factory: dependencyContainer,
      completion: { result in
        XCTAssertEqual(result, .noShow)
        expectation.fulfill()
      }
    )
    wait(for: [expectation])
  }

  func test_presentSurveyIfAvailable_sameAssignmentKey() {
    let storageMock = StorageMock(internalSurveyAssignmentKey: "1")
    let survey = Survey.stub()
      .setting(\.assignmentKey, to: "1")

    let expectation = expectation(description: "called completion block")
    let dependencyContainer = DependencyContainer()

    let messageHandler = PaywallMessageHandler(
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      factory: dependencyContainer
    )
    let webView = SWWebView(
      isMac: false,
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      messageHandler: messageHandler
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      paywallManager: dependencyContainer.paywallManager,
      webView: webView,
      cache: nil
    )

    SurveyManager.presentSurveyIfAvailable(
      survey,
      using: paywallVc,
      loadingState: .ready,
      shouldShow: true,
      isDebuggerLaunched: false,
      paywallInfo: .stub(),
      storage: storageMock,
      factory: dependencyContainer,
      completion: { result in
        XCTAssertEqual(result, .noShow)
        expectation.fulfill()
      }
    )
    wait(for: [expectation], timeout: 0.2)
    XCTAssertFalse(storageMock.didSave)
  }

  func test_presentSurveyIfAvailable_zeroPresentationProbability() {
    let storageMock = StorageMock()

    let survey = Survey.stub()
      .setting(\.presentationProbability, to: 0)

    let expectation = expectation(description: "called completion block")
    let dependencyContainer = DependencyContainer()

    let messageHandler = PaywallMessageHandler(
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      factory: dependencyContainer
    )
    let webView = SWWebView(
      isMac: false,
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      messageHandler: messageHandler
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      paywallManager: dependencyContainer.paywallManager,
      webView: webView,
      cache: nil
    )


    SurveyManager.presentSurveyIfAvailable(
      survey,
      using: paywallVc,
      loadingState: .ready,
      shouldShow: true,
      isDebuggerLaunched: false,
      paywallInfo: .stub(),
      storage: storageMock,
      factory: dependencyContainer,
      completion: { result in
        XCTAssertEqual(result, .holdout)
        expectation.fulfill()
      }
    )
    wait(for: [expectation])
    XCTAssertTrue(storageMock.didSave)
  }

  func test_presentSurveyIfAvailable_debuggerLaunched() {
    let storageMock = StorageMock()

    let survey = Survey.stub()

    let expectation = expectation(description: "called completion block")
    expectation.isInverted = true
    let dependencyContainer = DependencyContainer()

    let messageHandler = PaywallMessageHandler(
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      factory: dependencyContainer
    )
    let webView = SWWebView(
      isMac: false,
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      messageHandler: messageHandler
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      paywallManager: dependencyContainer.paywallManager,
      webView: webView,
      cache: nil
    )

    SurveyManager.presentSurveyIfAvailable(
      survey,
      using: paywallVc,
      loadingState: .ready,
      shouldShow: true,
      isDebuggerLaunched: true,
      paywallInfo: .stub(),
      storage: storageMock,
      factory: dependencyContainer,
      completion: { result in
        XCTAssertEqual(result, .show)
        expectation.fulfill()
      }
    )
    wait(for: [expectation], timeout: 0.1)
    XCTAssertFalse(storageMock.didSave)
  }

  func test_presentSurveyIfAvailable_success() {
    let storageMock = StorageMock()
    storageMock.reset()

    let survey = Survey.stub()
      .setting(\.presentationProbability, to: 1)

    let expectation = expectation(description: "called completion block")
    expectation.isInverted = true
    let dependencyContainer = DependencyContainer()

    let messageHandler = PaywallMessageHandler(
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      factory: dependencyContainer
    )
    let webView = SWWebView(
      isMac: false,
      sessionEventsManager: dependencyContainer.sessionEventsManager,
      messageHandler: messageHandler
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      paywallManager: dependencyContainer.paywallManager,
      webView: webView,
      cache: nil
    )

    SurveyManager.presentSurveyIfAvailable(
      survey,
      using: paywallVc,
      loadingState: .ready,
      shouldShow: true,
      isDebuggerLaunched: false,
      paywallInfo: .stub(),
      storage: storageMock,
      factory: dependencyContainer,
      completion: { result in
        XCTAssertEqual(result, .show)
        expectation.fulfill()
      }
    )
    wait(for: [expectation], timeout: 0.1)
  }
}
