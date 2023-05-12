//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//

import Foundation
import Combine

extension Superwall {
  func checkDebuggerPresentation(
    _ request: PresentationRequest,
    _ paywallStatePublisher: PassthroughSubject<PaywallState, Never>
  ) throws {
    guard request.flags.isDebuggerLaunched else {
      return
    }
    if request.presenter is DebugViewController {
      return
    }
    let error = InternalPresentationLogic.presentationError(
      domain: "SWPresentationError",
      code: 101,
      title: "Debugger Is Presented",
      value: "Trying to present paywall when debugger is launched."
    )
    let state: PaywallState = .presentationError(error)
    paywallStatePublisher.send(state)
    paywallStatePublisher.send(completion: .finished)
    throw PresentationPipelineError.debuggerPresented
  }
}
