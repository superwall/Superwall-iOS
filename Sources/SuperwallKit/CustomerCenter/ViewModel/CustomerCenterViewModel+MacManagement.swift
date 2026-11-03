//
//  CustomerCenterViewModel+MacManagement.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 16/10/2026.
//

import Foundation

#if os(macOS)
extension CustomerCenterViewModel {
  /// The App Store's page for managing subscriptions, which opens in the App
  /// Store app.
  // swiftlint:disable:next force_unwrapping
  static let appStoreSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

  enum RefreshOnReturn {
    /// Read the receipts again, as after the iOS manage sheet. Turning off
    /// auto-renew produces no transaction update to pick up.
    case receipts
    /// Fetch customer info again, as after the iOS Safari sheet.
    case customerInfo
  }

  /// Opens a page for managing a purchase in the user's browser or the App
  /// Store, and refreshes once they're back, as closing the iOS sheet does.
  func openForManagement(_ url: URL, refresh: RefreshOnReturn) {
    refreshOnReturn = refresh
    dependencies.urlOpener.open(url)
  }

  func appDidBecomeActive() async {
    guard let refresh = refreshOnReturn else {
      return
    }
    refreshOnReturn = nil
    let info: CustomerInfo
    switch refresh {
    case .receipts:
      info = await dependencies.customerInfo.refreshReceipts()
    case .customerInfo:
      info = await dependencies.customerInfo.fetchCustomerInfo()
    }
    await apply(customerInfo: info, refetchProducts: true)
  }
}
#endif
