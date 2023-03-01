//
//  File.swift
//  
//
//  Created by Pavel Tikhonenko on 07.08.2020.
//

import Foundation

extension _ASN1Decoder
{
	/// Returns the given value unboxed from a container.
	func unbox(_ value: Data, as type: Bool.Type) throws -> Bool?
	{
		assertionFailure("Not yet implemented")
		return nil
	}
	
	func unbox(_ value: ASN1Object, as type: Int.Type) throws -> Int?
	{
		return ASN1Serialization.readInt(from: value) //TODO throw
	}
	
	func unbox(_ value: ASN1Object, as type: Int8.Type) throws -> Int8?
	{
		assertionFailure("Not yet implemented")
		return nil
	}
	
	func unbox(_ value: ASN1Object, as type: Int16.Type) throws -> Int16?
	{
		assertionFailure("Not yet implemented")
		return nil
	}
	
	func unbox(_ value: ASN1Object, as type: Int32.Type) throws -> Int32?
	{
		return ASN1Serialization.readInt(from: value) //TODO throw
	}
	
	func unbox(_ value: ASN1Object, as type: Int64.Type) throws -> Int64?
	{
		assertionFailure("Not yet implemented")
		return nil
	}
	
	func unbox(_ value: ASN1Object, as type: UInt.Type) throws -> UInt?
	{
		assertionFailure("Not yet implemented")
		return nil
	}
	
	func unbox(_ value: ASN1Object, as type: UInt8.Type) throws -> UInt8?
	{
		assertionFailure("Not yet implemented")
		return nil
	}
	
	func unbox(_ value: ASN1Object, as type: UInt16.Type) throws -> UInt16?
	{
		assertionFailure("Not yet implemented")
		return nil
	}
	
	func unbox(_ value: ASN1Object, as type: UInt32.Type) throws -> UInt32?
	{
		assertionFailure("Not yet implemented")
		return nil
	}
	
	func unbox(_ value: ASN1Object, as type: UInt64.Type) throws -> UInt64?
	{
		assertionFailure("Not yet implemented")
		return nil
	}
	
	func unbox(_ value: ASN1Object, as type: Float.Type) throws -> Float?
	{
		assertionFailure("Not yet implemented")
		return nil
	}
	
	func unbox(_ value: ASN1Object, as type: Double.Type) throws -> Double?
	{
		assertionFailure("Not yet implemented")
		return nil
	}
	
	func unbox(_ value: ASN1Object, as type: String.Type) throws -> String?
	{
		return ASN1Serialization.readString(from: value, encoding: value.template.stringEncoding)
	}
	
	func unbox(_ value: ASN1Object, as type: Date.Type) throws -> Date?
	{
		assertionFailure("Not yet implemented")
		return nil
	}
	
	func unbox(_ value: ASN1Object, as type: Data.Type) throws -> Data?
	{
		return value.valueData
	}
	
	func unboxSkippedField(_ value: ASN1Object) throws -> ASN1SkippedField?
	{
		return ASN1SkippedField(rawData: value.rawData)
	}
	
	func unbox(_ value: ASN1Object, as type: Decimal.Type) throws -> Decimal?
	{
		assertionFailure("Not yet implemented")
		return nil
	}
	
	func unbox<T : Decodable>(_ value: ASN1Object, as type: T.Type) throws -> T?
	{
		return try unbox_(value, as: type) as? T
	}
	
	func unbox(_ value: ASN1Object, as type: ASN1SkippedField.Type) throws -> ASN1SkippedField?
	{
		return try unboxSkippedField(value)
	}
	
	func unbox_(_ value: ASN1Object, as type: Decodable.Type) throws -> Any?
	{
		if type == ASN1SkippedField.self
		{
			return try self.unbox(value, as: ASN1SkippedField.self)
		}
		
		if type == Data.self || type == NSData.self
		{
			return try self.unbox(value, as: Data.self)
		}
		
		self.storage.push(container: value)
		defer { self.storage.popContainer() }
		
		return try type.init(from: self)
		
	}
}
