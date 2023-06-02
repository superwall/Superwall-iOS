//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

/// A request to get a paywall.
struct PaywallRequest {
  struct Overrides {
    /// The products to substitute into the response.
    var products: PaywallProducts?

    /// Whether to override the displaying of a free trial.
    var isFreeTrial: Bool?
  }

  /// The event data
  var eventData: EventData?

  /// The identifiers for the paywall and experiment.
  let responseIdentifiers: ResponseIdentifiers

  /// Overrides within the paywall.
  let overrides: Overrides

  /// If the debugger is launched when the request was created.
  let isDebuggerLaunched: Bool

  /// The number of times to retry the request.
  let retryCount: Int
}
