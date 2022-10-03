//
//  PaywallPresentationResult.swift
//  Superwall
//
//  Created by Yusuf Tör on 07/03/2022.
//

import Foundation

enum PaywallPresentationResult {
  case closed
  case initiatePurchase(productId: String)
  case initiateRestore
  case custom(string: String)
  case openedURL(url: URL)
  case openedUrlInSafari(_ url: URL)
  case openedDeepLink(url: URL)
}
