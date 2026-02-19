//
//  File.swift
//
//
//  Created by Yusuf Tör on 06/12/2022.
//

import Testing
@testable import SuperwallKit
import Combine

@Suite(.serialized)
struct ConfirmPaywallAssignmentOperatorTests {
  @Test @MainActor
  func confirmPaywallAssignment_debuggerLaunched() async {
    let dependencyContainer = DependencyContainer()
    let configManager = ConfigManagerMock(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer
    )
    try? await Task.sleep(nanoseconds: 10_000_000)
    dependencyContainer.configManager = configManager

    let request = PresentationRequest.stub()
      .setting(\.flags.type, to: .presentation)
     Superwall.shared.confirmPaywallAssignment(
      Assignment(experimentId: "", variant: .init(id: "", type: .treatment, paywallId: ""), isSentToServer: false), request: request,
      isDebuggerLaunched: true,
      dependencyContainer: dependencyContainer
     )
    #expect(!configManager.confirmedAssignment)
  }

  @Test @MainActor
  func confirmPaywallAssignment_noAssignment() async {
    let dependencyContainer = DependencyContainer()
    let configManager = ConfigManagerMock(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer
    )
    try? await Task.sleep(nanoseconds: 10_000_000)
    dependencyContainer.configManager = configManager

    let request = PresentationRequest.stub()
      .setting(\.flags.type, to: .presentation)
     Superwall.shared.confirmPaywallAssignment(
      nil,
      request: request,
      isDebuggerLaunched: false,
      dependencyContainer: dependencyContainer
     )
    #expect(!configManager.confirmedAssignment)
  }

  @Test @MainActor
  func confirmPaywallAssignment_confirmAssignment() async {
    let dependencyContainer = DependencyContainer()
    let configManager = ConfigManagerMock(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer
    )
    try? await Task.sleep(nanoseconds: 10_000_000)
    dependencyContainer.configManager = configManager

    let request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      isDebuggerLaunched: false,
      isPaywallPresented: false,
      type: .getPaywall(.stub())
    )

    Superwall.shared.confirmPaywallAssignment(
      Assignment(experimentId: "", variant: .init(id: "", type: .treatment, paywallId: ""), isSentToServer: false),
      request: request,
      isDebuggerLaunched: false,
      dependencyContainer: dependencyContainer
     )
   #expect(configManager.confirmedAssignment)
  }

  @Test @MainActor
  func confirmPaywallAssignment_confirmAssignment_isSentToServer() async {
    let dependencyContainer = DependencyContainer()
    let configManager = ConfigManagerMock(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer
    )
    try? await Task.sleep(nanoseconds: 10_000_000)
    dependencyContainer.configManager = configManager

    let request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      isDebuggerLaunched: false,
      isPaywallPresented: false,
      type: .getPaywall(.stub())
    )

    Superwall.shared.confirmPaywallAssignment(
      Assignment(experimentId: "", variant: .init(id: "", type: .treatment, paywallId: ""), isSentToServer: true),
      request: request,
      isDebuggerLaunched: false,
      dependencyContainer: dependencyContainer
     )
   #expect(!configManager.confirmedAssignment)
  }

  @Test @MainActor
  func confirmPaywallAssignment_getPresentationResult() async {
    let dependencyContainer = DependencyContainer()
    let configManager = ConfigManagerMock(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer
    )
    try? await Task.sleep(nanoseconds: 10_000_000)
    dependencyContainer.configManager = configManager

    let request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      isDebuggerLaunched: false,
      isPaywallPresented: false,
      type: .getPresentationResult
    )

    Superwall.shared.confirmPaywallAssignment(
      Assignment(experimentId: "", variant: .init(id: "", type: .treatment, paywallId: ""), isSentToServer: false),
      request: request,
      isDebuggerLaunched: false,
      dependencyContainer: dependencyContainer
     )
   #expect(configManager.confirmedAssignment)
  }

  @Test @MainActor
  func confirmPaywallAssignment_handleImplicitTrigger() async {
    let dependencyContainer = DependencyContainer()
    let configManager = ConfigManagerMock(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer
    )
    try? await Task.sleep(nanoseconds: 10_000_000)
    dependencyContainer.configManager = configManager

    let request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      isDebuggerLaunched: false,
      isPaywallPresented: false,
      type: .handleImplicitTrigger
    )

    Superwall.shared.confirmPaywallAssignment(
      Assignment(experimentId: "", variant: .init(id: "", type: .treatment, paywallId: ""), isSentToServer: false),
      request: request,
      isDebuggerLaunched: false,
      dependencyContainer: dependencyContainer
     )
    #expect(configManager.confirmedAssignment)
  }

  @Test @MainActor
  func confirmPaywallAssignment_paywallDeclineCheck() async {
    let dependencyContainer = DependencyContainer()
    let configManager = ConfigManagerMock(
      options: SuperwallOptions(),
      storeKitManager: dependencyContainer.storeKitManager,
      storage: dependencyContainer.storage,
      network: dependencyContainer.network,
      paywallManager: dependencyContainer.paywallManager,
      deviceHelper: dependencyContainer.deviceHelper,
      entitlementsInfo: dependencyContainer.entitlementsInfo,
      webEntitlementRedeemer: dependencyContainer.webEntitlementRedeemer,
      factory: dependencyContainer
    )
    try? await Task.sleep(nanoseconds: 10_000_000)
    dependencyContainer.configManager = configManager

    let request = dependencyContainer.makePresentationRequest(
      .explicitTrigger(.stub()),
      isDebuggerLaunched: false,
      isPaywallPresented: false,
      type: .paywallDeclineCheck
    )

    Superwall.shared.confirmPaywallAssignment(
      Assignment(experimentId: "", variant: .init(id: "", type: .treatment, paywallId: ""), isSentToServer: false),
      request: request,
      isDebuggerLaunched: false,
      dependencyContainer: dependencyContainer
     )
    #expect(!configManager.confirmedAssignment)
  }
}
