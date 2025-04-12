//
//  File.swift
//  
//
//  Created by Yusuf Tör on 12/10/2022.
//

import UIKit

struct Action {
  let title: String
  let call: () -> Void
}

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
