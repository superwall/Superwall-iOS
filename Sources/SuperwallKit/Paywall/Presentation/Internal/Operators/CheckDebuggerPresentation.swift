//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/05/2023.
//

import Foundation
import Combine

extension Superwall {
  /// Cancels the state publisher if the debugger is already launched.
  ///
  /// - Parameters:
  ///   - request: The presentation request.
  ///   - paywallStatePublisher: A `PassthroughSubject` that gets sent ``PaywallState`` objects.
  func checkDebuggerPresentation(
    request: PresentationRequest,
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>?
  ) throws {
    guard request.flags.type == .presentation else {
      return
    }
    guard request.flags.isDebuggerLaunched else {
      return
    }
    #if os(macOS)
    if request.presenter is MacDebugViewController {
      return
    }
    #else
    if request.presenter is DebugViewController {
      return
    }
    #endif
    let error = InternalPresentationLogic.presentationError(
      domain: "SWKPresentationError",
      code: 101,
      title: "Debugger Is Presented",
      value: "Trying to present paywall when debugger is launched."
    )
    let state: PaywallState = .presentationError(error)
    paywallStatePublisher?.send(state)
    paywallStatePublisher?.send(completion: .finished)
    throw PresentationPipelineError.debuggerPresented
  }
}
