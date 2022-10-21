//
//  File.swift
//  
//
//  Created by Yusuf Tör on 21/10/2022.
//

import Foundation
import StoreKit

enum TransactionErrorLogic {
  enum ErrorOutcome {
    case cancelled
    case presentAlert
  }

  static func handle(_ error: Error) -> ErrorOutcome {
    if #available(iOS 15.0, *),
       let error = error as? StoreKitError {
      switch error {
      case .userCancelled:
        return .cancelled
      default:
        break
      }
    }
    if let error = error as? SKError {
      switch error.code {
      case .overlayCancelled,
        .paymentCancelled,
        .overlayTimeout:
        return .cancelled
      default:
        break
      }
    }

    return .presentAlert
  }
}
