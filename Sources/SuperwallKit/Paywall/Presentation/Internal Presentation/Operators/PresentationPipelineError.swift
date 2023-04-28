//
//  File.swift
//  
//
//  Created by Yusuf Tör on 26/09/2022.
//

import Foundation

enum PresentationPipelineError: Error {
  case debuggerPresented
  case paywallAlreadyPresented
  case userIsSubscribed
  case holdout
  case noRuleMatch
  case eventNotFound
  case noPaywallViewController
  case noPresenter
  case cancelled
  case unknown
}
