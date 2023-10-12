//
//  File.swift
//  
//
//  Created by Yusuf Tör on 09/10/2023.
//

import Foundation

/// An enum whose cases describe the type of restore that occurred.
public enum RestoreType {
  /// The user tried to purchase a product and it resulted in a restore.
  case viaPurchase(StoreTransaction?)

  /// The user tried to restore purchases.
  case viaRestore
}
