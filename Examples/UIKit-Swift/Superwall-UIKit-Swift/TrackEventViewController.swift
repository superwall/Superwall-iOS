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

final class TrackEventViewController: UIViewController {
  @IBOutlet private var subscriptionLabel: UILabel!
  private var subscribedCancellable: AnyCancellable?
  private var cancellable: AnyCancellable?

  static func fromStoryboard() -> TrackEventViewController {
    let storyboard = UIStoryboard(
      name: "Main",
      bundle: nil
    )
    let controller = storyboard.instantiateViewController(
      withIdentifier: "TrackEventViewController"
    ) as! TrackEventViewController

    return controller
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.isNavigationBarHidden = false
  }

  override func viewDidLoad() {
    super.viewDidLoad()

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
    UserDefaults.standard.setValue(false, forKey: "IsLoggedIn")
    SuperwallService.reset()
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
      self.presentAlert(title: "Feature Launched", message: "wrap your awesome features in register calls like this to remotely paywall your app. You can choose if these are paid features remotely.")
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
    alertController.popoverPresentationController?.sourceView = self.view
    self.present(alertController, animated: true)
  }

  // The below function gives an example of how to track an event using Combine publishers:
  /*
  func trackEventUsingCombine() {
    cancellable = Superwall.shared
      .publisher(forEvent: "MyEvent")
      .sink { paywallState in
        switch paywallState {
        case .presented(let paywallInfo):
          print("paywall info is", paywallInfo)
        case .dismissed(let result):
          switch result.state {
          case .closed:
            print("User dismissed the paywall.")
          case .purchased(productId: let productId):
            print("Purchased a product with id \(productId), then dismissed.")
          case .restored:
            print("Restored purchases, then dismissed.")
          }
        case .skipped(let reason):
          switch reason {
          case .noRuleMatch:
            print("The user did not match any rules")
          case .holdout(let experiment):
            print("The user is in a holdout group, with experiment id: \(experiment.id), group id: \(experiment.groupId), paywall id: \(experiment.variant.paywallId ?? "")")
          case .eventNotFound:
            print("The event wasn't found in a campaign on the dashboard.")
          case .userIsSubscribed:
            print("The user is subscribed.")
          case .error(let error):
            print("Failed to present paywall. Consider a native paywall fallback", error)
          }
        }
      }
  }
  */
}
