//
//  File.swift
//  
//
//  Created by Yusuf Tör on 28/10/2022.
//

import Foundation
@testable import SuperwallKit

final class SessionEventsDelegateMock: SessionEventsDelegate {
  var queue: SessionEnqueuable

  init(
    queue: SessionEnqueuable
  ) {
    self.queue = queue
  }

  func enqueue(_ transaction: StoreTransaction) async {
    await queue.enqueue(transaction)
  }
}
