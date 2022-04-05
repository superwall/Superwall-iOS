//
//  PresentPaywallViewController.swift
//  SuperwallUIKitExample
//
//  Created by Yusuf Tör on 05/04/2022.
//

import UIKit
import Paywall
import Combine

final class PresentPaywallViewController: UIViewController {
  @IBOutlet private var subscriptionLabel: UILabel!
  private var cancellables: Set<AnyCancellable> = []

  static func fromStoryboard() -> PresentPaywallViewController {
    let storyboard = UIStoryboard(
      name: "Main",
      bundle: nil
    )
    let controller = storyboard.instantiateViewController(
      withIdentifier: "PresentPaywallViewController"
    ) as! PresentPaywallViewController
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
          self?.subscriptionLabel.text = "You do not have an active subscription so the paywall will show when clicking the button."
        }
      }
      .store(in: &cancellables)
  }

  @IBAction private func presentPaywall() {
    Paywall.present { paywallInfo in
      print("The paywall did present. The paywallInfo object is", paywallInfo)
    } onDismiss: { didPurchase, productId, paywallInfo in
      if didPurchase {
        print("The purchased product ID is", productId)
      } else {
        print("The info of the paywall is", paywallInfo)
      }
    } onFail: { error in
      print("did fail", error)
    }
  }
}
