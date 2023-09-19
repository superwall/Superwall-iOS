//
//  File.swift
//  
//
//  Created by Pavel Tikhonenko on 15.08.2020.
//

import Foundation

enum OID: String
{
	/// NIST Algorithm
	case sha1 = "1.3.14.3.2.26"
	case sha256 = "2.16.840.1.101.3.4.2.1"
	
	/// PKCS1
	case sha1WithRSAEncryption = "1.2.840.113549.1.1.5"
	case sha256WithRSAEncryption = " 1.2.840.113549.1.1.11"
	
	/// PKCS7
	case data = "1.2.840.113549.1.7.1"
	case signedData = "1.2.840.113549.1.7.2"
	case envelopedData = "1.2.840.113549.1.7.3"
	case signedAndEnvelopedData = "1.2.840.113549.1.7.4"
	case digestedData = "1.2.840.113549.1.7.5"
	case encryptedData = "1.2.840.113549.1.7.6"
}

extension OID
{
	@available(iOS 10.0, *)
	func encryptionAlgorithm() -> SecKeyAlgorithm
	{
		switch self
		{
		case .sha1:
			return SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA1
		case .sha256:
			return SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA256
		case .sha1WithRSAEncryption:
			return SecKeyAlgorithm.rsaEncryptionOAEPSHA1
		case .sha256WithRSAEncryption:
			return SecKeyAlgorithm.rsaEncryptionOAEPSHA256
		default:
			assertionFailure("Don't even try to obtain a value for this type")
			return SecKeyAlgorithm.rsaSignatureRaw
		}
	}
}

struct PKCS7Container: ASN1Decodable
{
	var oid: ASN1SkippedField
	private(set) var signedData: SignedData
	
	enum CodingKeys: ASN1CodingKey
	{
		case oid
		case signedData
		
		var template: ASN1Template
		{
			switch self
			{
			case .oid:
				return .universal(ASN1Identifier.Tag.objectIdentifier)
			case .signedData:
				return SignedData.template
			}
		}
	}
	
}

extension PKCS7Container
{
	struct SignedData: ASN1Decodable
	{
		static var template: ASN1Template
		{
			return ASN1Template.contextSpecific(0).constructed().explicit(tag: 16).constructed()
		}
		
		var version: Int32
		var alg: DigestAlgorithmIdentifiersContainer
		var contentInfo: ContentInfo
		var certificates: CetrificatesContaner
		var signerInfos: SignerInfos
		
		enum CodingKeys: ASN1CodingKey
		{
			case version
			case alg
			case contentInfo
			case certificates
			case signerInfos
			
			var template: ASN1Template
			{
				switch self
				{
				case .version:
					return .universal(ASN1Identifier.Tag.integer)
				case .alg:
					return DigestAlgorithmIdentifiersContainer.template
				case .contentInfo:
					return ContentInfo.template
				case .certificates:
					return CetrificatesContaner.template
				case .signerInfos:
					return SignerInfos.template
				}
			}
		}
	}
	
	struct DigestAlgorithmIdentifiersContainer: ASN1Decodable
	{
		var items: [Item]
		
		init(from decoder: Decoder) throws
		{
			var container: UnkeyedDecodingContainer = try decoder.unkeyedContainer()
			
			var items: [Item] = []
			
			while !container.isAtEnd
			{
				items.append(try container.decode(Item.self))
			}
			
			self.items = items
		}
		
		static var template: ASN1Template { ASN1Template.universal(ASN1Identifier.Tag.set).constructed() }
		
		struct Item: ASN1Decodable
		{
			var algorithm: String
			var parameters: ASN1Null
			
			enum CodingKeys: ASN1CodingKey
			{
				case algorithm
				case parameters
				
				var template: ASN1Template
				{
					switch self
					{
					case .algorithm:
						return .universal(ASN1Identifier.Tag.objectIdentifier)
					case .parameters:
						return .universal(ASN1Identifier.Tag.null)
					}
				}
			}
			
			static var template: ASN1Template
			{
				return ASN1Template.universal(ASN1Identifier.Tag.sequence).constructed()
			}
			
		}
	}
	
	struct ContentInfo: ASN1Decodable
	{
		static var template: ASN1Template
		{
			return ASN1Template.universal(ASN1Identifier.Tag.sequence).constructed()
		}
		
		var oid: ASN1SkippedField
		var payload: ASN1SkippedField
		
		enum CodingKeys: ASN1CodingKey
		{
			case oid
			case payload
			
			var template: ASN1Template
			{
				switch self
				{
				case .oid:
					return .universal(ASN1Identifier.Tag.objectIdentifier)
				case .payload:
					return ASN1Template.contextSpecific(0).constructed()
				}
			}
		}
	}
	
	
	struct Certificate: ASN1Decodable
	{
		var cert: TPSCertificate
		var signatureAlgorithm: ASN1SkippedField
		var signatureValue: Data
		
		var rawData: Data
		
		enum CodingKeys: ASN1CodingKey
		{
			case cert
			case signatureAlgorithm
			case signatureValue
			
			var template: ASN1Template
			{
				switch self
				{
				case .cert:
					return TPSCertificate.template
				case .signatureAlgorithm:
					return ASN1Template.universal(ASN1Identifier.Tag.sequence).constructed()
				case .signatureValue:
					return ASN1Template.universal(ASN1Identifier.Tag.bitString)
				}
			}
		}
		
		init(from decoder: Decoder) throws
		{
			let dec = decoder as! ASN1DecoderProtocol
			let container = try decoder.container(keyedBy: CodingKeys.self)
			
			self.rawData = dec.dataToDecode
			self.cert = try container.decode(TPSCertificate.self, forKey: .cert)
			self.signatureAlgorithm = try container.decode(ASN1SkippedField.self, forKey: .signatureAlgorithm)
			self.signatureValue = try container.decode(Data.self, forKey: .signatureValue)
		}
		
		static var template: ASN1Template
		{
			return ASN1Template.universal(ASN1Identifier.Tag.sequence).constructed()
		}
	}
	
	struct TPSCertificate: ASN1Decodable
	{
		var version: Int
		var serialNumber: Int
		var signature: ASN1SkippedField
		var issuer: ASN1SkippedField
		var validity: ASN1SkippedField
		var subject: ASN1SkippedField
		var subjectPublicKeyInfo: Data // We will need only this field
		var extensions: ASN1SkippedField
		
		enum CodingKeys: ASN1CodingKey
		{
			case version
			case serialNumber
			case signature
			case issuer
			case validity
			case subject
			case subjectPublicKeyInfo
			case extensions
			
			var template: ASN1Template
			{
				switch self
				{
				case .version:
					return ASN1Template.contextSpecific(0).constructed().explicit(tag: ASN1Identifier.Tag.integer)
				case .serialNumber:
					return ASN1Template.universal(ASN1Identifier.Tag.integer)
				case .signature:
					return ASN1Template.universal(ASN1Identifier.Tag.sequence).constructed()
				case .issuer:
					return ASN1Template.universal(ASN1Identifier.Tag.sequence).constructed()
				case .validity:
					return ASN1Template.universal(ASN1Identifier.Tag.sequence).constructed()
				case .subject:
					return ASN1Template.universal(ASN1Identifier.Tag.sequence).constructed()
				case .subjectPublicKeyInfo:
					return ASN1Template.universal(ASN1Identifier.Tag.sequence).constructed()
				case .extensions:
					return ASN1Template.contextSpecific(3).constructed().explicit(tag: ASN1Identifier.Tag.sequence).constructed()
				}
			}
		}
		
		init(from decoder: Decoder) throws
		{
			let container = try decoder.container(keyedBy: CodingKeys.self)
			
			self.version = try container.decode(Int.self, forKey: .version)
			self.serialNumber = try container.decode(Int.self, forKey: .serialNumber)
			self.signature = try container.decode(ASN1SkippedField.self, forKey: .signature)
			self.issuer = try container.decode(ASN1SkippedField.self, forKey: .issuer)
			self.validity = try container.decode(ASN1SkippedField.self, forKey: .validity)
			self.subject = try container.decode(ASN1SkippedField.self, forKey: .subject)
			
			let subDec = try container.superDecoder(forKey: .subjectPublicKeyInfo) as! ASN1DecoderProtocol
			self.subjectPublicKeyInfo = subDec.dataToDecode
			
			self.extensions = try container.decode(ASN1SkippedField.self, forKey: .extensions)
		}
		
		static var template: ASN1Template
		{
			return ASN1Template.universal(ASN1Identifier.Tag.sequence).constructed()
		}
	}
	
	struct CetrificatesContaner: ASN1Decodable
	{
		let certificates: [Certificate]
		
		init(from decoder: Decoder) throws
		{
			var container: UnkeyedDecodingContainer = try decoder.unkeyedContainer()
			
			var certificates: [Certificate] = []
			
			while !container.isAtEnd {
				certificates.append(try container.decode(Certificate.self))
			}
			
			self.certificates = certificates
		}
		
		static var template: ASN1Template
		{
			return ASN1Template.contextSpecific(0).constructed().implicit(tag: ASN1Identifier.Tag.sequence)
		}
	}
	
	struct SignerInfos: ASN1Decodable
	{
		static var template: ASN1Template
		{
			return ASN1Template.universal(ASN1Identifier.Tag.set).constructed().explicit(tag: ASN1Identifier.Tag.sequence).constructed()
		}
		
		var version: Int
		var signerIdentifier: ASN1SkippedField
		var digestAlgorithm: ASN1SkippedField
		var digestEncryptionAlgorithm: ASN1SkippedField
		var encryptedDigest: Data
		
		enum CodingKeys: ASN1CodingKey
		{
			case version
			case signerIdentifier
			case digestAlgorithm
			case digestEncryptionAlgorithm
			case encryptedDigest
			
			var template: ASN1Template
			{
				switch self
				{
				case .version:
					return .universal(ASN1Identifier.Tag.integer)
				case .signerIdentifier:
					return ASN1Template.universal(ASN1Identifier.Tag.sequence).constructed()
				case .digestAlgorithm:
					return ASN1Template.universal(ASN1Identifier.Tag.sequence).constructed()
				case .digestEncryptionAlgorithm:
					return ASN1Template.universal(ASN1Identifier.Tag.sequence).constructed()
				case .encryptedDigest:
					return .universal(ASN1Identifier.Tag.octetString)
				}
			}
		}
	}
}

extension PKCS7Container
{
	static var template: ASN1Template
	{
		return ASN1Template.universal(16).constructed()
	}
}
