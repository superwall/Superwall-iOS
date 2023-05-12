//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//

import Foundation

extension Superwall {
  /// Logs the presentation request with a custom message and gets debug info for the event.
  ///
  /// - Parameters:
  ///     - message: A message to log.
  func logPresentation(
    _ request: PresentationRequest,
    _ message: String
  ) -> [String: Any] {
    let eventData = request.presentationInfo.eventData
    let debugInfo: [String: Any] = [
      "on": request.presenter.debugDescription,
      "fromEvent": eventData.debugDescription as Any
    ]
    Logger.debug(
      logLevel: .debug,
      scope: .paywallPresentation,
      message: message,
      info: debugInfo
    )
    return debugInfo
  }
}
