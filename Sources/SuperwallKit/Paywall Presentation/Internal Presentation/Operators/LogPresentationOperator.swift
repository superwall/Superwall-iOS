//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

typealias DebugInfo = [String: Any]

extension AnyPublisher where Output == PresentationRequest, Failure == Error {
  /// Logs the presentation request with a custom message and gets debug info for the event.
  ///
  /// - Parameters:
  ///     - message: A message to log.
  func logPresentation(_ message: String) -> AnyPublisher<(PresentationRequest, DebugInfo), Failure> {
    map { request in
      let eventData = request.presentationInfo.eventData
      let debugInfo: [String: Any] = [
        "on": request.presentingViewController.debugDescription,
        "fromEvent": eventData.debugDescription as Any,
        "cached": request.cached
      ]

      Logger.debug(
        logLevel: .debug,
        scope: .paywallPresentation,
        message: message,
        info: debugInfo
      )
      return (request, debugInfo)
    }
    .eraseToAnyPublisher()
  }
}
