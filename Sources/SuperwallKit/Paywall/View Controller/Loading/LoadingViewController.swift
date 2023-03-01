//
//  File.swift
//  
//
//  Created by Yusuf Tör on 11/10/2022.
//

import SwiftUI

protocol LoadingDelegate: AnyObject {
  var loadingState: PaywallLoadingState { get }
}

final class LoadingViewController: UIHostingController<LoadingView> {
  let model: LoadingModel

  init(delegate: LoadingDelegate) {
    model = LoadingModel(delegate: delegate)
    super.init(rootView: LoadingView(model: model))
    view.backgroundColor = .clear
    view.translatesAutoresizingMaskIntoConstraints = false
  }

  @MainActor required dynamic init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show() {
    self.view.isHidden = false
    model.isHidden = false
  }

  func hide() {
    model.isHidden = true
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) { [weak self] in
      self?.view.isHidden = true
    }
  }
}
