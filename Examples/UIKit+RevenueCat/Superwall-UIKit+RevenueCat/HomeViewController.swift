//
//  TrackEventViewController.swift
//  SuperwallUIKitExample
//
//  Created by Yusuf Tör on 05/04/2022.
//
// swiftlint:disable force_cast

import UIKit
import SuperwallKit
import RevenueCat
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

    // subscribe to subscriptionStatus changes
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
    if !Purchases.shared.isAnonymous {
      Task {
        try? await Purchases.shared.logOut()
      }
    }
    _ = self.navigationController?.popToRootViewController(animated: true)
  }

  @IBAction private func launchFeature() {
    let handler = PaywallPresentationHandler()
    handler.onDismiss { paywallInfo in
      print("The paywall dismissed. PaywallInfo:", paywallInfo)
    }
    handler.onPresent { paywallInfo in
      print("The paywall presented. PaywallInfo:", paywallInfo)
    }
    handler.onError { error in
      print("The paywall presentation failed with error \(error)")
    }
    handler.onSkip { reason in
      switch reason {
        case .userIsSubscribed:
          print("Paywall not shown because user is subscribed.")
        case .holdout(let experiment):
          print("Paywall not shown because user is in a holdout group in Experiment: \(experiment.id)")
        case .noRuleMatch:
          print("Paywall not shown because user doesn't match any rules.")
        case .eventNotFound:
          print("Paywall not shown because this event isn't part of a campaign.")
      }
    }

    Superwall.shared.register(event: "campaign_trigger", handler: handler) {
      // code in here can be remotely configured to execute. Either
      // (1) always after presentation or
      // (2) only if the user pays
      // code is always executed if no paywall is configured to show
      self.presentAlert(
        title: "Feature Launched",
        message: "Wrap your awesome features in register calls like this to remotely paywall your app. You can choose if these are paid features remotely."
      )
    }



    Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
      Task { @MainActor in
        do {
          let paywallVC = try await Superwall.shared.getPaywallViewController(forEvent: "campaign_trigger")


          paywallVC.onDismiss { result in
            print("[get paywall vc] paywall dismissed", result)
          }

          self.present(paywallVC, animated: true) {
            paywallVC.presentationDidFinish()
            print("[get paywall vc] paywall presented")
          }
        } catch let error  {

          print("[get paywall vc] unable to get paywall vc", error)
        }
      }
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
}


//extension UIViewController {
//  func present(_ viewControllerToPresent: PaywallViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
//    viewControllerToPresent.presentationWillBegin()
//
//    self.present(viewControllerToPresent as UIViewController, animated: flag) {
//      viewControllerToPresent.presentationDidFinish()
//      completion?()
//    }
//  }
//}


