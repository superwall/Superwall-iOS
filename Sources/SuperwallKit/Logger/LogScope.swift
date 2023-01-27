//
//  File.swift
//  
//
//  Created by Yusuf Tör on 22/11/2022.
//

import Foundation

/// The possible scope of logs to print to the console.
@objc(SWKLogScope)
public enum LogScope: Int, Sendable, CustomStringConvertible {
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

  public var description: String {
    switch self {
    case .localizationManager:
      return "localizationManager"
    case .bounceButton:
      return "bounceButton"
    case .coreData:
      return "coreData"
    case .configManager:
      return "configManager"
    case .debugManager:
      return "debugManager"
    case .debugViewController:
      return "debugViewController"
    case .localizationViewController:
      return "localizationViewController"
    case .gameControllerManager:
      return "gameControllerManager"
    case .device:
      return "device"
    case .network:
      return "network"
    case .paywallEvents:
      return "paywallEvents"
    case .productsManager:
      return "productsManager"
    case .storeKitManager:
      return "storeKitManager"
    case .events:
      return "events"
    case .receipts:
      return "receipts"
    case .superwallCore:
      return "superwallCore"
    case .paywallPresentation:
      return "paywallPresentation"
    case .paywallTransactions:
      return "paywallTransactions"
    case .paywallViewController:
      return "paywallViewController"
    case .cache:
      return "cache"
    case .all:
      return "all"
    }
  }
}
