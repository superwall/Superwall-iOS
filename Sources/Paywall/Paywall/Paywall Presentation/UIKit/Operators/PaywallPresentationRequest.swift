//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import UIKit
import Combine

struct PaywallPresentationRequest {
  let presentationInfo: PresentationInfo
  var presentingViewController: UIViewController?
  var cached = true
  var paywallOverrides: PaywallOverrides?

  var publisher: AnyPublisher<Self, Error> {
    Just(self)
      .setFailureType(to: Error.self)
      .eraseToAnyPublisher()
  }
}
