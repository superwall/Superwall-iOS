//
//  File.swift
//  
//
//  Created by Yusuf Tör on 06/12/2022.
//

import UIKit
import Combine
@testable import SuperwallKit

final class PaywallViewControllerMock: PaywallViewController {
  var shouldPresent = false

  override func present(
    on presenter: UIViewController,
    eventData: EventData?,
    presentationStyleOverride: PaywallPresentationStyle?,
    paywallStatePublisher: PassthroughSubject<PaywallState, Never>,
    completion: @escaping (Bool) -> Void
  ) {
    completion(shouldPresent)
  }
}
