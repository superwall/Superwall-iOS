//
//  WKExtension+Platform.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 04/11/2026.
//
// The WatchKit side of the UIKit helpers the SDK leans on, given the same names
// so shared code calls one API on every platform.

#if os(watchOS)
import WatchKit

extension WKExtension {
  /// The shared extension object, under the name UIKit code uses.
  static var sharedApplication: WKExtension? {
    return WKExtension.shared()
  }

  /// Opens a system URL, such as a phone number or the App Store.
  func open(_ url: URL) {
    openSystemURL(url)
  }
}
#endif
