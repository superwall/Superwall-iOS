//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

extension PaywallSession {
  struct Paywall: Codable {
    /// Database ID of the paywall.
    let id: String
    /// Idenfier of the paywall.
    let identifier: String
    /// Loading info of the paywall webview.
    let webViewLoading: LoadingInfo
  }
}
