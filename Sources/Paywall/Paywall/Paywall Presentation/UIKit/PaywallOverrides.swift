//
//  File.swift
//  
//
//  Created by Yusuf Tör on 07/09/2022.
//

import Foundation

public struct PaywallOverrides {
  public let products: PaywallProducts?
  public let ignoreSubscriptionStatus: Bool
  public let presentationStyle: PaywallPresentationStyle?

  public init(
    products: PaywallProducts? = nil,
    ignoreSubscriptionStatus: Bool = false,
    presentationStyleOverride: PaywallPresentationStyle? = nil
  ) {
    self.products = products
    self.ignoreSubscriptionStatus = ignoreSubscriptionStatus
    self.presentationStyle = presentationStyleOverride
  }
}
