//
//  ASN1Types.swift
//  asn1swift
//
//  Created by Pavel Tikhonenko on 27.07.2020.
//

import Foundation

struct ASN1Object
{
	var valueData: Data { Data(pointer: valuePtr, size: valueLength) }
	var rawData: Data { Data(pointer: dataPtr, size: dataLength) }
	var template: ASN1Template
	
	var dataPtr: UnsafePointer<UInt8>
	var dataLength: Int
	
	var valuePtr: UnsafePointer<UInt8> { return dataPtr + valuePosition }
	var valueLength: Int
	private var valuePosition: Int
	
	init(data: UnsafePointer<UInt8>, dataLength: Int, valuePosition: Int, valueLength: Int, template: ASN1Template)
	{
		self.dataPtr = data
		self.dataLength = dataLength
		self.valuePosition = valuePosition
		self.valueLength = valueLength
		self.template = template
	}
}

extension ASN1Object
{
	static func initialize(with data: UnsafePointer<UInt8>, length: Int, using template: ASN1Template) throws -> ASN1Object
	{
		let ptr = data
		var v: UnsafePointer<UInt8>!
		var vLength: Int = 0
		let c = try extractValue(from: ptr, length: length, with: template.expectedTags, value: &v, valueLength: &vLength)
		
		return ASN1Object(data: data, dataLength: c + vLength, valuePosition: c, valueLength: vLength, template: template)
	}
}

public typealias ASN1Tag = UInt8

public struct ASN1SkippedField: ASN1Decodable
{
	public var rawData: Data
	
	public static var template: ASN1Template { ASN1Template.universal(0) }
}

public struct ASN1Null: ASN1Decodable
{
	public static var template: ASN1Template { ASN1Template.universal(ASN1Identifier.Tag.null) }
}

extension ASN1Tag
{
	var unknown: ASN1Tag { 0 }
	
	func stringEncoding() -> String.Encoding
	{
		switch self
		{
		case ASN1Identifier.Tag.objectIdentifier:
			return .oid
		case ASN1Identifier.Tag.utf8String,
			 ASN1Identifier.Tag.printableString,
			 ASN1Identifier.Tag.numericString,
			 ASN1Identifier.Tag.generalString,
			 ASN1Identifier.Tag.universalString,
			 ASN1Identifier.Tag.characterString,
			 ASN1Identifier.Tag.t61String:
			return .utf8
		case ASN1Identifier.Tag.ia5String,
			 ASN1Identifier.Tag.utcTime,
			 ASN1Identifier.Tag.generalizedTime:
			return .ascii
		default:
			assertionFailure("We can't get a string encoding for this tag")
			return .ascii
		}
	}
}

public struct ASN1Identifier
{
	public struct Modifiers
	{
		public static let methodMask: UInt8 = 0x20
		public static let primitiv: UInt8 = 0x00
		public static let constructed: UInt8 = 0x20
		
		public static let classMask: UInt8 = 0xc0
		public static let universal: UInt8 = 0x00
		public static let application: UInt8 = 0x40
		public static let contextSpecific: UInt8 = 0x80
		public static let `private`: UInt8 = 0xc0
		
		public static let any: UInt32 = 0x00400
	}
	
	public struct Tag
	{
		public static let tagMask: UInt8 = 0xff
		public static let tagNumMask: UInt8 = 0x7f
		
		public static let endOfContent: ASN1Tag = 0x00
		public static let boolean: ASN1Tag = 0x01
		public static let integer: ASN1Tag = 0x02
		public static let bitString: ASN1Tag = 0x03
		public static let octetString: ASN1Tag = 0x04
		public static let null: ASN1Tag = 0x05
		public static let objectIdentifier: ASN1Tag = 0x06
		public static let objectDescriptor: ASN1Tag = 0x07
		public static let external: ASN1Tag = 0x08
		public static let read: ASN1Tag = 0x09
		public static let enumerated: ASN1Tag = 0x0A
		public static let embeddedPdv: ASN1Tag = 0x0B
		public static let utf8String: ASN1Tag = 0x0C
		public static let relativeOid: ASN1Tag = 0x0D
		public static let sequence: ASN1Tag = 0x10
		public static let set: ASN1Tag = 0x11
		public static let numericString: ASN1Tag = 0x12
		public static let printableString: ASN1Tag = 0x13
		public static let t61String: ASN1Tag = 0x14
		public static let videotexString: ASN1Tag = 0x15
		public static let ia5String: ASN1Tag = 0x16
		public static let utcTime: ASN1Tag = 0x17
		public static let generalizedTime: ASN1Tag = 0x18
		public static let graphicString: ASN1Tag = 0x19
		public static let visibleString: ASN1Tag = 0x1A
		public static let generalString: ASN1Tag = 0x1B
		public static let universalString: ASN1Tag = 0x1C
		public static let characterString: ASN1Tag = 0x1D
		public static let bmpString: ASN1Tag = 0x1E
		public static let highTag: ASN1Tag = 0x1f
			
		public init()
		{
			assertionFailure("You can't construct this struct")
		}
		
		public static func custom(raw: UInt8) -> ASN1Tag
		{
			return raw
		}
	}
	
	public enum Method: UInt8
	{
		case primitive = 0x00
		case constructed = 0x01
	}
	
	public enum Class: UInt8, RawRepresentable
	{
		case universal = 0x00 //0
		case application = 0x01 //1
		case contextSpecific = 0x02 //2
		case `private` = 0x03 //3
	}
}
