//
//  File.swift
//  
//
//  Created by brian on 7/28/21.
//

import Foundation
import Logging

internal func log(_ items: Any...) {
    if (Paywall.debugLogsEnabled){
        print("Paywall Debug", items)
    }
}

