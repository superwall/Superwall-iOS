//
//  File.swift
//  
//
//  Created by Pavel Tikhonenko on 07.08.2020.
//

import Foundation

// MARK: ASN1KeyedDecodingContainer

internal struct ASN1KeyedDecodingContainer<K : CodingKey> : KeyedDecodingContainerProtocol
{
	typealias Key = K
	
	// MARK: Properties
	
	/// A reference to the decoder we're reading from.
	private let decoder: _ASN1Decoder
	
	/// A reference to the container we're reading from.
	private let container: ASN1Object
	private(set) var innerCache: Cache
	
	private let state: _ASN1Decoder.State
	
	/// The path of coding keys taken to get to this point in decoding.
	private(set) public var codingPath: [CodingKey]
	
	public var rawData: Data { return container.rawData }
	
	// MARK: - Initialization
	
	/// Initializes `self` by referencing the given decoder and container.
	init(referencing decoder: _ASN1Decoder, wrapping container: ASN1Object) throws
	{
		self.decoder = decoder
		self.codingPath = decoder.codingPath
		self.container = container
		
		self.state = _ASN1Decoder.State(obj: container)
		self.innerCache = Cache()
	}
	
	// MARK: - KeyedDecodingContainerProtocol Methods
	
	public var allKeys: [Key]
	{
		return []
	}
	
	public func contains(_ key: Key) -> Bool
	{
		return false
	}
	
	private func _errorDescription(of key: CodingKey) -> String
	{
		return "\(key) (\"\(key.stringValue)\")"
	}
	
	public func decodeNil(forKey key: Key) throws -> Bool
	{
		assertionFailure("Not supposed to be here")
		return false
	}
	
	public func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool
	{
		assertionFailure("Not supposed to be here")
		return false
	}
	
	public func decode(_ type: Int.Type, forKey key: Key) throws -> Int
	{
		self.decoder.codingPath.append(key)
		defer { self.decoder.codingPath.removeLast() }
		
		guard let value = try self.decoder.unbox(objToUnbox(forKey: key), as: Int.self) else
		{
			let type = Data.self
			throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
		}
		
		return value
	}
	
	public func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
		assertionFailure("Not supposed to be here")
		return 0
	}
	
	public func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16
	{
		assertionFailure("Not supposed to be here")
		return 0
	}
	
	public func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32
	{
		self.decoder.codingPath.append(key)
		defer { self.decoder.codingPath.removeLast() }
		
		guard let value = try self.decoder.unbox(objToUnbox(forKey: key), as: Int32.self) else
		{
			let type = Data.self
			throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
		}
		
		return value
	}
	
	public func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
		assertionFailure("Not supposed to be here")
		return 0
	}
	
	public func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
		assertionFailure("Not supposed to be here")
		return 0
	}
	
	public func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
		assertionFailure("Not supposed to be here")
		return 0
	}
	
	public func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
		assertionFailure("Not supposed to be here")
		return 0
	}
	
	public func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
		assertionFailure("Not supposed to be here")
		return 0
	}
	
	public func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
		assertionFailure("Not supposed to be here")
		return 0
	}
	
	public func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
		assertionFailure("Not supposed to be here")
		return 0
	}
	
	public func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
		assertionFailure("Not supposed to be here")
		return 0
	}
	
	public func decode(_ type: String.Type, forKey key: Key) throws -> String
	{
		self.decoder.codingPath.append(key)
		defer { self.decoder.codingPath.removeLast() }
		
		guard let value = try self.decoder.unbox(objToUnbox(forKey: key), as: String.self) else
		{
			let type = Data.self
			throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
		}
		
		return value
	}
	
	public func decodeSkippedField(forKey key: Key) throws -> ASN1SkippedField
	{
		self.decoder.codingPath.append(key)
		defer { self.decoder.codingPath.removeLast() }
		
		
		guard let value = try self.decoder.unboxSkippedField(objToUnbox(forKey: key)) else
		{
			let type = Data.self
			throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
		}
		
		return value
	}
	
	public func decodeData(forKey key: Key) throws -> Data
	{
		self.decoder.codingPath.append(key)
		defer { self.decoder.codingPath.removeLast() }
		
		
		guard let value = try self.decoder.unbox(objToUnbox(forKey: key), as: Data.self) else
		{
			let type = Data.self
			throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
		}
		
		return value
	}
	
	public func decode<T : Decodable>(_ type: T.Type, forKey key: Key) throws -> T
	{
		if type == Data.self || type == NSData.self
		{
			return try decodeData(forKey: key) as! T
		}
		
		if type == ASN1SkippedField.self
		{
			return try decodeSkippedField(forKey: key) as! T
		}
		
		self.decoder.codingPath.append(key)
		defer { self.decoder.codingPath.removeLast() }
		
		
		guard let value = try self.decoder.unbox(objToUnbox(forKey: key), as: T.self) else
		{
			throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "Expected \(type) value but found null instead."))
		}
		
		return value
	}
	
	fileprivate func objToUnbox(forKey key: Key) throws -> ASN1Object
	{
		guard let k = key as? ASN1CodingKey else
		{
			throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "key is not ASN1CodingKey"))
		}

		if let obj = innerCache.object(for: k.hashValue)
		{
			return obj
		}
		
		let obj = try ASN1Object.initialize(with: self.state.dataPtr, length: self.state.left, using: k.template)
		innerCache.cache(object: obj, for: k.hashValue)
		
		// Shift data (position)
		self.state.advance(obj.dataLength)
		
		return obj
	}
	
	public func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey>
	{
		assertionFailure("Hasn't implemented yet")
		let container = try ASN1KeyedDecodingContainer<NestedKey>(referencing: self.decoder, wrapping: self.container)
		return KeyedDecodingContainer(container)
	}
	
	public func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer
	{
		return try ASN1UnkeyedDecodingContainer(referencing: self.decoder, wrapping: objToUnbox(forKey: key))
	}
	
	private func _superDecoder(forKey key: __owned CodingKey) throws -> Decoder
	{
		guard let k = key as? ASN1CodingKey else
		{
			throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: self.decoder.codingPath, debugDescription: "key is not ASN1CodingKey"))
		}
		
		return _ASN1Decoder(referencing: try objToUnbox(forKey: k as! K), at: self.decoder.codingPath, options: self.decoder.options)
	}
	
	public func superDecoder() throws -> Decoder
	{
		assertionFailure("Hasn't implemented yet")
		return try _superDecoder(forKey: ASN1Key.super)
	}
	
	public func superDecoder(forKey key: Key) throws -> Decoder
	{
		return try _superDecoder(forKey: key)
	}
}

extension ASN1KeyedDecodingContainer
{
	class Cache
	{
		var storage: [Int: ASN1Object] = [:]
		
		func cache(object: ASN1Object, for key: Int)
		{
			storage[key] = object
		}
		
		func object(for key: Int) -> ASN1Object?
		{
			return storage[key]
		}
	}
}
