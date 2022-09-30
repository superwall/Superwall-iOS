//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

struct PaywallRequest {
  var eventData: EventData?
  let responseIdentifiers: ResponseIdentifiers
  var substituteProducts: PaywallProducts?

  var publisher: AnyPublisher<Self, Error> {
    Just(self)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
  }
}
