//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation
import Combine

struct PaywallResponseRequest {
  let eventData: EventData?
  let responseIdentifiers: ResponseIdentifiers
  let substituteProducts: PaywallProducts?

  var publisher: AnyPublisher<Self, Error> {
    Just(self)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
  }
}
