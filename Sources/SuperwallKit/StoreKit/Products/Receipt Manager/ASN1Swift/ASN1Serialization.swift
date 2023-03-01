//
//  ASN1Serialization.swift
//  asn1swift
//
//  Created by Pavel Tikhonenko on 28.07.2020.
//

import Foundation




struct ASN1Deserializer
{
	@inlinable
	@inline(__always)
	static func readInt(from data: Data) -> Int
	{
		var r: Int = 0
		
		let start = data.startIndex
		let end = start + data.endIndex
		
		for i in start..<end
		{
			r = r << 8
			r |= Int(data[i])
		}
		
		if r >= Int.max
		{
			return -1 //Invalid data
		}
		
		return r
	}
	
	@inlinable
	@inline(__always)
	static func readInt(from data: Data) -> Int32
	{
		var r: Int32 = 0
		
		let start = data.startIndex
		let end = start + data.endIndex
		
		for i in start..<end
		{
			r = r << 8
			r |= Int32(data[i])
		}
		
		if r >= Int32.max
		{
			return -1 //Invalid data
		}
		
		return r
	}
	
	static func readString(from data: Data, encoding: String.Encoding) -> String?
	{
		if encoding == .oid
		{
			return readOid(contentData: data)
		}else{
			return String(bytes: data, encoding: encoding)
		}
	}
	
	static func readOid(contentData: Data) -> String
	{
		if contentData.isEmpty { return "" }
		
		var oid: [UInt32] = [UInt32]()
		
		var shifted: UInt8 = 0x00
		var value: UInt32 = 0x00
		
		for (i, bit) in contentData.enumerated()
		{
			if i == 0
			{
				oid.append(UInt32(bit/40))
				oid.append(UInt32(bit%40))
			}else if (bit & 0x80) == 0
			{
				let v = UInt32((bit & 0x7F) | shifted)
				value |= v
				oid.append(value)
				
				shifted = 0x00
				value = 0x00
			}else
			{
				if value > 0 { value >>= 1 }
				
				let v = UInt32(((bit & 0x7F) | shifted) >> 1)
				value |= v
				value <<= 8
				
				shifted = bit << 7
			}
		}
		
		return oid.map { String($0) }.joined(separator: ".")
	}
}

class ASN1Serialization
{
	static func readInt(from obj: ASN1Object) -> Int
	{
		return ASN1Deserializer.readInt(from: obj.valueData)
	}
	
	static func readInt(from obj: ASN1Object) -> Int32
	{
		return ASN1Deserializer.readInt(from: obj.valueData)
	}
	
	static func readString(from data: ASN1Object, encoding: String.Encoding) -> String?
	{
		return ASN1Deserializer.readString(from: data.valueData, encoding: encoding)
	}
	
	
	
	
}
