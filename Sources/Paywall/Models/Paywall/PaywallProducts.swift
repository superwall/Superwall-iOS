//
//  File.swift
//  
//
//  Created by Yusuf Tör on 31/08/2022.
//

import Foundation
import StoreKit

@objc public class PaywallProducts: NSObject {
  var primary: SKProduct?
  var secondary: SKProduct?
  var tertiary: SKProduct?

  private override init() {}

  public init(
    primary: SKProduct? = nil,
    secondary: SKProduct? = nil,
    tertiary: SKProduct? = nil
  ) {
    self.primary = primary
    self.secondary = secondary
    self.tertiary = tertiary
  }
}
