//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 17/10/2024.
//

import SwiftUI

#if os(macOS)
struct PaywallViewControllerWrapper: NSViewControllerRepresentable {
  typealias NSViewControllerType = PaywallViewController
  let paywallViewController: PaywallViewController

  func makeNSViewController(context: Context) -> PaywallViewController {
    return paywallViewController
  }

  func updateNSViewController(_ nsViewController: PaywallViewController, context: Context) {}
}
#else
struct PaywallViewControllerWrapper: UIViewControllerRepresentable {
  typealias UIViewControllerType = PaywallViewController
  let paywallViewController: PaywallViewController

  func makeUIViewController(context: Context) -> PaywallViewController {
    return paywallViewController
  }

  func updateUIViewController(_ uiViewController: PaywallViewController, context: Context) {}
}
#endif
