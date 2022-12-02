//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

extension AnyPublisher where Output == (PresentationRequest, DebugInfo), Failure == Error {
  /// If debugger is launched but the presenting view controller isn't the debugger
  /// then it throws an error and cancels the pipeline.
  func checkDebuggerPresentation() -> AnyPublisher<Output, Failure> {
    tryMap { request, debugInfo in
      if request.injections.isDebuggerLaunched {
        guard request.presentingViewController is SWDebugViewController else {
          throw PresentationPipelineError.cancelled
        }
      }
      return (request, debugInfo)
    }
    .eraseToAnyPublisher()
  }
}
