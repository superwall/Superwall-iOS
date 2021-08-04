//
//  File.swift
//  
//
//  Created by Brian Anglin on 8/3/21.
//

import Foundation

class Store {
    public static let shared = Store();
    public var apiKey: String?
    public var appUserId: String?
}
