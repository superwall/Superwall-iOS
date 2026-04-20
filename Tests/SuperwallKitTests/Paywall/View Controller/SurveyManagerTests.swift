//
//  SurveyManagerTests.swift
//
//
//  Created by Yusuf Tör on 31/07/2023.
//

import Testing

@testable import SuperwallKit

@MainActor
struct SurveyManagerTests {
  @Test
  func presentSurveyIfAvailable_paywallDeclined_purchaseSurvey() async {
    let surveys = [
      Survey.stub()
        .setting(\.presentationCondition, to: .onPurchase)
    ]
    let dependencyContainer = DependencyContainer()

    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = SWWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: webView,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: nil,
      paywallArchiveManager: nil
    )

    await confirmation { completed in
      SurveyManager.presentSurveyIfAvailable(
        surveys,
        paywallResult: .declined,
        paywallCloseReason: .manualClose,
        using: paywallVc,
        loadingState: .ready,
        isDebuggerLaunched: false,
        paywallInfo: .stub(),
        storage: StorageMock(),
        factory: dependencyContainer,
        completion: { result in
          #expect(result == .noShow)
          completed()
        }
      )
    }
  }

  @Test
  func presentSurveyIfAvailable_surveyNil() async {
    let dependencyContainer = DependencyContainer()

    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = SWWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: webView,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: nil,
      paywallArchiveManager: nil
    )

    await confirmation { completed in
      SurveyManager.presentSurveyIfAvailable(
        [],
        paywallResult: .declined,
        paywallCloseReason: .manualClose,
        using: paywallVc,
        loadingState: .ready,
        isDebuggerLaunched: false,
        paywallInfo: .stub(),
        storage: StorageMock(),
        factory: dependencyContainer,
        completion: { result in
          #expect(result == .noShow)
          completed()
        }
      )
    }
  }

  @Test
  func presentSurveyIfAvailable_loadingState_loadingPurchase() async {
    let dependencyContainer = DependencyContainer()

    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = SWWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: webView,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: nil,
      paywallArchiveManager: nil
    )

    await confirmation(expectedCount: 0) { completed in
      SurveyManager.presentSurveyIfAvailable(
        [.stub().setting(\.presentationCondition, to: .onPurchase)],
        paywallResult: .purchased(StoreProduct(sk1Product: MockSkProduct())),
        paywallCloseReason: .systemLogic,
        using: paywallVc,
        loadingState: .loadingPurchase,
        isDebuggerLaunched: false,
        paywallInfo: .stub(),
        storage: StorageMock(),
        factory: dependencyContainer,
        completion: { result in
          #expect(result == .show)
          completed()
        }
      )
      try? await Task.sleep(nanoseconds: 200_000_000)
    }
  }

  @Test
  func presentSurveyIfAvailable_loadingState_loadingURL() async {
    let dependencyContainer = DependencyContainer()

    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = SWWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: webView,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: nil,
      paywallArchiveManager: nil
    )

    await confirmation { completed in
      SurveyManager.presentSurveyIfAvailable(
        [.stub().setting(\.presentationCondition, to: .onManualClose)],
        paywallResult: .declined,
        paywallCloseReason: .manualClose,
        using: paywallVc,
        loadingState: .loadingURL,
        isDebuggerLaunched: false,
        paywallInfo: .stub(),
        storage: StorageMock(),
        factory: dependencyContainer,
        completion: { result in
          #expect(result == .noShow)
          completed()
        }
      )
    }
  }

  @Test
  func presentSurveyIfAvailable_loadingState_manualLoading() async {
    let dependencyContainer = DependencyContainer()

    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = SWWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: webView,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: nil,
      paywallArchiveManager: nil
    )

    await confirmation { completed in
      SurveyManager.presentSurveyIfAvailable(
        [.stub().setting(\.presentationCondition, to: .onManualClose)],
        paywallResult: .declined,
        paywallCloseReason: .manualClose,
        using: paywallVc,
        loadingState: .manualLoading,
        isDebuggerLaunched: false,
        paywallInfo: .stub(),
        storage: StorageMock(),
        factory: dependencyContainer,
        completion: { result in
          #expect(result == .noShow)
          completed()
        }
      )
    }
  }

  @Test
  func presentSurveyIfAvailable_loadingState_unknown() async {
    let dependencyContainer = DependencyContainer()

    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = SWWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: webView,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: nil,
      paywallArchiveManager: nil
    )

    await confirmation { completed in
      SurveyManager.presentSurveyIfAvailable(
        [.stub().setting(\.presentationCondition, to: .onManualClose)],
        paywallResult: .declined,
        paywallCloseReason: .manualClose,
        using: paywallVc,
        loadingState: .unknown,
        isDebuggerLaunched: false,
        paywallInfo: .stub(),
        storage: StorageMock(),
        factory: dependencyContainer,
        completion: { result in
          #expect(result == .noShow)
          completed()
        }
      )
    }
  }

  @Test
  func presentSurveyIfAvailable_sameAssignmentKey() async {
    let storageMock = StorageMock(internalSurveyAssignmentKey: "1")
    let surveys = [
      Survey.stub()
        .setting(\.assignmentKey, to: "1")
        .setting(\.presentationCondition, to: .onManualClose)
    ]
    let dependencyContainer = DependencyContainer()

    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = SWWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: webView,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: nil,
      paywallArchiveManager: nil
    )

    await confirmation { completed in
      SurveyManager.presentSurveyIfAvailable(
        surveys,
        paywallResult: .declined,
        paywallCloseReason: .manualClose,
        using: paywallVc,
        loadingState: .ready,
        isDebuggerLaunched: false,
        paywallInfo: .stub(),
        storage: storageMock,
        factory: dependencyContainer,
        completion: { result in
          #expect(result == .noShow)
          completed()
        }
      )
    }
    #expect(!storageMock.didSave)
  }

  @Test
  func presentSurveyIfAvailable_zeroPresentationProbability() async {
    let storageMock = StorageMock()

    let surveys = [
      Survey.stub()
        .setting(\.presentationProbability, to: 0)
        .setting(\.presentationCondition, to: .onManualClose)
    ]

    let dependencyContainer = DependencyContainer()

    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = SWWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: webView,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: nil,
      paywallArchiveManager: nil
    )

    await confirmation { completed in
      SurveyManager.presentSurveyIfAvailable(
        surveys,
        paywallResult: .declined,
        paywallCloseReason: .manualClose,
        using: paywallVc,
        loadingState: .ready,
        isDebuggerLaunched: false,
        paywallInfo: .stub(),
        storage: storageMock,
        factory: dependencyContainer,
        completion: { result in
          #expect(result == .holdout)
          completed()
        }
      )
    }
    #expect(storageMock.didSave)
  }

  @Test
  func presentSurveyIfAvailable_debuggerLaunched() async {
    let storageMock = StorageMock()

    let surveys = [Survey.stub()]

    let dependencyContainer = DependencyContainer()

    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = SWWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: webView,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: nil,
      paywallArchiveManager: nil
    )

    await confirmation(expectedCount: 0) { completed in
      SurveyManager.presentSurveyIfAvailable(
        surveys,
        paywallResult: .declined,
        paywallCloseReason: .manualClose,
        using: paywallVc,
        loadingState: .ready,
        isDebuggerLaunched: true,
        paywallInfo: .stub(),
        storage: storageMock,
        factory: dependencyContainer,
        completion: { result in
          #expect(result == .show)
          completed()
        }
      )
      try? await Task.sleep(nanoseconds: 100_000_000)
    }
    #expect(!storageMock.didSave)
  }

  @Test
  func presentSurveyIfAvailable_success() async {
    let storageMock = StorageMock()
    storageMock.reset()

    let surveys = [
      Survey.stub()
        .setting(\.presentationProbability, to: 1)
        .setting(\.presentationCondition, to: .onManualClose)
    ]

    let dependencyContainer = DependencyContainer()

    let messageHandler = PaywallMessageHandler(
      receiptManager: dependencyContainer.receiptManager,
      factory: dependencyContainer,
      permissionHandler: FakePermissionHandler(),
      customCallbackRegistry: dependencyContainer.customCallbackRegistry
    )
    let webView = SWWebView(
      isMac: false,
      messageHandler: messageHandler,
      isOnDeviceCacheEnabled: true,
      factory: dependencyContainer
    )
    let paywallVc = PaywallViewControllerMock(
      paywall: .stub(),
      deviceHelper: dependencyContainer.deviceHelper,
      factory: dependencyContainer,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      webView: webView,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      cache: nil,
      paywallArchiveManager: nil
    )

    await confirmation(expectedCount: 0) { completed in
      SurveyManager.presentSurveyIfAvailable(
        surveys,
        paywallResult: .declined,
        paywallCloseReason: .manualClose,
        using: paywallVc,
        loadingState: .ready,
        isDebuggerLaunched: false,
        paywallInfo: .stub(),
        storage: storageMock,
        factory: dependencyContainer,
        completion: { result in
          #expect(result == .show)
          completed()
        }
      )
      try? await Task.sleep(nanoseconds: 100_000_000)
    }
  }
}
