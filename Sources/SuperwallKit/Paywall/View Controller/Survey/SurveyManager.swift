//
//  SurveyManager.swift
//  Superwall-UIKit-Swift
//
//  Created by Yusuf Tör on 25/07/2023.
//
// swiftlint:disable function_body_length

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// UIKit text field actions require an Objective-C class target.
// swiftlint:disable:next convenience_type
final class SurveyManager {
  static func presentSurveyIfAvailable(
    _ surveys: [Survey],
    paywallResult: PaywallResult,
    paywallCloseReason: PaywallCloseReason,
    using presenter: PaywallViewController,
    loadingState: PaywallLoadingState,
    isDebuggerLaunched: Bool,
    paywallInfo: PaywallInfo,
    storage: Storage,
    factory: TriggerFactory,
    completion: @escaping (SurveyPresentationResult) -> Void
  ) {
    guard let survey = selectSurvey(
      from: surveys,
      paywallResult: paywallResult,
      paywallCloseReason: paywallCloseReason
    ) else {
      completion(.noShow)
      return
    }

    guard
      loadingState == .ready || loadingState == .loadingPurchase
    else {
      completion(.noShow)
      return
    }
    if survey.hasSeenSurvey(storage: storage) {
      completion(.noShow)
      return
    }

    let isHoldout = survey.shouldAssignHoldout(
      isDebuggerLaunched: isDebuggerLaunched,
      storage: storage
    )

    if !isDebuggerLaunched {
      // Make sure we don't assess this survey with this assignment key again.
      storage.save(survey.assignmentKey, forType: SurveyAssignmentKey.self)
    }

    if isHoldout {
      Logger.debug(
        logLevel: .info,
        scope: .paywallViewController,
        message: "The survey will not present."
      )
      completion(.holdout)
      return
    }

    let options = survey.options.shuffled()
    let onResponse = { (option: SurveyOption, customResponse: String?) in
      recordResponse(
        option,
        fromSurvey: survey,
        withCustomResponse: customResponse,
        paywallInfo: paywallInfo,
        factory: factory,
        paywallViewController: presenter,
        completion: completion
      )
    }
    let onClose = {
      Task {
        let surveyClose = InternalSuperwallEvent.SurveyClose()
        await Superwall.shared.track(surveyClose)
      }
      completion(.show)
    }

    presentSurvey(
      survey,
      options: options,
      on: presenter,
      onResponse: onResponse,
      onClose: onClose
    )
  }

  /// Tracks the response, then completes unless it triggers another paywall.
  static private func recordResponse(
    _ option: SurveyOption,
    fromSurvey survey: Survey,
    withCustomResponse customResponse: String?,
    paywallInfo: PaywallInfo,
    factory: TriggerFactory,
    paywallViewController: PaywallViewController,
    completion: @escaping (SurveyPresentationResult) -> Void
  ) {
    // Always complete without tracking if debugger launched.
    Task {
      let surveyResponse = InternalSuperwallEvent.SurveyResponse(
        survey: survey,
        selectedOption: option,
        customResponse: customResponse,
        paywallInfo: paywallInfo
      )
      await Superwall.shared.track(surveyResponse)

      let outcome = await TrackingLogic.canTriggerPaywall(
        surveyResponse,
        triggers: factory.makeTriggers(),
        paywallViewController: paywallViewController
      )

      // If we are going to implicitly show another paywall, we don't call the completion
      // block as this will call didDismiss, which is going to be called
      // implicitly anyway.
      if outcome == .dontTriggerPaywall {
        await MainActor.run {
          completion(.show)
        }
      }
    }
  }

  private static func selectSurvey(
    from surveys: [Survey],
    paywallResult: PaywallResult,
    paywallCloseReason: PaywallCloseReason
  ) -> Survey? {
    let isPurchased: Bool
    switch paywallResult {
    case .purchased:
      isPurchased = true
    default:
      isPurchased = false
    }
    let isDeclined = paywallResult == .declined
    let isManualClose = paywallCloseReason == .manualClose

    let onManualClose = isDeclined && isManualClose
    let onPurchase = isPurchased

    for survey in surveys {
      switch survey.presentationCondition {
      case .onManualClose:
        if onManualClose {
          return survey
        }
      case .onPurchase:
        if onPurchase {
          return survey
        }
      }
    }

    return nil
  }
}

#if os(macOS)
extension SurveyManager {
  /// Shows the survey as an alert sheet with a button for each option.
  ///
  /// "Other" asks for the response in a second alert, whose Submit button
  /// stays off until something's been typed. Without a close option there's
  /// no button that skips the survey, as on iOS.
  static private func presentSurvey(
    _ survey: Survey,
    options: [SurveyOption],
    on presenter: PaywallViewController,
    onResponse: @escaping (SurveyOption, String?) -> Void,
    onClose: @escaping () -> Void
  ) {
    let alert = NSAlert()
    alert.messageText = survey.title
    alert.informativeText = survey.message
    for option in options {
      alert.addButton(withTitle: option.title)
    }
    let otherIndex = survey.includeOtherOption ? options.count : nil
    if survey.includeOtherOption {
      alert.addButton(withTitle: "Other")
    }
    if survey.includeCloseOption {
      let closeButton = alert.addButton(withTitle: "Close")
      closeButton.keyEquivalent = "\u{1b}"
    }

    run(alert, on: presenter) { index in
      if options.indices.contains(index) {
        onResponse(options[index], nil)
      } else if index == otherIndex {
        presentOtherResponse(for: survey, on: presenter, onResponse: onResponse)
      } else {
        onClose()
      }
    }
  }

  static private func presentOtherResponse(
    for survey: Survey,
    on presenter: PaywallViewController,
    onResponse: @escaping (SurveyOption, String?) -> Void
  ) {
    let alert = NSAlert()
    alert.messageText = survey.title
    alert.informativeText = survey.message
    let submitButton = alert.addButton(withTitle: "Submit")
    submitButton.isEnabled = false

    let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
    textField.placeholderString = "Your response"
    alert.accessoryView = textField
    let observer = NotificationCenter.default.addObserver(
      forName: NSControl.textDidChangeNotification,
      object: textField,
      queue: .main
    ) { _ in
      let text = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
      submitButton.isEnabled = !text.isEmpty
    }
    alert.window.initialFirstResponder = textField

    run(alert, on: presenter) { _ in
      NotificationCenter.default.removeObserver(observer)
      let option = SurveyOption(id: "000", title: "Other")
      onResponse(option, textField.stringValue)
    }
  }

  /// Shows `alert` on the paywall's window and reports which button was
  /// pressed, counting from zero.
  static private func run(
    _ alert: NSAlert,
    on presenter: PaywallViewController,
    onButton: @escaping (Int) -> Void
  ) {
    let handleResponse = { (response: NSApplication.ModalResponse) in
      onButton(response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue)
    }
    if let window = presenter.view.window {
      alert.beginSheetModal(for: window, completionHandler: handleResponse)
    } else {
      handleResponse(alert.runModal())
    }
  }
}
#else
extension SurveyManager {
  static private var otherAlertController: UIAlertController?

  static private func presentSurvey(
    _ survey: Survey,
    options: [SurveyOption],
    on presenter: PaywallViewController,
    onResponse: @escaping (SurveyOption, String?) -> Void,
    onClose: @escaping () -> Void
  ) {
    // Create alert controller and add options.
    let alertController = UIAlertController(
      title: survey.title,
      message: survey.message,
      preferredStyle: .actionSheet
    )
    if presenter.traitCollection.userInterfaceIdiom == .pad,
      let popover = alertController.popoverPresentationController {
      let sourceView: UIView
      if let rootView = presenter.view.window?.rootViewController?.view {
        sourceView = rootView
      } else {
        sourceView = presenter.view
      }
      popover.sourceView = sourceView
      popover.sourceRect = CGRect(
        x: sourceView.bounds.midX,
        y: sourceView.bounds.midY,
        width: 0,
        height: 0
      )
      popover.permittedArrowDirections = []
    }
    alertController.isModalInPresentation = true

    for option in options {
      let action = UIAlertAction(
        title: option.title,
        style: .default
      ) { _ in
        alertController.dismiss(animated: true) {
          onResponse(option, nil)
        }
        otherAlertController = nil
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
          otherAlertController.dismiss(animated: true) {
            onResponse(option, response)
          }
          self.otherAlertController = nil
        }
        submitAction.isEnabled = false

        otherAlertController.addAction(submitAction)

        alertController.dismiss(animated: true) {
          presenter.present(otherAlertController, animated: true)
        }
      }
      alertController.addAction(otherAction)
    }

    if survey.includeCloseOption {
      let closeButton = UIAlertAction(title: "Close", style: .cancel) { _ in
        onClose()
      }
      alertController.addAction(closeButton)
    }

    presenter.present(alertController, animated: true)
  }

  @objc
  static private func alertTextFieldDidChange(_ sender: UITextField) {
    if let text = sender.text {
      let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
      otherAlertController?.actions[0].isEnabled = !text.isEmpty
    }
  }
}
#endif
