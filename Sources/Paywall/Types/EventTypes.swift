//
//  File.swift
//  
//
//  Created by Jake Mor on 12/26/21.
//

import Foundation

internal struct EventsRequest: Codable {
	var events: [JSON]
}

internal struct EventsResponse: Codable {
	var status: String
}

internal struct EventData: Codable {
	var id: String
	var name: String
	var parameters: JSON
	var createdAt: String
	var jsonData: JSON {
		return [
			"event_id": JSON(id),
			"event_name": JSON(name),
			"parameters": parameters,
			"created_at": JSON(createdAt),
		]
	}
}
