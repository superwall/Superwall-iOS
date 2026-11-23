//
//  Storage+FirstDeepLink.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 10/11/2026.
//

import Foundation

extension Storage {
  /// Saves the server's answer about the first deep link, so the deep link
  /// isn't sent again.
  ///
  /// - Parameter page: The custom product page the deep link belongs to, or
  ///   `nil` if the server found none.
  func finishFirstSessionDeepLinkLookup(page: CustomProductPage?) {
    if let page {
      save(page, forType: FirstSessionCustomProductPage.self)
    }
    delete(FirstSessionDeepLinkLookup.self)
  }
}
