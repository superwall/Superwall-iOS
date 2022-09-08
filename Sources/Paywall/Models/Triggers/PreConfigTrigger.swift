//
//  File.swift
//  
//
//  Created by Yusuf Tör on 01/06/2022.
//

import UIKit

struct PreConfigTrigger {
  let presentationInfo: PresentationInfo
  var viewController: UIViewController?
  var paywallOverrides: PaywallOverrides?
  var paywallState: ((PaywallState) -> Void)?
}
