//
//  File.swift
//  
//
//  Created by Yusuf Tör on 02/12/2022.
//

import UIKit
import Combine

final class PresentationItems {
  /// Used to store the publishers from ``track(event:params:paywallOverrides:paywallHandler:)``
  /// and its internal presentation subject so that they don't instantly deallocate.
  ///
  /// They are removed from here on completion of the publisher.
  var cancellables: Set<AnyCancellable> = []

  /// The publisher and request involved in the last successful paywall presentation request.
  var last: LastPresentationItems?

  /// The ``PaywallInfo`` object stored from the last paywall view controller that was dismissed.
  var paywallInfo: PaywallInfo?

  /// The window that presents the paywall.
  var window: UIWindow?

  func reset() {
    cancellables.removeAll()
    last = nil
    window = nil
    paywallInfo = nil
  }
}

/// Items involved in the last successful paywall presentation request.
struct LastPresentationItems {
  /// The last successful paywall presentation request.
  let request: PresentationRequest

  /// The last sucessful presentation subject.
  let subject: PresentationSubject
}
