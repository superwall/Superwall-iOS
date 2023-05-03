//
//  File.swift
//
//
//  Created by Jake Mor on 10/9/21.
//

import Foundation
import Combine
import UIKit

extension Superwall {
  /// Gets the  ``PaywallViewController`` object for an event, which you can present
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
  ///
  /// - Parameters:
  ///   -  event: The name of the event, as you have defined on the Superwall dashboard.
  ///   - params: Optional parameters you'd like to pass with your event. These can be referenced within the rules
  ///   of your campaign. Keys beginning with `$` are reserved for Superwall and will be dropped. Values can be any
  ///   JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will
  ///   be dropped.
  ///   - paywallOverrides: An optional ``PaywallOverrides`` object whose parameters override the paywall defaults. Use this to override products, presentation style, and whether it ignores the subscription status. Defaults to `nil`.
  ///   - completion: A completion block that contains a `Result` type, containing either a success case with a
  ///   ``PaywallViewController`` object, or a failure case with an `Error`.
  public func getPaywallViewController(
    forEvent event: String,
    params: [String: Any]? = nil,
    paywallOverrides: PaywallOverrides? = nil,
    completion: @escaping (Result<PaywallViewController, Error>) -> Void
  ) {
    Task {
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
  ///
  /// - Parameters:
  ///   -  event: The name of the event, as you have defined on the Superwall dashboard.
  ///   - params: Optional parameters you'd like to pass with your event. These can be referenced within the rules
  ///   of your campaign. Keys beginning with `$` are reserved for Superwall and will be dropped. Values can be any
  ///   JSON encodable value, URLs or Dates. Arrays and dictionaries as values are not supported at this time, and will
  ///   be dropped.
  ///   - paywallOverrides: An optional ``PaywallOverrides`` object whose parameters override the paywall defaults. Use this to override products, presentation style, and whether it ignores the subscription status. Defaults to `nil`.
  ///
  /// - Returns A ``PaywallViewController`` object.
  /// - Throws: An `Error` explaining why it couldn't get the view controller.
  @MainActor
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
        isPaywallPresented: false,
        type: .getPaywallViewController
      )
      return self.internallyGetPaywallViewController(presentationRequest)
    }
    .eraseToAnyPublisher()
    .throwableAsync()
  }
}
