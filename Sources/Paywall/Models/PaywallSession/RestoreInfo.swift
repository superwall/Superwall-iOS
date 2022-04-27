//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

extension PaywallSession {
  struct RestoreInfo: Encodable {
    /// When the transaction restoration was initiated.
    let startAt: Date
    /// When the transaction restoration failed.
    let failedAt: Date
    /// When the transaction restoration completed.
    let completedAt: Date
  }
}
