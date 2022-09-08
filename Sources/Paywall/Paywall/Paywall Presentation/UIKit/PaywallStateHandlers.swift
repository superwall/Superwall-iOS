//
//  File.swift
//  
//
//  Created by Yusuf Tör on 07/09/2022.
//

import Foundation

public enum PaywallState {
  case presented(PaywallInfo)
  case dismissed(PaywallDismissedResult)
  case skipped(PaywallSkippedReason)
}
