//
//  File.swift
//  SuperwallKit
//
//  Created by Yusuf Tör on 17/10/2024.
//

import SwiftUI

struct PaywallViewControllerWrapper: UIViewControllerRepresentable {
  typealias UIViewControllerType = PaywallViewController
  let paywallViewController: PaywallViewController

  func makeUIViewController(context: Context) -> PaywallViewController {
    return paywallViewController
  }

  func updateUIViewController(_ uiViewController: PaywallViewController, context: Context) {}
}
