//
//  File.swift
//  
//
//  Created by Jake Mor on 8/3/22.
//

import Foundation
import UIKit

extension UIApplication {
  var activeWindow: UIWindow? {
    if #available(iOS 13.0, *) {
      let windows = UIApplication.shared.connectedScenes.flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
      return windows.first { $0.isKeyWindow } ?? windows.first
    } else {
      return UIApplication.shared.keyWindow
    }
  }
}
