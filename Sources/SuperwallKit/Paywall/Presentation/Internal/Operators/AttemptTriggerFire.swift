//
//  AttemptTriggerFire.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 04/11/2026.
//

import Foundation

extension Superwall {
  func attemptTriggerFire(
    for request: PresentationRequest,
    triggerResult: InternalTriggerResult
  ) async {
    guard let placementName = request.presentationInfo.placementName else {
      // The paywall is being presented by identifier, which is what the debugger uses and that's not supported.
      return
    }
    switch request.presentationInfo {
    case .implicitTrigger,
      .explicitTrigger:
      switch triggerResult {
      case .error,
        .placementNotFound:
        return
      default:
        break
      }
    case .fromIdentifier:
      break
    }

    let triggerFire = InternalSuperwallEvent.TriggerFire(
      triggerResult: triggerResult,
      triggerName: placementName
    )
    await Superwall.shared.track(triggerFire)
  }
}
