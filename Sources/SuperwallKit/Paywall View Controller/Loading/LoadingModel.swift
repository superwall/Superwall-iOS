//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/10/2022.
//

import SwiftUI

final class LoadingModel: ObservableObject {
  @Published var isAnimating = false
  @Published var scaleAmount = 0.05
  @Published var rotationAmount: CGFloat = .pi
  @Published var padding: CGFloat = 0
  @Published var isHidden = false
  private weak var delegate: LoadingDelegate?

  init(delegate: LoadingDelegate?) {
    self.delegate = delegate
  }
}
