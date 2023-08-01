//
//  SurveyManager.swift
//  Superwall-UIKit-Swift
//
//  Created by Yusuf Tör on 25/07/2023.
//
// swiftlint:disable function_body_length

import UIKit

enum SurveyManager {
  static func presentSurveyIfAvailable(
    _ survey: Survey?,
    using presenter: UIViewController?,
    paywallIsDeclined: Bool,
    paywallInfo: PaywallInfo,
    storage: Storage,
    completion: @escaping () -> Void
  ) {
    guard paywallIsDeclined else {
      completion()
      return
    }
    guard let survey = survey else {
      completion()
      return
    }

    let shouldPresent = survey.shouldPresent(storage: storage)

    // Make sure we don't assess this survey with this assignment key again.
    storage.save(survey.assignmentKey, forType: SurveyAssignmentKey.self)

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
    alertController.popoverPresentationController?.sourceView = presenter?.view

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
        // TODO: Sort out the ID here:
        let option = SurveyOption(id: "123", title: "Other")

        let otherAlertController = UIAlertController(
          title: option.title,
          message: nil,
          preferredStyle: .alert
        )
        otherAlertController.popoverPresentationController?.sourceView = presenter?.view
        otherAlertController.addTextField()

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

        otherAlertController.addAction(submitAction)

        alertController.dismiss(animated: true) {
          presenter?.present(otherAlertController, animated: true)
        }
      }
      alertController.addAction(otherAction)
    }

    presenter?.present(alertController, animated: true)
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
  }
}
