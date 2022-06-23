//
//  PaywallOptionsViewController.swift
//  SuperwallUIKitExample
//
//  Created by Yusuf Tör on 05/04/2022.
//

import UIKit

final class PaywallOptionsViewController: UIViewController {
  @IBOutlet private var name: UILabel!

  static func fromStoryboard() -> PaywallOptionsViewController {
    let storyboard = UIStoryboard(
      name: "Main",
      bundle: nil
    )
    let controller = storyboard.instantiateViewController(
      withIdentifier: "PaywallOptionsViewController"
    ) as! PaywallOptionsViewController
    // swiftlint:disable:previous force_cast
    return controller
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.titleView = UIImageView(
      image: UIImage(named: "logo")
    )
    name.text = "Hi \(PaywallService.name)!"
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = false
  }
}
