//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//

import Foundation

extension Superwall {
  func logErrors(
    from request: PresentationRequest,
    _ error: Error
  ) {
    Task {
      if let reason = error as? PresentationPipelineError {
        let trackedEvent = InternalSuperwallEvent.PresentationRequest(
          eventData: request.presentationInfo.eventData,
          type: request.flags.type,
          status: .noPresentation,
          statusReason: reason
        )
        await track(trackedEvent)
      }
    }
    Logger.debug(
      logLevel: .info,
      scope: .paywallPresentation,
      message: "Skipped paywall presentation: \(error)"
    )
  }
}
