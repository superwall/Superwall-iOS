//
//  ASN1Templates.swift
//  asn1swift
//
//  Created by Pavel Tikhonenko on 29.07.2020.
//

import Foundation

public class ASN1Template
{
	var expectedTags: [ASN1Tag] = []
	
	fileprivate init(kind: ASN1Tag)
	{
		expectedTags.append(kind)
	}
	
	public func implicit(tag: ASN1Tag) -> ASN1Template
	{
		return self
	}
	
	public func explicit(tag: ASN1Tag) -> ASN1Template
	{
		expectedTags.append(tag)
		
		return self
	}
	
	public func constructed() -> ASN1Template
	{
		if expectedTags.isEmpty
		{
			expectedTags.append(0)
		}
		
		if var last = expectedTags.last
		{
			last |= ASN1Identifier.Modifiers.constructed
			expectedTags[expectedTags.count - 1] = last
		}
		
		return self
	}
}

public extension ASN1Template
{
	static func contextSpecific(_ id: ASN1Tag) -> ASN1Template
	{
		return ASN1Template(kind: ASN1Identifier.Modifiers.contextSpecific | id)
	}
	
	static func universal(_ tag: ASN1Tag) -> ASN1Template
	{
		return ASN1Template(kind: ASN1Identifier.Modifiers.universal | tag)
	}
	
	var stringEncoding: String.Encoding
	{
		for tag in expectedTags
		{
			if tag & 0xc0 != 0 // Skip iff not universal
			{
				continue
			}
			
			return (tag as ASN1Tag).stringEncoding()
		}
		
		assertionFailure("This template should be treated as a string")
		return .utf8
	}
}
