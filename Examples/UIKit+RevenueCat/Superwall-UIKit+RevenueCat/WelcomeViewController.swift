//
//  WelcomeViewController.swift
//  SuperwallUIKitExample
//
//  Created by Yusuf Tör on 05/04/2022.
//

import UIKit
import SuperwallKit

final class WelcomeViewController: UIViewController {
  @IBOutlet private var textFieldBackgroundView: UIView!
  @IBOutlet private var textField: UITextField!

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = true
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(superwallDidConfigure),
      name: Notification.Name("SuperwallDidConfigure"),
      object: nil
    )

    textFieldBackgroundView.layer.cornerRadius = textFieldBackgroundView.frame.height / 2
    textField.delegate = self
    UINavigationBar.appearance().titleTextAttributes = [
      .foregroundColor: UIColor.white,
      .font: UIFont.rubikBold(.five)
    ]
    navigationController?.interactivePopGestureRecognizer?.isEnabled = false
  }

  @objc
  private func superwallDidConfigure() {
    if Superwall.isLoggedIn {
      next()
    }
  }

  @IBAction private func logIn() {
    Task {
      if let name = textField.text {
        PaywallManager.setName(to: name)
      }
      let userId = "abc"
      await PaywallManager.logIn(userId: userId)
      next()
    }
  }

  private func next() {
    let trackEventViewController = TrackEventViewController.fromStoryboard()
    navigationController?.pushViewController(trackEventViewController, animated: true)
  }
}

// MARK: - UITextFieldDelegate
extension WelcomeViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
}
