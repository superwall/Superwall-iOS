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
  /// Gets the  ``PaywallViewController`` object, which you can present
  /// however you want.
  ///
  /// To use this you **must** follow the following steps:
  ///
  /// 1. Call this function to retrieve the ``PaywallViewController``.
  /// 2. Call ``PaywallViewController/presentationWillBegin()`` when
  /// you're about to present the view controller.
  /// 3. Present the view controller.
  /// 4. Call ``PaywallViewController/presentationDidFinish()`` after presentation
  /// completes.
  ///
  /// - Note: The remotely configured presentation style will be ignored, it is up to you
  /// to set it programmatically. 
  public func getPaywallViewController(
    forEvent event: String,
    params: [String: Any]? = nil,
    paywallOverrides: PaywallOverrides? = nil,
    completion: @escaping (Result<PaywallViewController, Error>) -> Void
  ) {
    Task { @MainActor in 
      do {
        let paywallViewController = try await getPaywallViewController(
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

  /// Gets the  ``PaywallViewController`` object, which you can present
  /// however you want.
  ///
  /// To use this you **must** follow the following steps:
  ///
  /// 1. Call this function to retrieve the ``PaywallViewController``.
  /// 2. Call ``PaywallViewController/presentationWillBegin()`` when
  /// you're about to present the view controller.
  /// 3. Present the view controller.
  /// 4. Call ``PaywallViewController/presentationDidFinish()`` after presentation
  /// completes.
  ///
  /// - Note: The remotely configured presentation style will be ignored, it is up to you
  /// to set it programmatically.
  public func getPaywallViewController(
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
      return self.internallyGetPaywallViewController(presentationRequest)
    }
    .eraseToAnyPublisher()
    .throwableAsync()
  }
}
