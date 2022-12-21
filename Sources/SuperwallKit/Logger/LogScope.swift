//
//  File.swift
//  
//
//  Created by Yusuf Tör on 22/11/2022.
//

import Foundation

/// The possible scope of logs to print to the console.
public enum LogScope: String {
  case localizationManager
  case bounceButton
  case coreData
  case configManager
  case debugManager
  case debugViewController
  case localizationViewController
  case gameControllerManager
  case device
  case network
  case paywallEvents
  case productsManager
  case storeKitManager
  case events
  case receipts
  case superwallCore
  case paywallPresentation
  case paywallTransactions
  case paywallViewController
  case cache
  case all
}
