//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

extension AnyPublisher where Output == (PaywallPresentationRequest, DebugInfo), Failure == Error {
  func checkForDebugger() -> AnyPublisher<Output, Failure> {
    self
      .flatMap { request, debugInfo in
        Future {
          let isDebuggerLaunched = await SWDebugManager.shared.isDebuggerLaunched
          if isDebuggerLaunched {
            guard request.presentingViewController is SWDebugViewController else {
              throw PresentationPipelineError.cancelled
            }
          }
          return (request, debugInfo)
        }
      }
      .eraseToAnyPublisher()
  }
}
