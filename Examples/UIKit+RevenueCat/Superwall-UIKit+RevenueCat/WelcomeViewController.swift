//
//  WelcomeViewController.swift
//  SuperwallUIKitExample
//
//  Created by Yusuf Tör on 05/04/2022.
//

import UIKit
import SuperwallKit
import RevenueCat

final class WelcomeViewController: UIViewController {
  @IBOutlet private var textFieldBackgroundView: UIView!
  @IBOutlet private var textField: UITextField!

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = true
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    if Superwall.shared.isLoggedIn {
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
    if let username = textField.text {
      if username.isEmpty {
        let alert = UIAlertController(title: "Username Left Blank", message: "How would you like to continue?", preferredStyle: .alert)
        let useAnonymous = UIAlertAction(title: "Anonymous Account",  style: .default) {
          [weak self] _ in
          self?.next()
        }
        let useUsername = UIAlertAction(title: "Pick Username", style: .default)
        alert.addAction(useAnonymous)
        alert.addAction(useUsername)
        present(alert, animated: true)
        return
      }

      Superwall.shared.setUserAttributes(["firstName": username])

      Superwall.shared.identify(userId: "abc_\(username)")
      Task {
        try? await Purchases.shared.logIn("abc_\(username)")
      }

      next()
    }


  }

  private func next() {
    let trackEventViewController = HomeViewController.fromStoryboard()
    navigationController?.pushViewController(trackEventViewController, animated: true)
  }
}

// MARK: - UITextFieldDelegate
extension WelcomeViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    _ = textField.resignFirstResponder()
    return true
  }
}
