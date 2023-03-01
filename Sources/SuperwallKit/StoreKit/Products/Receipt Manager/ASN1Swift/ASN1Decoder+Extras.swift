//
//  ASN1Decoder+Decode.swift
//  asn1swift
//
//  Created by Pavel Tikhonenko on 31.07.2020.
//

import Foundation

@inlinable
@inline(__always)
func isHighTag(_ number: UInt8) -> Bool
{
	return number == 0x1f
}

@inlinable
@inline(__always)
func lastTagNumber(_ byte: UInt8) -> Bool
{
	return (byte & 0x80) == 0x1f
}

@inlinable
@inline(__always)
func lengthIsShortForm(_ byte: UInt8) -> Bool
{
	return (byte & 0x80) == 0
}

@inlinable
@inline(__always)
func longFormLength(_ byte: UInt8) -> UInt8
{
	return (byte & 0x7f)
}

@inlinable
@inline(__always)
func highBits(_ field: UInt8, _ cnt: UInt8) -> UInt8
{
	return field >> (UInt8(MemoryLayout.size(ofValue: field))*8 - cnt)
}

@inlinable
@inline(__always)
func tlvConstructed(tag: UInt8) -> Bool
{
	return tag & 0x20 != 0
}
