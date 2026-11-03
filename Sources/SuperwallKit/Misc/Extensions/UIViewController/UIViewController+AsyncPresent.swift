//
//  File.swift
//  
//
//  Created by Yusuf Tör on 13/10/2022.
//

#if !os(macOS)
import UIKit

extension UIViewController {
  @MainActor
  func present(_ viewControllerToPresent: UIViewController, animated flag: Bool) async {
    return await withCheckedContinuation { continuation in
      present(viewControllerToPresent, animated: flag) {
        continuation.resume()
      }
    }
  }
}
#endif
