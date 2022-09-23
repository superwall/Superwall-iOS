//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

extension AnyPublisher where Output == (PaywallPresentationRequest, DebugInfo), Failure == Error {
  func checkForDebugger(_ cancellable: AnyCancellable?) -> AnyPublisher<Output, Failure> {
    self
      .receive(on: RunLoop.main)
      .map { request, debugInfo in
        let isDebuggerLaunched = SWDebugManager.shared.isDebuggerLaunched
        if isDebuggerLaunched {
          // if the debugger is launched, ensure the viewcontroller is the debugger
          guard request.presentingViewController is SWDebugViewController else {
            cancellable?.cancel()
            return
          }
        }
        return (request, debugInfo)
      }
      .receive(on: DispatchQueue.global(qos: .userInitiated))
      .eraseToAnyPublisher()
  }
}
