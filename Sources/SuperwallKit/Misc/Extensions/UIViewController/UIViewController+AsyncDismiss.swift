//
//  File.swift
//  
//
//  Created by Yusuf Tör on 20/09/2022.
//

import UIKit

extension UIViewController {
  @MainActor
  func dismiss(animated: Bool) async {
    await withCheckedContinuation { continuation in
      self.dismiss(animated: animated) {
        continuation.resume()
      }
    }
  }
}
