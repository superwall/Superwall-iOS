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
    forEvent event: String,
    params: [String: Any]? = nil,
    paywallOverrides: PaywallOverrides? = nil,
    completion: @escaping (Result<PaywallViewController, Error>) -> Void
  ) {
    Task {
      do {
        let paywallViewController = try await getPaywall(
          forEvent: event,
          params: params,
          paywallOverrides: paywallOverrides
        )
        completion(.success(paywallViewController))
      } catch {
        completion(.failure(error))
      }
    }
  }

  public func getPaywall(
    forEvent: String,
    params: [String: Any]? = nil,
    paywallOverrides: PaywallOverrides? = nil
  ) async throws -> PaywallViewController {
    return try await Future {
      let trackableEvent = UserInitiatedEvent.Track(
        rawName: forEvent,
        canImplicitlyTriggerPaywall: false,
        customParameters: params ?? [:],
        isFeatureGatable: false
      )
      let trackResult = await self.track(trackableEvent)
      return trackResult
    }
    .flatMap { trackResult in
      let presentationRequest = self.dependencyContainer.makePresentationRequest(
        .explicitTrigger(trackResult.data),
        paywallOverrides: paywallOverrides,
        isPaywallPresented: false
      )

      let paywallStatePublisher: PassthroughSubject<PaywallState, Never> = .init()

      return self.internallyGetPaywallViewController(presentationRequest, paywallStatePublisher)
    }
    .eraseToAnyPublisher()
    .throwableAsync()
  }
}
