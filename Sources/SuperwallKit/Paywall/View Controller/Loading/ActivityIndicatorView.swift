//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/10/2022.
//
// swiftlint:disable void_function_in_ternary

import SwiftUI

#if os(macOS)
struct ActivityIndicatorView: NSViewRepresentable {
  var isAnimating: Bool

  func makeNSView(context: Context) -> NSProgressIndicator {
    let spinner = NSProgressIndicator()
    spinner.style = .spinning
    spinner.controlSize = .large
    spinner.isDisplayedWhenStopped = true
    // The spinner sits on a dark blur, so draw it light whatever the app's
    // appearance.
    spinner.appearance = NSAppearance(named: .darkAqua)
    spinner.translatesAutoresizingMaskIntoConstraints = false
    return spinner
  }

  func updateNSView(_ nsView: NSProgressIndicator, context: Context) {
    isAnimating ? nsView.startAnimation(nil) : nsView.stopAnimation(nil)
  }
}
#else
struct ActivityIndicatorView: UIViewRepresentable {
  var isAnimating: Bool

  func makeUIView(context: Context) -> UIActivityIndicatorView {
    let spinner = UIActivityIndicatorView()
    spinner.color = .white
    spinner.translatesAutoresizingMaskIntoConstraints = false
    spinner.style = .large
    spinner.hidesWhenStopped = false
    return spinner
  }

  func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
    isAnimating ? uiView.startAnimating() : uiView.stopAnimating()
  }
}
#endif
