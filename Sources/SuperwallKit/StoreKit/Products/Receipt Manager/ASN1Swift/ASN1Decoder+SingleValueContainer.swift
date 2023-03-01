//
//  File.swift
//  
//
//  Created by Pavel Tikhonenko on 07.08.2020.
//

import Foundation

// MARK: SingleValueDecodingContainer

extension _ASN1Decoder: SingleValueDecodingContainer
{
	// MARK: SingleValueDecodingContainer Methods
	
	public func decodeNil() -> Bool
	{
		assertionFailure("Not supposed to be here")
		return false
	}
	
	public func decode(_ type: Bool.Type) throws -> Bool
	{
		assertionFailure("Not supposed to be here")
		return false
	}
	
	public func decode(_ type: Int.Type) throws -> Int
	{
		return try self.unbox(self.storage.current, as: Int.self)!
	}
	
	public func decode(_ type: Int8.Type) throws -> Int8
	{
		assertionFailure("Not supposed to be here")
		return 0
	}
	
	public func decode(_ type: Int16.Type) throws -> Int16
	{
		assertionFailure("Not supposed to be here")
		return 0
	}
	
	public func decode(_ type: Int32.Type) throws -> Int32
	{
		return try self.unbox(self.storage.current, as: Int32.self)!
	}
	
	public func decode(_ type: Int64.Type) throws -> Int64
	{
		assertionFailure("Not supposed to be here")
		return 0
	}
	
	public func decode(_ type: UInt.Type) throws -> UInt
	{
		assertionFailure("Not supposed to be here")
		return 0
	}
	
	public func decode(_ type: UInt8.Type) throws -> UInt8
	{
		assertionFailure("Not supposed to be here")
		return 0
	}
	
	public func decode(_ type: UInt16.Type) throws -> UInt16
	{
		assertionFailure("Not supposed to be here")
		return 0
	}
	
	public func decode(_ type: UInt32.Type) throws -> UInt32
	{
		assertionFailure("Not supposed to be here")
		return 0
	}
	
	public func decode(_ type: UInt64.Type) throws -> UInt64
	{
		assertionFailure("Not supposed to be here")
		return 0
	}
	
	public func decode(_ type: Float.Type) throws -> Float
	{
		assertionFailure("Not supposed to be here")
		return 0
	}
	
	public func decode(_ type: Double.Type) throws -> Double
	{
		assertionFailure("Not supposed to be here")
		return 0
	}
	
	public func decode(_ type: String.Type) throws -> String
	{
		return try self.unbox(self.storage.current, as: String.self)!
	}
	
	public func decode<T : Decodable>(_ type: T.Type) throws -> T
	{
		if type == ASN1SkippedField.self
		{
			print(213)
		}
		
		let obj = try ASN1Object.initialize(with: self.storage.current.valuePtr, length: self.storage.current.valueLength, using: self.storage.current.template)
		return try self.unbox(obj, as: type)!
	}
}
