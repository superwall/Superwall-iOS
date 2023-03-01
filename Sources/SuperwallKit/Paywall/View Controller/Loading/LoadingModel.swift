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
  @Published var opacityAmount = 0.01
  @Published var rotationAmount: CGFloat = .pi
  @Published var padding: CGFloat = 0
  @Published var isHidden = false
  @Published var movedUp = false
  private weak var delegate: LoadingDelegate?

  init(delegate: LoadingDelegate?) {
    self.delegate = delegate
    addObservers()
  }

  /// Add observers so that we know when the payment sheet will display.
  private func addObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  @objc private func applicationWillResignActive() {
    guard delegate?.loadingState == .loadingPurchase else {
      return
    }
    movedUp = true
  }

  @objc private func applicationDidBecomeActive() {
    guard delegate?.loadingState == .loadingPurchase else {
      return
    }
    movedUp = false
  }
}
