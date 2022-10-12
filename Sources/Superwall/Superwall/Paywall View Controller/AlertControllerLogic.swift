//
//  File.swift
//  
//
//  Created by Yusuf Tör on 12/10/2022.
//

import UIKit

enum AlertControllerFactory {
  static func create(
    title: String,
    message: String,
    actionTitle: String? = nil,
    closeActionTitle: String = "Done",
    closeActionStyle: UIAlertAction.Style = .cancel,
    action: (() -> Void)? = nil,
    onClose: (() -> Void)? = nil
  ) -> UIAlertController {
    let alertController = UIAlertController(
      title: title,
      message: message,
      preferredStyle: .alert
    )

    if let actionTitle = actionTitle {
      let alertAction = UIAlertAction(
        title: actionTitle,
        style: .default
      ) { _ in
        action?()
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

    return alertController
  }
}
