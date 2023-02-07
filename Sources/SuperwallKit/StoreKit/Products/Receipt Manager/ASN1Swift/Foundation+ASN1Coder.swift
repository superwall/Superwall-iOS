//
//  File.swift
//  
//
//  Created by Pavel Tikhonenko on 04.08.2020.
//

import Foundation

extension String: ASN1Decodable
{
	public static var template: ASN1Template
	{
		return ASN1Template.universal(ASN1Identifier.Tag.utf8String)
	}
}

extension Int: ASN1Decodable
{
	public static var template: ASN1Template
	{
		return ASN1Template.universal(2)
	}
}

extension Int32: ASN1Decodable
{
	public static var template: ASN1Template
	{
		return ASN1Template.universal(2)
	}
}

extension Data: ASN1Decodable
{
	public static var template: ASN1Template
	{
		assertionFailure("Provide template")
		return ASN1Template.universal(0)
		
	}
}

extension String.Encoding
{
	public var template: ASN1Template
	{
		switch self
		{
		case .ascii:
			return ASN1Template.universal(ASN1Identifier.Tag.ia5String)
		case .utf8:
			return ASN1Template.universal(ASN1Identifier.Tag.utf8String)
		case .oid:
			return ASN1Template.universal(ASN1Identifier.Tag.objectIdentifier)
		default:
			assertionFailure("Provide template for this encoding")
			break
		}
		
		assertionFailure("Provide template")
		return ASN1Template.universal(0)
		
	}
	
	static var oid: String.Encoding = String.Encoding(rawValue: 360)
}

extension Data
{
	init(pointer: UnsafePointer<UInt8>, size: Int)
	{
		let ptr = UnsafeMutableRawPointer(mutating: pointer)
		
		if size == 0
		{
			self = Data()
		}else{
			self = Data(bytesNoCopy: ptr, count: size, deallocator: .none)
		}
	}
}
