//
//  ASN1Decoder.swift
//  asn1swift
//
//  Created by Pavel Tikhonenko on 29.07.2020.
//

import Foundation

typealias ASN1DecoderConsumedValue = Int

open class ASN1Decoder
{
	//fileprivate //TODO
	struct EncodingOptions
	{
		/// Contextual user-provided information for use during encoding/decoding.
		let userInfo: [CodingUserInfoKey : Any] = [:]
	}
	
	public init() {}
	
	// MARK: - Decoding Values
	
	/// Decodes a top-level value of the given type from the given ASN1 representation.
	///
	/// - parameter type: The type of the value to decode.
	/// - parameter data: The data to decode from.
	/// - parameter template: // TODO
	/// - returns: A value of the requested type.
	/// - throws: `DecodingError.dataCorrupted` if values requested from the payload are corrupted, or if the given data is not valid ASN1.
	/// - throws: An error if any value throws an error during decoding.
	open func decode<T : ASN1Decodable>(_ type: T.Type, from data: Data, template: ASN1Template? = nil) throws -> T
	{
		let t: ASN1Template = template ?? type.template
		
		return try data.withUnsafeBytes { (p) throws -> T in
			
			let ptr: UnsafePointer<UInt8> = p.baseAddress!.assumingMemoryBound(to: UInt8.self)
			let top = try ASN1Object.initialize(with: ptr, length: data.count, using: t)
			
			let opt = EncodingOptions()
			let decoder = _ASN1Decoder(referencing: top, options: opt)
			
			guard let value = try decoder.unbox(top, as: type) else
			{
				throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: [], debugDescription: "The given data did not contain a top-level value."))
			}
			
			return value
		}
		
	}
}

internal struct ASN1Key: CodingKey
{
	public var stringValue: String
	public var intValue: Int?
	
	public init?(stringValue: String) {
		self.stringValue = stringValue
		self.intValue = nil
	}
	
	public init?(intValue: Int) {
		self.stringValue = "\(intValue)"
		self.intValue = intValue
	}
	
	public init(stringValue: String, intValue: Int?) {
		self.stringValue = stringValue
		self.intValue = intValue
	}
	
	init(index: Int) {
		self.stringValue = "Index \(index)"
		self.intValue = index
	}
	
	static let `super` = ASN1Key(stringValue: "super")!
}

// MARK: _ASN1Decoder

public protocol ASN1DecoderProtocol: Decoder
{
	var dataToDecode: Data { get }
	func extractValueData() throws -> Data
}

extension _ASN1Decoder
{
	public var dataToDecode: Data
	{
		return self.storage.current.rawData
	}
	
	public func extractValueData() throws -> Data
	{
		return self.storage.current.valueData
	}
}
//TODO: private
class _ASN1Decoder: ASN1DecoderProtocol
{
	internal struct Storage
	{
		// MARK: Properties
		
		/// The container stack.
		/// Elements may be any one of the ASN1 types (NSNull, NSNumber, String, Array, [String : Any]).
		private(set) var containers: [ASN1Object] = []
		
		// MARK: - Modifying the Stack
		
		var count: Int
		{
			return self.containers.count
		}
		
		var isTop: Bool
		{
			return count == 1
		}
		var current: ASN1Object
		{
			precondition(!self.containers.isEmpty, "Empty container stack.")
			return self.containers.last!
		}
		
		mutating func push(container: __owned ASN1Object)
		{
			self.containers.append(container)
		}
		
		mutating func popContainer()
		{
			precondition(!self.containers.isEmpty, "Empty container stack.")
			self.containers.removeLast()
		}
	}
	
	class State
	{
		var dataPtr: UnsafePointer<UInt8>
		var consumedMyself: Int
		var left: Int
		
		var asn1Obj: ASN1Object
		
		init(obj: ASN1Object)
		{
			self.asn1Obj = obj
			self.dataPtr = obj.valuePtr
			self.consumedMyself = 0
			self.left = obj.valueLength
		}
		
		var isAtEnd: Bool
		{
			return left == 0 || (dataPtr[0] == 0 && dataPtr[1] == 0)
		}
		
		func advance(_ numBytes: Int)
		{
			dataPtr += numBytes
			consumedMyself += numBytes
			left -= numBytes
		}
	}
	
	public var codingPath: [CodingKey] = []
	
	public var userInfo: [CodingUserInfoKey: Any] { return options.userInfo }
	
	var options: ASN1Decoder.EncodingOptions!
	
	internal var storage: Storage
	
	
	internal init(referencing asn1Object: ASN1Object, at codingPath: [CodingKey] = [], options: ASN1Decoder.EncodingOptions)
	{
		self.storage = Storage()
		self.storage.push(container: asn1Object)
		
		self.codingPath = codingPath
		self.options = options
	}
	
	public init()
	{
		self.storage = Storage()
	}
	
	/// Returns the data stored in this decoder as represented in a container
	/// keyed by the given key type.
	///
	/// - parameter type: The key type to use for the container.
	/// - returns: A keyed decoding container view into this decoder.
	/// - throws: `DecodingError.typeMismatch` if the encountered stored value is
	///   not a keyed container.
	public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key>
	{
		let container = try ASN1KeyedDecodingContainer<Key>(referencing: self, wrapping: self.storage.current)
		return KeyedDecodingContainer(container)
	}
	
	/// Returns the data stored in this decoder as represented in a container
	/// appropriate for holding values with no keys.
	///
	/// - returns: An unkeyed container view into this decoder.
	/// - throws: `DecodingError.typeMismatch` if the encountered stored value is
	///   not an unkeyed container.
	public func unkeyedContainer() throws -> UnkeyedDecodingContainer
	{
		return try ASN1UnkeyedDecodingContainer(referencing: self, wrapping: self.storage.current)
	}
	
	/// Returns the data stored in this decoder as represented in a container
	/// appropriate for holding a single primitive value.
	///
	/// - returns: A single value container view into this decoder.
	/// - throws: `DecodingError.typeMismatch` if the encountered stored value is
	///   not a single value container.
	public func singleValueContainer() throws -> SingleValueDecodingContainer
	{
		return self
	}
}



