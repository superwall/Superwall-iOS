//
//  File.swift
//  
//
//  Created by Yusuf Tör on 02/05/2023.
//

import Foundation
import Combine

extension AnyPublisher where Output == PresentablePipelineOutput, Failure == Error {
  func logErrors(from request: PresentationRequest) -> PresentablePipelineOutputPublisher {
    tryCatch { error -> PresentablePipelineOutputPublisher in
      Task.detached {
        if let reason = error as? PresentationPipelineError {
          let trackedEvent = InternalSuperwallEvent.PresentationRequest(
            eventData: request.presentationInfo.eventData,
            type: request.flags.type,
            status: .noPresentation,
            statusReason: reason
          )
          await Superwall.shared.track(trackedEvent)
        }
      }
      Logger.debug(
        logLevel: .info,
        scope: .paywallPresentation,
        message: "Skipped paywall presentation: \(error)"
      )
      throw error
    }
    .eraseToAnyPublisher()
  }
}
