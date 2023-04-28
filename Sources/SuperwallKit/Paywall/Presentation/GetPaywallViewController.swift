//
//  File.swift
//
//
//  Created by Jake Mor on 10/9/21.
//
// swiftlint:disable line_length file_length function_body_length

import Foundation
import Combine
import UIKit

extension Superwall {

  public func getPaywall(
      forEvent: String,
      params: [String: Any]? = nil,
      paywallOverrides: PaywallOverrides? = nil
    ) async throws -> PaywallViewController {

    return try await withCheckedThrowingContinuation { continuation in
      getPaywall(forEvent: forEvent, params: params, paywallOverrides: paywallOverrides) { paywallViewController, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let paywallViewController = paywallViewController {
          continuation.resume(returning: paywallViewController)
        } else {
          continuation.resume(throwing: PresentationPipelineError.unknown)
        }
      }
    }
  }

  public func getPaywall(
    forEvent: String,
    params: [String: Any]? = nil,
    paywallOverrides: PaywallOverrides? = nil,
    completion: @escaping (PaywallViewController?, Error?) -> Void
  ) {

    let trackableEvent = UserInitiatedEvent.Track(
      rawName: forEvent,
      canImplicitlyTriggerPaywall: false,
      customParameters: params ?? [:],
      isFeatureGatable: false
    )

    Task {
      let trackResult = await self.track(trackableEvent)

      let presentationRequest = self.dependencyContainer.makePresentationRequest(
        .explicitTrigger(trackResult.data),
        paywallOverrides: paywallOverrides,
        isPaywallPresented: false
      )

      let paywallStatePublisher: PassthroughSubject<PaywallState, Never> = .init()

      let presentablePublisher = self.internallyGetPaywallViewController(presentationRequest, paywallStatePublisher)

      presentablePublisher.subscribe(Subscribers.Sink(
        receiveCompletion: { done in
          switch done {
            case .failure(let error):
              completion(nil, error)
            default:
              break
          }
        },
        receiveValue: { @MainActor state in

          let paywall = state.paywallViewController
          paywall.set(eventData: trackResult.data, presentationStyleOverride: paywallOverrides?.presentationStyle, paywallStatePublisher: paywallStatePublisher)
          completion(state.paywallViewController, nil)
        }
      ))
    }


  }
}
