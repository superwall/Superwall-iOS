//
//  File.swift
//  
//
//  Created by Jake Mor on 3/22/23.
//

import Foundation

public class PaywallPresentationHandler: NSObject {
  public var onPresent: ((_ paywallInfo: PaywallInfo) -> Void)? = nil
  public var onDismiss: ((_ paywallInfo: PaywallInfo) -> Void)? = nil
  public var onError: ((_ error: Error) -> Void)? = nil
}
