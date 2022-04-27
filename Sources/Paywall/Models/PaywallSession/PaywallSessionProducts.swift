//
//  File.swift
//  
//
//  Created by Yusuf Tör on 27/04/2022.
//

import Foundation

extension PaywallSession {
  struct Products: Encodable {
    /// Array of products available
    let array: [SWProduct]
    /// array of names of products on the paywall
    let ids: [String]
    let platformIdentifiers: [String]
    /// The loading start and end times, as well as duration.
    let loadingInfo: LoadingInfo
  }
}
