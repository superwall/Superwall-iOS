//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/10/2022.
//

import SwiftUI



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
