//
//  File.swift
//  
//
//  Created by Yusuf Tör on 28/10/2022.
//

import Foundation
@testable import SuperwallKit

actor MockSessionEventsQueue: SessionEnqueuable {
  var transactions: [StoreTransaction] = []

  func enqueue(_ transaction: StoreTransaction) {
    transactions.append(transaction)
  }

  func flushInternal(depth: Int) {}

  func saveCacheToDisk() {}
}
