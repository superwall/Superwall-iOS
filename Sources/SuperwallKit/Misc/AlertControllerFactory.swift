//
//  File.swift
//  
//
//  Created by Yusuf Tör on 12/10/2022.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct Action {
  let title: String
  let call: () -> Void
}

#if os(macOS)
enum AlertControllerFactory {
  /// Shows an alert as a sheet on the view controller's window, or app-modally
  /// when it isn't in one.
  ///
  /// The action buttons come first so the first of them answers Return, as the
  /// main action on a Mac does. When there are actions, the close button
  /// answers Escape. Each button calls what its `UIAlertController`
  /// counterpart would: an action's `call`, or `onClose`.
  @MainActor
  static func present(
    title: String? = nil,
    message: String? = nil,
    closeActionTitle: String = "Done",
    actions: [Action] = [],
    onClose: (() -> Void)? = nil,
    on viewController: NSViewController?
  ) {
    let alert = NSAlert()
    alert.messageText = title ?? ""
    alert.informativeText = message ?? ""
    for action in actions {
      alert.addButton(withTitle: action.title)
    }
    let closeButton = alert.addButton(withTitle: closeActionTitle)
    if !actions.isEmpty {
      closeButton.keyEquivalent = "\u{1b}"
    }

    let handleResponse = { (response: NSApplication.ModalResponse) in
      let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
      if actions.indices.contains(index) {
        actions[index].call()
      } else {
        onClose?()
      }
    }

    if let window = viewController?.view.window {
      alert.beginSheetModal(for: window, completionHandler: handleResponse)
    } else {
      handleResponse(alert.runModal())
    }
  }
}
#else
enum AlertControllerFactory {
  static func make(
    title: String? = nil,
    message: String? = nil,
    closeActionTitle: String = "Done",
    closeActionStyle: UIAlertAction.Style = .cancel,
    actions: [Action] = [],
    onClose: (() -> Void)? = nil,
    sourceView: UIView
  ) -> UIAlertController {
    let alertController = UIAlertController(
      title: title,
      message: message,
      preferredStyle: .alert
    )

    for action in actions {
      let alertAction = UIAlertAction(
        title: action.title,
        style: .default
      ) { _ in
        action.call()
      }
      alertController.addAction(alertAction)
    }

    let action = UIAlertAction(
      title: closeActionTitle,
      style: closeActionStyle
    ) { _ in
      onClose?()
    }
    alertController.addAction(action)
    alertController.popoverPresentationController?.sourceView = sourceView

    return alertController
  }
}
#endif
