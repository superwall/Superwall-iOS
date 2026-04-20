//
//  File.swift
//
//
//  Created by Yusuf Tör on 06/12/2022.
//

import Combine
import UIKit
import Testing

@testable import SuperwallKit

@Suite(.serialized)
final class PresentPaywallOperatorTests {
  var cancellables: [AnyCancellable] = []

  @Test
  @MainActor
  func presentPaywall_isPresented() async {
    let statePublisher = PassthroughSubject<PaywallState, Never>()

    await confirmation { confirm in
      statePublisher.sink { completion in
        Issue.record()
      } receiveValue: { state in
        switch state {
        case .presented:
          confirm()
        default:
          break
        }
      }
      .store(in: &cancellables)
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

      webView.delegate = paywallVc
      messageHandler.delegate = paywallVc

      paywallVc.shouldPresent = true

      do {
        _ = try await Superwall.shared.presentPaywallViewController(
          paywallVc,
          on: UIViewController(),
          unsavedOccurrence: nil,
          debugInfo: [:],
          request: .stub(),
          paywallStatePublisher: statePublisher
        )
      } catch {
        Issue.record("Shouldn't fail")
      }
    }
  }

  @Test
  @MainActor
  func presentPaywall_isNotPresented() async {
    let statePublisher = PassthroughSubject<PaywallState, Never>()

    await confirmation(expectedCount: 2) { confirm in
      statePublisher.sink { completion in
        switch completion {
        case .finished:
          confirm()
        default:
          break
        }
      } receiveValue: { state in
        switch state {
        case .presentationError:
          confirm()
        default:
          break
        }
      }
      .store(in: &cancellables)

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
      paywallVc.shouldPresent = false
      webView.delegate = paywallVc
      messageHandler.delegate = paywallVc

      do {
        _ = try await Superwall.shared.presentPaywallViewController(
          paywallVc,
          on: UIViewController(),
          unsavedOccurrence: nil,
          debugInfo: [:],
          request: .stub(),
          paywallStatePublisher: statePublisher
        )
        Issue.record("Should fail")
      } catch {
        if let error = error as? PresentationPipelineError,
          case .paywallAlreadyPresented = error
        {

        } else {
          Issue.record("Wrong error type")
        }
      }
    }
  }
}
