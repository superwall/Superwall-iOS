//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

extension AnyPublisher where Output == (PresentationRequest, DebugInfo), Failure == Error {
  /// Checks whether the debugger is launched. If it is but the presenting view controller isn't the debugger
  /// then it throws an error and cancels the pipeline.
  func checkForDebugger() -> AnyPublisher<Output, Failure> {
    asyncMap { request, debugInfo in
      let isDebuggerLaunched = await SWDebugManager.shared.isDebuggerLaunched
      if isDebuggerLaunched {
        guard request.presentingViewController is SWDebugViewController else {
          throw PresentationPipelineError.cancelled
        }
      }
      return (request, debugInfo)
    }
    .eraseToAnyPublisher()
  }
}
