//
//  File.swift
//  
//
//  Created by Yusuf Tör on 02/12/2022.
//

import UIKit
import Combine

final class PresentationItems {
  /// The publisher and request involved in the last successful paywall presentation request.
  var last: LastPresentationItems?

  /// The ``PaywallInfo`` object stored from the last paywall view controller that was dismissed.
  var paywallInfo: PaywallInfo?

  /// The window that presents the paywall.
  var window: UIWindow?

  func reset() {
    last = nil
    window = nil
    paywallInfo = nil
  }
}

/// Items involved in the last successful paywall presentation request.
struct LastPresentationItems {
  /// The last paywall presentation request.
  let request: PresentationRequest

  /// The last state publisher.
  let statePublisher: PassthroughSubject<PaywallState, Never>
}
