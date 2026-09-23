//
//  CustomerCenterViewModel+Refund.swift
//
//
//  Created by Yusuf Tör on 23/09/2026.
//

import Foundation

// MARK: - Refund sheet

@available(iOS 15.0, *)
extension CustomerCenterViewModel {
  /// Called by the refund sheet's completion. The product comes from when the sheet was opened,
  /// not from `sheet`: the sheet's binding clears `sheet` as it closes, which can happen before
  /// this runs.
  func refundRequestDidFinish(status: CustomerCenterRefundStatus) async {
    guard let productId = pendingRefundProductId else { return }
    pendingRefundProductId = nil
    await refundSheetDidFinish(productId: productId, status: status)
  }
}
