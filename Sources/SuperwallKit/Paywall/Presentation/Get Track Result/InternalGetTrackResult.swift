//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/11/2022.
//

import Foundation
import Combine

enum GetTrackResultError: Error, Equatable {
  case willNotPresent(TriggerResult)
  case userIsSubscribed
  case paywallNotAvailable

  static func == (lhs: GetTrackResultError, rhs: GetTrackResultError) -> Bool {
    switch (lhs, rhs) {
    case (.willNotPresent, .willNotPresent),
      (.userIsSubscribed, .userIsSubscribed),
      (.paywallNotAvailable, .paywallNotAvailable):
      return true
    default:
      return false
    }
  }
}

extension Superwall {
  func getTrackResult(for request: PresentationRequest) async -> PresentationResult {
    let presentationSubject = PresentationSubject(request)

    return await presentationSubject
      .eraseToAnyPublisher()
      .waitToPresent()
      .logPresentation("Called Superwall.shared.getTrackResult")
      .evaluateRules(isPreemptive: true)
      .checkForPaywallResult()
      .getPaywallViewController(pipelineType: .getTrackResult)
      .checkPaywallIsPresentable()
      .convertToTrackResult()
      .async()
  }
}

// MARK: - Async Publisher for GetTrackResult
extension Publisher where Output == PresentationResult {
  /// Waits and returns the first value of the publisher.
  ///
  /// This handles the error cases thrown by `getTrackResult(for:)`.
  @discardableResult
  func async() async -> Output {
    await withCheckedContinuation { continuation in
      var cancellable: AnyCancellable?
      cancellable = first()
        .sink { completion in
          switch completion {
          case .failure(let error):
            switch error {
            case let error as GetTrackResultError:
              switch error {
              case .willNotPresent(let result):
                let trackResult = GetTrackResultLogic.convertTriggerResult(result)
                continuation.resume(with: .success(trackResult))
              case .userIsSubscribed:
                continuation.resume(with: .success(.userIsSubscribed))
              case .paywallNotAvailable:
                continuation.resume(with: .success(.paywallNotAvailable))
              }
            default:
              break
            }
            cancellable?.cancel()
          case .finished:
            cancellable?.cancel()
          }
        } receiveValue: { value in
          continuation.resume(with: .success(value))
        }
    }
  }
}
