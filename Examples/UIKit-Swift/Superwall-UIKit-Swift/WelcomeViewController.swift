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
  private var isLoggedIn = false
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = true
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    isLoggedIn = UserDefaults.standard.bool(forKey: "IsLoggedIn")

    if isLoggedIn {
      next()
    }

    textFieldBackgroundView.layer.cornerRadius = textFieldBackgroundView.frame.height / 2
    textField.delegate = self
    UINavigationBar.appearance().titleTextAttributes = [
      .foregroundColor: UIColor.white,
      .font: UIFont.rubikBold(.five)
    ]
    navigationController?.interactivePopGestureRecognizer?.isEnabled = false
  }

  @IBAction private func logIn() {
    UserDefaults.standard.setValue(true, forKey: "IsLoggedIn")
    Task {
      if let name = textField.text {
        SuperwallService.setName(to: name)
      }
      await SuperwallService.identify()
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
