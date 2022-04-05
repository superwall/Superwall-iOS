//
//  WelcomeViewController.swift
//  SuperwallUIKitExample
//
//  Created by Yusuf Tör on 05/04/2022.
//

import UIKit

final class WelcomeViewController: UIViewController {
  @IBOutlet private var textFieldBackgroundView: UIView!
  @IBOutlet private var textField: UITextField!

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = true
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    textFieldBackgroundView.layer.cornerRadius = textFieldBackgroundView.frame.height / 2
    UINavigationBar.appearance().titleTextAttributes = [
      .foregroundColor: UIColor.white,
      .font: UIFont.rubikBold(.five)
    ]
  }

  @IBAction private func showOptionsView() {
    if let name = textField.text {
      PaywallService.setName(to: name)
    }
    let optionsViewController = PaywallOptionsViewController.fromStoryboard()
    navigationController?.pushViewController(optionsViewController, animated: true)
  }
}
