//
//  File.swift
//  
//
//  Created by Yusuf Tör on 18/10/2022.
//

import Foundation

//TODO: DOCUMENT THIS
public enum PurchaseResult {
  case cancelled
  case purchased
  case pending
  case failed(Error)
}

@objc public enum PurchaseResultObjc: Int {
  case cancelled
  case purchased
  case pending
  case failed
}
