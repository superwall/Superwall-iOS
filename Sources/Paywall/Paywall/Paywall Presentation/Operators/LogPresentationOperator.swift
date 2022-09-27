//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

typealias DebugInfo = [String: Any]

extension AnyPublisher where Output == PaywallPresentationRequest, Failure == Error {
  func logPresentation() -> AnyPublisher<(PaywallPresentationRequest, DebugInfo), Failure> {
    self
      .map { request in
        let eventData = request.presentationInfo.eventData
        let debugInfo: [String: Any] = [
          "on": request.presentingViewController.debugDescription,
          "fromEvent": eventData.debugDescription as Any,
          "cached": request.cached
        ]
        Logger.debug(
          logLevel: .debug,
          scope: .paywallPresentation,
          message: "Called Paywall.track",
          info: debugInfo
        )
        return (request, debugInfo)
      }
      .eraseToAnyPublisher()
  }
}
