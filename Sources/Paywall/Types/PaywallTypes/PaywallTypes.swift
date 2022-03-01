//
//  File.swift
//  
//
//  Created by Jake Mor on 12/26/21.
//
import Foundation
import UIKit

struct PaywallRequest: Codable {
	var appUserId: String
}

struct PaywallFromEventRequest: Codable {
	var appUserId: String
	var event: EventData?
}

struct PaywallsResponse: Decodable {
	var paywalls: [PaywallResponse]
}

struct Variable: Decodable {
	var key: String
	var value: JSON
}

struct ProductVariable: Decodable {
	var key: String
	var value: JSON
}

enum PaywallPresentationStyle: String, Decodable {
	case sheet = "SHEET"
	case modal = "MODAL"
	case fullscreen = "FULLSCREEN"
}
