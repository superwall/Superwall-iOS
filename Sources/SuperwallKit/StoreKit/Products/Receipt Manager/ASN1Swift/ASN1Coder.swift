//
//  ASN1Coder.swift
//  asn1swift
//
//  Created by Pavel Tikhonenko on 29.07.2020.
//

import Foundation

typealias ASN1Codable = ASN1Encodable & ASN1Decodable

protocol ASN1Encodable: Encodable { }
protocol ASN1Decodable: Decodable
{
	static var template: ASN1Template { get }
}

protocol ASN1CodingKey: CodingKey
{
	var template: ASN1Template { get }
	
	var hashValue: Int { get }
}

extension ASN1CodingKey
{
	func hash(into hasher: inout Hasher)
	{
		if let v = self.intValue
		{
			hasher.combine(v)
		}else{
			hasher.combine(self.stringValue)
		}
		
	}
}

