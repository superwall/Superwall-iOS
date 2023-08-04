//
//  SurveyManager.swift
//  Superwall-UIKit-Swift
//
//  Created by Yusuf Tör on 25/07/2023.
//
// swiftlint:disable function_body_length

import UIKit

final class SurveyManager {
  static private var otherAlertController: UIAlertController?

  static func presentSurveyIfAvailable(
    _ survey: Survey?,
    using presenter: UIViewController,
    loadingState: PaywallLoadingState,
    paywallIsManuallyDeclined: Bool,
    isDebuggerLaunched: Bool,
    paywallInfo: PaywallInfo,
    storage: Storage,
    completion: @escaping () -> Void
  ) {
    guard loadingState == .ready else {
      completion()
      return
    }
    guard paywallIsManuallyDeclined else {
      completion()
      return
    }
    guard let survey = survey else {
      completion()
      return
    }

    let shouldPresent = survey.shouldPresent(
      isDebuggerLaunched: isDebuggerLaunched,
      storage: storage
    )

    if !isDebuggerLaunched {
      // Make sure we don't assess this survey with this assignment key again.
      storage.save(survey.assignmentKey, forType: SurveyAssignmentKey.self)
    }

    guard shouldPresent else {
      Logger.debug(
        logLevel: .info,
        scope: .paywallViewController,
        message: "The survey will not present."
      )
      completion()
      return
    }

    let options = survey.options.shuffled()

    // Create alert controller and add options.
    let alertController = UIAlertController(
      title: survey.title,
      message: survey.message,
      preferredStyle: .actionSheet
    )
    alertController.popoverPresentationController?.sourceView = presenter.view
    // Calculate the center of the view
    let centerX = presenter.view.bounds.midX
    let centerY = presenter.view.bounds.minY

    // Set the sourceRect to center the popover
    alertController.popoverPresentationController?.sourceRect = CGRect(x: centerX, y: centerY, width: 0, height: 0)
    alertController.isModalInPresentation = true

    for option in options {
      let action = UIAlertAction(
        title: option.title,
        style: .default
      ) { _ in
        selectedOption(
          option,
          fromSurvey: survey,
          withCustomResponse: nil,
          paywallInfo: paywallInfo,
          alertController: alertController,
          completion: completion
        )
      }
      alertController.addAction(action)
    }

    if survey.includeOtherOption {
      let otherAction = UIAlertAction(
        title: "Other",
        style: .default
      ) { _ in
        let option = SurveyOption(id: "000", title: "Other")

        let otherAlertController = UIAlertController(
          title: survey.title,
          message: survey.message,
          preferredStyle: .alert
        )
        self.otherAlertController = otherAlertController
        otherAlertController.popoverPresentationController?.sourceView = presenter.view
        otherAlertController.addTextField { textField in
          textField.addTarget(
            self,
            action: #selector(alertTextFieldDidChange(_:)),
            for: .editingChanged
          )
          textField.placeholder = "Your response"
        }

        let submitAction = UIAlertAction(title: "Submit", style: .default) { _ in
          let textField = otherAlertController.textFields?[0]
          let response = textField?.text
          selectedOption(
            option,
            fromSurvey: survey,
            withCustomResponse: response,
            paywallInfo: paywallInfo,
            alertController: otherAlertController,
            completion: completion
          )
        }
        submitAction.isEnabled = false

        otherAlertController.addAction(submitAction)

        alertController.dismiss(animated: true) {
          presenter.present(otherAlertController, animated: true)
        }
      }
      alertController.addAction(otherAction)
    }

    presenter.present(alertController, animated: true)
  }

  static private func selectedOption(
    _ option: SurveyOption,
    fromSurvey survey: Survey,
    withCustomResponse customResponse: String?,
    paywallInfo: PaywallInfo,
    alertController: UIAlertController,
    completion: @escaping () -> Void
  ) {
    alertController.dismiss(animated: true) {
      Task {
        await Superwall.shared.track(
          InternalSuperwallEvent.SurveyResponse(
            survey: survey,
            selectedOption: option,
            customResponse: customResponse,
            paywallInfo: paywallInfo
          )
        )
      }
      completion()
    }
    otherAlertController = nil
  }

  @objc
  static private func alertTextFieldDidChange(_ sender: UITextField) {
    if let text = sender.text {
      let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
      otherAlertController?.actions[0].isEnabled = !text.isEmpty
    }
  }
}
