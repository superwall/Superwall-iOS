//
//  File.swift
//  
//
//  Created by Yusuf Tör on 02/05/2023.
//

import Foundation
import Combine

extension AnyPublisher where Output == PresentablePipelineOutput, Failure == Error {
  func printErrors() -> PresentablePipelineOutputPublisher {
    handleEvents(receiveCompletion: { completion in
      switch completion {
      case .failure(let error):
        Logger.debug(
          logLevel: .error,
          scope: .paywallPresentation,
          message: "Skipped paywall presentation: \(error)"
        )
      case .finished:
        break
      }
    })
    .eraseToAnyPublisher()
  }
}
