//
//  ImplicitlyTriggerPaywallViewController.swift
//  SuperwallUIKitExample
//
//  Created by Yusuf Tör on 05/04/2022.
//

import UIKit
import Paywall
import Combine

final class ImplicitlyTriggerPaywallViewController: UIViewController {
  @IBOutlet private var countLabel: UILabel!
  @IBOutlet private var subscriptionLabel: UILabel!
  private var count = 0 {
    didSet {
      countLabel.text = "Count: \(count)"
      if count == 3 {
        Paywall.track("MyEvent")
      }
    }
  }
  private var cancellables: Set<AnyCancellable> = []

  static func fromStoryboard() -> ImplicitlyTriggerPaywallViewController {
    let storyboard = UIStoryboard(
      name: "Main",
      bundle: nil
    )
    let controller = storyboard.instantiateViewController(
      withIdentifier: "ImplicitlyTriggerPaywallViewController"
    ) as! ImplicitlyTriggerPaywallViewController
    // swiftlint:disable:previous force_cast

    return controller
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    StoreKitService.shared.isSubscribed
      .sink { [weak self] isSubscribed in
        if isSubscribed {
          self?.subscriptionLabel.text = "You currently have an active subscription. Therefore, the paywall will never show. For the purposes of this app, delete and reinstall the app to clear subscriptions."
        } else {
          self?.subscriptionLabel.text = "You do not have an active subscription so the paywall will show when the counter reaches 3."
        }
      }
      .store(in: &cancellables)
  }

  @IBAction private func incrementCount() {
    count += 1
  }

  @IBAction private func resetCount() {
    count = 0
  }
}
