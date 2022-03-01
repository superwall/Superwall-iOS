//
//  File.swift
//  
//
//  Created by Jake Mor on 12/26/21.
//

import Foundation

struct EventsRequest: Codable {
	var events: [JSON]
}

struct EventsResponse: Codable {
	var status: String
}

struct EventData: Codable {
	var id: String
	var name: String
	var parameters: JSON
	var createdAt: String
	var jsonData: JSON {
		return [
			"event_id": JSON(id),
			"event_name": JSON(name),
			"parameters": parameters,
			"created_at": JSON(createdAt)
		]
	}
}
