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
  ///    - request: The presentation request.
  ///    - message: A message to log.
  func logPresentation(request: PresentationRequest) -> [String: Any] {
    var message = "Called "
    switch request.flags.type {
    case .getPaywall:
      message += "Superwall.shared.getPaywall"
    case .presentation:
      switch request.presentationInfo.triggerType {
      case .explicit:
        message += "Superwall.shared.register"
      case .implicit:
        message = "Tracking an implicit trigger"
      }
    case .getPresentationResult:
      message += "Superwall.shared.getPresentationResult"
    case .getImplicitPresentationResult:
      message += "Superwall.shared.getImplicitPresentationResult"
    }
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
