//
//  TrackEventViewController.swift
//  SuperwallUIKitExample
//
//  Created by Yusuf Tör on 05/04/2022.
//
// swiftlint:disable force_cast

import UIKit
import SuperwallKit
import Combine

final class HomeViewController: UIViewController {
  @IBOutlet private var subscriptionLabel: UILabel!
  private var subscribedCancellable: AnyCancellable?
  private var cancellable: AnyCancellable?

  static func fromStoryboard() -> HomeViewController {
    let storyboard = UIStoryboard(
      name: "Main",
      bundle: nil
    )
    let controller = storyboard.instantiateViewController(
      withIdentifier: "HomeViewController"
    ) as! HomeViewController

    return controller
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = false
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    // Subscribe to subscriptionStatus changes
    subscribedCancellable = Superwall.shared.$subscriptionStatus
      .receive(on: DispatchQueue.main)
      .sink { [weak self] status in
        switch status {
        case .unknown:
          self?.subscriptionLabel.text = "Loading subscription status."
        case .active:
          self?.subscriptionLabel.text = "You currently have an active subscription. Therefore, the paywall will never show. For the purposes of this app, delete and reinstall the app to clear subscriptions."
        case .inactive:
          self?.subscriptionLabel.text = "You do not have an active subscription so the paywall will show when clicking the button."
        }
      }


    navigationItem.hidesBackButton = true
  }

  @IBAction private func logOut() {
    Superwall.shared.reset()
    _ = self.navigationController?.popToRootViewController(animated: true)
  }

  @IBAction private func launchFeature() {
    let handler = PaywallPresentationHandler()
    handler.onDismiss = { paywallInfo in
      print("The paywall dismissed. PaywallInfo:", paywallInfo)
    }
    handler.onPresent = { paywallInfo in
      print("The paywall presented. PaywallInfo:", paywallInfo)
    }
    handler.onError = { error in
      print("The paywall presentation failed with error \(error)")
    }
    Superwall.shared.register(event: "campaign_trigger", handler: handler) {
      // code in here can be remotely configured to execute. Either
      // (1) always after presentation or
      // (2) only if the user pays
      // code is always executed if no paywall is configured to show
      self.presentAlert(
        title: "Feature Launched",
        message: "Wrap your awesome features in register calls like this to remotely paywall your app. You can remotely decide whether these are paid features."
      )
    }
  }

  private func presentAlert(title: String, message: String) {
    let alertController = UIAlertController(
      title: title,
      message: message,
      preferredStyle: .alert
    )
    let okAction = UIAlertAction(title: "OK", style: .default) { _ in }
    alertController.addAction(okAction)
    alertController.popoverPresentationController?.sourceView = view
    self.present(alertController, animated: true)
  }
}
