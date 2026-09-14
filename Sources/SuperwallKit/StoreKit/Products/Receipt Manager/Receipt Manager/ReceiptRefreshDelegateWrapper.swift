//
//  ReceiptRefreshDelegateWrapper.swift
//  SuperwallKit
//

import Foundation
import StoreKit

final class ReceiptRefreshDelegateWrapper: NSObject, SKRequestDelegate {
  weak var receiptManager: ReceiptManager?

  func requestDidFinish(_ request: SKRequest) {
    Task {
      await receiptManager?.receiptRefreshDidFinish(request: request)
    }
  }

  func request(_ request: SKRequest, didFailWithError error: Error) {
    Task {
      await receiptManager?.receiptRefreshDidFail(
        request: request,
        error: error
      )
    }
  }
}
