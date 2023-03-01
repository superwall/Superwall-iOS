//
//  File.swift
//  
//
//  Created by Pavel Tikhonenko on 07.08.2020.
//

import Foundation

func consume(from dataPtr: UnsafePointer<UInt8>, length: Int, expectedTags: [ASN1Tag]) throws -> Int
{
	var len: Int = 0
	let cons = try checkTags(from: dataPtr, size: length, with: expectedTags, lastTlvLength: &len)
	
	return cons + len
}

func extractTLLength(from dataPtr: UnsafePointer<UInt8>, length: Int, expectedTags: [ASN1Tag]) -> Int
{
	var ptr = dataPtr
	var tlvTag: ASN1Tag  = 0
	let tlvConstr: Bool = tlvConstructed(tag: ptr[0])
	var tlvLen: Int = 0 // Size of inner value
	var r: Int = 0
	
	for _ in expectedTags
	{
		let tagLen = fetchTag(from: ptr, size: length, to: &tlvTag)
		let lenOfLen = fetchLength(from: ptr + 1, size: length - 1, isConstructed: tlvConstr, rLen: &tlvLen)
		ptr += tagLen + lenOfLen
		r += tagLen + lenOfLen
	}
	
	return r
}

func extractValue(from dataPtr: UnsafePointer<UInt8>, length: Int, with expectedTags: [ASN1Tag], value: UnsafeMutablePointer<UnsafePointer<UInt8>?>, valueLength: inout Int) throws -> ASN1DecoderConsumedValue
{
	var len: Int = 0
	let cons = try checkTags(from: dataPtr, size: length, with: expectedTags, lastTlvLength: &len)
	
	value.pointee = dataPtr + cons
	valueLength = len
	
	return cons
}

func checkTags(from ptr: UnsafePointer<UInt8>, size: Int, with expectedTags: [ASN1Tag], lastTlvLength: inout Int) throws -> ASN1DecoderConsumedValue
{
	var ptr = ptr
	var size = size
	var consumedMyself: Int = 0
	var tagLen: Int = 0 // Length of tag
	var lenOfLen: Int = 0 // Lenght of L
	var tlvTag: ASN1Tag = 0 // Tag
	var tlvConstr: Bool = false
	var tlvLen: Int = 0 // Lenght of inner value
	var limitLen: Int = -1
	var expectEOCTerminators: Int = 0
	
	var step: Int = 0
	
	for tag in expectedTags
	{
		//expectEOCTerminators = 0
		
		tagLen = fetchTag(from: ptr, size: size, to: &tlvTag)
		
		if tagLen == -1
		{
			throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Data corrupted"))
		}
		
		tlvConstr = tlvConstructed(tag: ptr[0])
		
		if tlvTag != tag
		{
			throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Unexpected tag. Inappropriate."))
		}
		
		lenOfLen = fetchLength(from: ptr + 1, size: size - 1, isConstructed: tlvConstr, rLen: &tlvLen)
		
		if tlvLen == -1 // Indefinite length.
		{
			let calculatedLen = calculateLength(from: ptr + tagLen, size: size - tagLen, isConstructed: tlvConstr) - lenOfLen
			
			if calculatedLen > 0
			{
				tlvLen = calculatedLen// - 2 // remove two EOC bytes
				expectEOCTerminators = 1
			}else{
				assertionFailure("Unexpected indefinite length in a chain of definite lengths") // TODO: throw
			}
		}
		
		if limitLen == -1
		{
			limitLen  = tlvLen + tagLen + lenOfLen + expectEOCTerminators
			
			if limitLen < 0
			{
				assertionFailure("Too great tlv_len value?") // TODO: throw
				return -1
			}
			
		}
		
		// Better to keep this but the problem that we can't get outter expectEOCTerminators, pass state maybe
		//			else if limitLen != tlvLen + tagLen + lenOfLen + expectEOCTerminators
		//			{
		//				/*
		//				* Inner TLV specifies length which is inconsistent
		//				* with the outer TLV's length value.
		//				*/
		//				assertionFailure("Outer TLV is \(limitLen) and inner is \(tlvLen)") // TODO: throw
		//				return -1
		//			}
		
		ptr += (tagLen + lenOfLen)
		consumedMyself += (tagLen + lenOfLen)
		
		limitLen -= (tagLen + lenOfLen + expectEOCTerminators)
		
		if size > limitLen
		{
			size = limitLen
		}
		
		step += 1
	}
	
	lastTlvLength = tlvLen
	return consumedMyself
}

func fetchTag(from ptr: UnsafePointer<UInt8>, size: Int, to rTag: inout ASN1Tag) -> ASN1DecoderConsumedValue
{
	let firstByte = ptr.pointee
	
	var rawTag: UInt8 = firstByte
	let rawTagClass: UInt8 = rawTag >> 6
	
	rawTag &= ASN1Identifier.Tag.highTag
	
	if rawTag != ASN1Identifier.Tag.highTag
	{
		rTag = firstByte
		return 1;
	}
	
	var val: UInt = 0
	var skipped: Int = 2
	
	for i in 1..<size
	{
		if skipped > size { break }
		
		let b = ptr[i]
		
		if b & ASN1Identifier.Modifiers.contextSpecific != 0
		{
			val = (val << 7) | UInt(b & ASN1Identifier.Tag.highTag)
			
			if val >> ((8 * MemoryLayout.size(ofValue: val)) - 9) != 0
			{
				// No more space
				skipped = -1
				break
			}
		}else{
			val = (val << 7) | UInt(b)
			rTag = UInt8(val << 2) | rawTagClass;
			break
		}
		
		skipped += 1
	}
	
	return skipped
}

func fetchLength(from ptr: UnsafePointer<UInt8>, size: Int, isConstructed: Bool, rLen: inout Int) -> ASN1DecoderConsumedValue
{
	var oct = ptr.pointee
	
	if (oct & 0x80) == 0
	{
		rLen = Int(oct)
		return 1
	}else{
		var len: Int = 0
		
		
		if isConstructed && oct == 0x80 // Indefinite length
		{
			
			rLen = Int(-1)
			return 1
		}
		
		if oct == 0xff
		{
			/* Reserved in standard for future use. */
			return -1;
		}
		
		oct &= ASN1Identifier.Tag.tagNumMask
		
		var skipped: Int = 1
		for i in 1..<size
		{
			if oct == 0 { break }
			
			skipped += 1
			
			if skipped > size
			{
				break
			}
			
			let b = ptr[i]
			
			len = (len << 8) | Int(b)
			oct -= 1
		}
		
		if oct == 0
		{
			if len < 0
			{
				return -1
			}
			
			rLen = len
			return skipped
		}
		
		assertionFailure("Not enought data")
		return -1
	}
}

func calculateLength(from ptr: UnsafePointer<UInt8>, size: Int, isConstructed: Bool) -> Int
{
	var ptr = ptr
	let rawSize = size
	var size = size
	
	var vlen: Int = 0 // Length of V in TLV
	var tl: Int = 0 // Length of L in TLV
	var ll: Int = 0 // Length of L in TLV
	var skip: Int = 0
	
	ll = fetchLength(from: ptr, size: size, isConstructed: isConstructed, rLen: &vlen)
	
	if ll <= 0
	{
		return ll
	}
	
	if(vlen >= 0)
	{
		skip = ll + vlen
		
		if skip > size
		{
			assertionFailure("Not enought data")
			return 0
		}
		
		return skip
	}
	
	skip = ll
	ptr = ptr + ll
	size -= ll
	
	while true {
		var tag: ASN1Tag = 0
		
		tl = fetchTag(from: ptr, size: size, to: &tag)
		if tl <= 0 { return tl }
		
		ll = calculateLength(from: ptr + tl, size: size - tl, isConstructed: tlvConstructed(tag: tag))
		if ll <= 0 { return ll }
		
		skip += tl + ll
		
		if(ptr.pointee == 0 && (ptr+1).pointee == 0) { return skip }
		
		if skip == rawSize { return skip }
		
		ptr += (tl + ll)
		size -= (tl + ll)
	}
	
	assertionFailure("This assertion must not happen")
	return 0
}
