//
//  File.swift
//  
//
//  Created by Yusuf Tör on 01/09/2023.
//

import UIKit

extension UIWindow {
  static var hasTouched = false

  // TODO: What if we have multiple windows?? Need to make sure swizzledSendEvnet is only called once.
  /// Intercepts the very first touch on the UIWindow
  static func swizzleSendEvent() {
    let originalSelector = #selector(UIWindow.sendEvent(_:))
    let swizzledSelector = #selector(swizzledSendEvent(_:))

    guard
        let originalMethod = class_getInstanceMethod(UIWindow.self, originalSelector),
        let swizzledMethod = class_getInstanceMethod(UIWindow.self, swizzledSelector)
    else {
        return
    }

    method_exchangeImplementations(originalMethod, swizzledMethod)
  }

  @objc private func swizzledSendEvent(_ event: UIEvent) {
    if event.type == .touches {
      // Handle touch events
      guard let _ = event.allTouches?.filter({ $0.phase == .began }) else {
        // Call the original implementation of sendEvent
        swizzledSendEvent(event)
        return
      }
      Task {
        let event = InternalSuperwallEvent.TouchesBegan()
        await Superwall.shared.track(event)
      }

      // Call the original implementation of sendEvent
      swizzledSendEvent(event)

      // Reverse the swizzle
      Self.swizzleSendEvent()
    } else {
      // Call the original implementation of sendEvent
      swizzledSendEvent(event)
    }
  }
}
