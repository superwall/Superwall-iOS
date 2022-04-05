//
//  OptionsTableViewController.swift
//  SuperwallUIKitExample
//
//  Created by Yusuf Tör on 05/04/2022.
//

import Foundation
import UIKit

final class OptionsTableViewController: UITableViewController {
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(
      at: indexPath,
      animated: true
    )

    switch indexPath.row {
    case 0:
      navigationController?.pushViewController(
        PresentPaywallViewController.fromStoryboard(),
        animated: true
      )
    case 1:
      navigationController?.pushViewController(
        ExplicitlyTriggerPaywallViewController.fromStoryboard(),
        animated: true
      )
    case 2:
      navigationController?.pushViewController(
        ImplicitlyTriggerPaywallViewController.fromStoryboard(),
        animated: true
      )
    default:
      break
    }
  }
}
