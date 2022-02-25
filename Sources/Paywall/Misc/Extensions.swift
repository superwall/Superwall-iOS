//
//  File 2.swift
//  
//
//  Created by Brian Anglin on 8/4/21.
//
import UIKit
import Foundation
import StoreKit

internal extension UIColor {
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
    
    var readableOverlayColor: UIColor {
        return isDarkColor ? .white : .black
    }
    
    var isDarkColor: Bool {
        var r, g, b, a: CGFloat
        (r, g, b, a) = (0, 0, 0, 0)
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return  lum < 0.50
    }
}


internal extension Date {

    var isoString: String {
		
		if #available(iOS 11.0, *) {
			let f1 = ISO8601DateFormatter()
			f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
			return f1.string(from: self)
		}
		
		let f2 = DateFormatter()
		f2.calendar = Calendar(identifier: .iso8601)
		f2.locale = Locale(identifier: "en_US_POSIX")
		f2.timeZone = TimeZone(secondsFromGMT: 0)
		f2.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
		return f2.string(from: self)
		
    }
	
	var isoStringFormatted: String {
		
		if #available(iOS 11.0, *) {
			let f1 = ISO8601DateFormatter()
			f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
			return f1.string(from: self)
		}
		
		let f2 = DateFormatter()
		f2.calendar = Calendar(identifier: .iso8601)
		f2.locale = Locale(identifier: "en_US_POSIX")
		f2.timeZone = TimeZone(secondsFromGMT: 0)
		f2.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
		return f2.string(from: self)
		
	}
}



extension UIWindow {
	static var isLandscape: Bool {
		if #available(iOS 13.0, *) {
			return UIApplication.shared.windows
				.first?
				.windowScene?
				.interfaceOrientation
				.isLandscape ?? false
		} else {
			return UIApplication.shared.statusBarOrientation.isLandscape
		}
	}
}


extension Dictionary {

	func removingNSNullValues() -> Dictionary {
		self.filter { !($0.value is NSNull) }
	}

}

extension Dictionary {

	/// Merge strategy to use for any duplicate keys.
	enum MergeStrategy<Value> {

		/// Keep the original value.
		case keepOriginalValue
		/// Overwrite the original value.
		case overwriteValue

		var combine: (Value, Value) -> Value {
			switch self {
			case .keepOriginalValue:
				return { original, _ in original }
			case .overwriteValue:
				return { _, overwrite in overwrite }
			}
		}

	}

	/// Creates a dictionary by merging the given dictionary into this
	/// dictionary, using a merge strategy to determine the value for
	/// duplicate keys.
	///
	/// - Parameters:
	///   - other:  A dictionary to merge.
	///   - strategy: The merge strategy to use for any duplicate keys. The strategy provides a
	///   closure that returns the desired value for the final dictionary. The default is `overwriteValue`.
	/// - Returns: A new dictionary with the combined keys and values of this
	///   dictionary and `other`.
	func merging(_ other: [Key: Value], strategy: MergeStrategy<Value> = .overwriteValue) -> [Key: Value] {
		merging(other, uniquingKeysWith: strategy.combine)
	}

	/// Merge the keys/values of two dictionaries.
	///
	/// The merge strategy used is `overwriteValue`.
	///
	/// - Parameters:
	///   - lhs: A dictionary to merge.
	///   - rhs: Another dictionary to merge.
	/// - Returns: An dictionary with keys and values from both.
	static func + (lhs: [Key: Value], rhs: [Key: Value]) -> [Key: Value] {
		lhs.merging(rhs)
	}

}


internal extension UIViewController {
	static var topMostViewController: UIViewController? {
		var presentor: UIViewController? = UIApplication.shared.keyWindow?.rootViewController
		
		while let p = presentor?.presentedViewController {
			presentor = p
		}
		
		return presentor
	}
}



internal func OnMain(_ execute: @escaping () -> Void) {
	DispatchQueue.main.async(execute: execute)
}

internal func OnMain(after: TimeInterval, _ execute: @escaping () -> Void) {
	DispatchQueue.main.asyncAfter(deadline: .now() + after, execute: execute)
}


extension Encodable {
  var dictionary: [String: Any]? {
	guard let data = try? JSONEncoder().encode(self) else { return nil }
	return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)).flatMap { $0 as? [String: Any] }
  }
}

//
extension String  {
//	var isNumber: Bool {
//		let numberSet = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))
//		let input = trimmingCharacters(in: .whitespacesAndNewlines)
//		return !input.isEmpty && input.rangeOfCharacter(from: numberSet.inverted) == nil
//	}
//	
	func removeCharacters(from forbiddenChars: CharacterSet) -> String {
		let passed = self.unicodeScalars.filter { !forbiddenChars.contains($0) }
		return String(String.UnicodeScalarView(passed))
	}
}

extension Decimal {
	mutating func round(_ scale: Int, _ roundingMode: NSDecimalNumber.RoundingMode) {
		var localCopy = self
		NSDecimalRound(&self, &localCopy, scale, roundingMode)
	}

	func rounded(_ scale: Int, _ roundingMode: NSDecimalNumber.RoundingMode) -> Decimal {
		var result = Decimal()
		var localCopy = self
		NSDecimalRound(&result, &localCopy, scale, roundingMode)
		return result
	}
}
