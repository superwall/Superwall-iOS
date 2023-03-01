//
//  File.swift
//  
//
//  Created by Pavel Tikhonenko on 07.08.2020.
//

import Foundation

// MARK: ASN1UnkeyedDecodingContainer

public protocol ASN1UnkeyedDecodingContainerProtocol: UnkeyedDecodingContainer
{
	var rawData: Data { get }
	var valueData: Data { get }
	
	mutating func decode(_ type: String.Type, template: ASN1Template) throws -> String
	mutating func decode<T>(_ type: T.Type, template: ASN1Template) throws -> T where T: Decodable
	mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, for template: ASN1Template) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey
	mutating func nestedUnkeyedContainer(for template: ASN1Template) throws -> UnkeyedDecodingContainer
	
	mutating func skip(template: ASN1Template) throws
}

extension ASN1UnkeyedDecodingContainer: ASN1UnkeyedDecodingContainerProtocol
{
	/// Raw data
	var rawData: Data { return container.rawData }
	var valueData: Data { return container.valueData }
	
	mutating func decode(_ type: String.Type, template: ASN1Template) throws -> String
	{
		guard !self.isAtEnd else
		{
			throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Unkeyed container is at end."))
		}
		
		self.decoder.codingPath.append(ASN1Key(index: self.currentIndex))
		defer { self.decoder.codingPath.removeLast() }
		
		let obj = try _objToUnbox(from: template)

		guard let value = try self.decoder.unbox(obj, as: String.self) else
		{
			throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
		}
		
		return value
	}
	
	mutating func decode(_ type: Int.Type, template: ASN1Template) throws -> Int
	{
		guard !self.isAtEnd else
		{
			throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Unkeyed container is at end."))
		}
		
		self.decoder.codingPath.append(ASN1Key(index: self.currentIndex))
		defer { self.decoder.codingPath.removeLast() }
		
		guard let value = try self.decoder.unbox(_objToUnbox(from: template), as: Int.self) else
		{
			throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
		}
		
		return value
		
	}
	
	mutating func decode<T>(_ type: T.Type, template: ASN1Template) throws -> T where T: Decodable
	{
		guard !self.isAtEnd else
		{
			throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Unkeyed container is at end."))
		}
		
		self.decoder.codingPath.append(ASN1Key(index: self.currentIndex))
		defer { self.decoder.codingPath.removeLast() }
		
		guard let value = try self.decoder.unbox(_objToUnbox(from: template), as: T.self) else
		{
			throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
		}
		
		return value
	}
	
	mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, for template: ASN1Template) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey
	{
		guard !self.isAtEnd else
		{
			throw DecodingError.valueNotFound(Any.self, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Unkeyed container is at end."))
		}
		
		self.decoder.codingPath.append(ASN1Key(index: self.currentIndex))
		defer { self.decoder.codingPath.removeLast() }
		
		let obj = try _objToUnbox(from: template)
		
		let container = try ASN1KeyedDecodingContainer<NestedKey>(referencing: self.decoder, wrapping: obj)
		return KeyedDecodingContainer(container)
	}
	
	mutating func nestedUnkeyedContainer(for template: ASN1Template) throws -> UnkeyedDecodingContainer
	{
		guard !self.isAtEnd else
		{
			throw DecodingError.valueNotFound(Any.self, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Unkeyed container is at end."))
		}
		
		self.decoder.codingPath.append(ASN1Key(index: self.currentIndex))
		defer { self.decoder.codingPath.removeLast() }
		
		let obj = try _objToUnbox(from: template)
		
		return try ASN1UnkeyedDecodingContainer(referencing: self.decoder, wrapping: obj)
	}
	
	mutating func skip(template: ASN1Template) throws
	{
		guard !self.isAtEnd else
		{
			throw DecodingError.valueNotFound(Any.self, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Unkeyed container is at end."))
		}
		
		let bytesToSkip = try consume(from: self.state.dataPtr, length: self.state.left, expectedTags: template.expectedTags)
		self.state.advance(bytesToSkip)
		self.currentIndex += 1
	}
}

internal struct ASN1UnkeyedDecodingContainer
{
	private let decoder: _ASN1Decoder
	private let container: ASN1Object
	private let state: _ASN1Decoder.State
	
	/// The path of coding keys taken to get to this point in decoding.
	public var codingPath: [CodingKey]
	
	/// The index of the element we're about to decode.
	private(set) public var currentIndex: Int
	
	var count: Int?
	
	var isAtEnd: Bool
	{
		return state.isAtEnd
	}
	
	init(referencing decoder: _ASN1Decoder, wrapping container: ASN1Object) throws
	{
		self.decoder = decoder
		
		self.codingPath = decoder.codingPath
		self.currentIndex = 0
		
		self.container = container
		self.state = _ASN1Decoder.State(obj: container)
	}
	
	mutating func decodeNil() throws -> Bool
	{
		assertionFailure("Hasn't implemented yet")
		return true
	}
	
	mutating func decode(_ type: Bool.Type) throws -> Bool
	{
		assertionFailure("Hasn't implemented yet")
		return false
	}
	
	mutating func decode(_ type: String.Type, using stringEncoding: String.Encoding) throws -> String
	{
		guard !self.isAtEnd else
		{
			throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Unkeyed container is at end."))
		}
		
		self.decoder.codingPath.append(ASN1Key(index: self.currentIndex))
		defer { self.decoder.codingPath.removeLast() }
		
		let obj = try ASN1Object.initialize(with: self.state.dataPtr, length: self.state.left, using: stringEncoding.template)
		self.state.advance(obj.dataLength)
		self.currentIndex += 1
		
		guard let value = try self.decoder.unbox(obj, as: String.self) else
		{
			throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
		}
		
		return value
		
	}
	
	mutating func decode(_ type: String.Type) throws -> String
	{
		return try decode(type, using: .utf8)

	}
	
	mutating func decode(_ type: Double.Type) throws -> Double
	{
		assertionFailure("Hasn't implemented yet")
		return 0
	}
	
	mutating func decode(_ type: Float.Type) throws -> Float
	{
		assertionFailure("Hasn't implemented yet")
		return 0
	}
	
	mutating func decode(_ type: Int.Type) throws -> Int
	{
		guard !self.isAtEnd else
		{
			throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Unkeyed container is at end."))
		}
		
		self.decoder.codingPath.append(ASN1Key(index: self.currentIndex))
		defer { self.decoder.codingPath.removeLast() }
		
		guard let value = try self.decoder.unbox(objToUnbox(type), as: Int.self) else
		{
			throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
		}
		
		return value

	}
	
	mutating func decode(_ type: Int8.Type) throws -> Int8
	{
		return try Int8(decode(Int.self))
	}
	
	mutating func decode(_ type: Int16.Type) throws -> Int16
	{
		return try Int16(decode(Int.self))
	}
	
	mutating func decode(_ type: Int32.Type) throws -> Int32
	{
		guard !self.isAtEnd else
		{
			throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Unkeyed container is at end."))
		}
		
		self.decoder.codingPath.append(ASN1Key(index: self.currentIndex))
		defer { self.decoder.codingPath.removeLast() }
		
		guard let value = try self.decoder.unbox(objToUnbox(type), as: Int32.self) else
		{
			throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
		}
		
		return value
	}
	
	mutating func decode(_ type: Int64.Type) throws -> Int64
	{
		return try Int64(decode(Int.self))
	}
	
	mutating func decode(_ type: UInt.Type) throws -> UInt
	{
		return try UInt(decode(Int.self))
	}
	
	mutating func decode(_ type: UInt8.Type) throws -> UInt8
	{
		return try UInt8(decode(Int.self))
	}
	
	mutating func decode(_ type: UInt16.Type) throws -> UInt16
	{
		return try UInt16(decode(Int.self))
	}
	
	mutating func decode(_ type: UInt32.Type) throws -> UInt32
	{
		return try UInt32(decode(Int.self))
	}
	
	mutating func decode(_ type: UInt64.Type) throws -> UInt64
	{
		return try UInt64(decode(Int.self))
	}
	
	mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable
	{
		guard !self.isAtEnd else
		{
			throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Unkeyed container is at end."))
		}
		
		self.decoder.codingPath.append(ASN1Key(index: self.currentIndex))
		defer { self.decoder.codingPath.removeLast() }
		
		guard let value = try self.decoder.unbox(objToUnbox(type), as: T.self) else
		{
			throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
		}
		
		return value
	}
	
	fileprivate mutating func objToUnbox<T: Decodable>(_ type: T.Type) throws -> ASN1Object
	{
		guard let t = type as? ASN1Decodable.Type else
		{
			throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: ""))
		}
		
		return try _objToUnbox(from: t.template)
	}
	
	fileprivate mutating func _objToUnbox(from template: ASN1Template) throws -> ASN1Object
	{
		let obj = try ASN1Object.initialize(with: self.state.dataPtr, length: self.state.left, using: template)
		
		defer {
			// Shift data (position)
			self.state.advance(obj.dataLength)
			self.currentIndex += 1
		}
		
		return obj
	}
	
	mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey
	{
		let container = try ASN1KeyedDecodingContainer<NestedKey>(referencing: self.decoder, wrapping: self.container)
		return KeyedDecodingContainer(container)
	}
	
	mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer
	{
		assertionFailure("Hasn't implemented yet")
		return try ASN1UnkeyedDecodingContainer(referencing: self.decoder, wrapping: self.container)
	}
	
	mutating func superDecoder() throws -> Decoder
	{
		assertionFailure("Hasn't implemented yet")
		return _ASN1Decoder()
	}
}
