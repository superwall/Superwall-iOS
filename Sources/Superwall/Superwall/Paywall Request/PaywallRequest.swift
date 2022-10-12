//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

/// A request to get a paywall response.
struct PaywallRequest {
  /// The event data
  var eventData: EventData?

  /// The identifiers for the paywall and experiment.
  let responseIdentifiers: ResponseIdentifiers

  /// The products to substitute into the response.
  var substituteProducts: PaywallProducts?

  /// The request publisher that fires just once.
  var publisher: AnyPublisher<Self, Error> {
    Just(self)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
  }
}
