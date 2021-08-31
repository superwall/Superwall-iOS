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
        return ISO8601DateFormatter().string(from: self)
    }
}


internal extension SKProduct {
    
    var eventData: [String: String] {
        return [
            "price": localizedPrice,
            "periodAlt": localizedSubscriptionPeriod,
            "period": period,
            "periodly": "\(period)ly",
            "weeklyPrice": weeklyPrice,
            "trialPeriodDays": trialPeriodDays,
            "trialPeriodWeeks": trialPeriodWeeks,
            "trialPeriodMonths": trialPeriodMonths,
            "trialPeriodYears": trialPeriodYears,
            "trialPeriodText": trialPeriodText
        ]
    }

    var localizedPrice: String {
        return priceFormatter(locale: priceLocale).string(from: price) ?? "?"
    }
    
    private func priceFormatter(locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        return formatter
    }
    
    var localizedSubscriptionPeriod: String {
        guard let subscriptionPeriod = self.subscriptionPeriod else { return "" }
        
        let dateComponents: DateComponents
        
        switch subscriptionPeriod.unit {
        case .day: dateComponents = DateComponents(day: subscriptionPeriod.numberOfUnits)
        case .week: dateComponents = DateComponents(weekOfMonth: subscriptionPeriod.numberOfUnits)
        case .month: dateComponents = DateComponents(month: subscriptionPeriod.numberOfUnits)
        case .year: dateComponents = DateComponents(year: subscriptionPeriod.numberOfUnits)
        @unknown default:
            print("WARNING: SwiftyStoreKit localizedSubscriptionPeriod does not handle all SKProduct.PeriodUnit cases.")
            // Default to month units in the unlikely event a different unit type is added to a future OS version
            dateComponents = DateComponents(month: subscriptionPeriod.numberOfUnits)
        }

        return DateComponentsFormatter.localizedString(from: dateComponents, unitsStyle: .short) ?? ""
    }

    var period: String {
        get {

            guard let period = subscriptionPeriod else { return "" }

            if period.unit == .day {
                if period.numberOfUnits == 7 {
                    return "week"
                } else {
                    return "day"
                }
            }

            if period.unit == .month {
                return "month"
            }

            if period.unit == .week {
                return "week"
            }

            if period.unit == .year {
                return "year"
            }

            return ""

        }
    }

    var weeklyPrice: String {
        get {
            if price == NSDecimalNumber(decimal: 0.00) {
                return "$0.00"
            }

            let numberFormatter = NumberFormatter()
            let locale = priceLocale
            numberFormatter.numberStyle = .currency
            numberFormatter.locale = locale
            
            let periodText = period

            if periodText == "year" {
                return numberFormatter.string(from: NSDecimalNumber(decimal: (price as Decimal) / Decimal(52.0))) ?? "N/A"
            }

            if periodText == "month" {
                return numberFormatter.string(from: NSDecimalNumber(decimal: (price as Decimal) * Decimal(11.99) / Decimal(52.0))) ?? "N/A"
            }

            if periodText == "week" {
                return numberFormatter.string(from: NSDecimalNumber(decimal: (price as Decimal))) ?? "N/A"
            }

            if periodText == "day" {
                return numberFormatter.string(from: NSDecimalNumber(decimal: (price as Decimal))) ?? "N/A"
            }

            return "$0.00"
        }
    }

    var hasFreeTrial: Bool {
        get {
            if let _ = introductoryPrice?.subscriptionPeriod {
                return true
            } else {
                return false
            }
        }
    }

    var trialPeriodDays: String {
        get {
            if let trialPeriod = introductoryPrice?.subscriptionPeriod {
                let c = trialPeriod.numberOfUnits

                if trialPeriod.unit == .day {
                    return "\(Int(1 * c))"
                }

                if trialPeriod.unit == .month {
                    return "\(Int(30 * c))"
                }

                if trialPeriod.unit == .week {
                    return "\(Int(7 * c))"
                }

                if trialPeriod.unit == .year {
                    return "\(Int(365 * c))"
                }

            }

            return "0"
        }
    }
    
    var trialPeriodWeeks: String {
        get {
            if let trialPeriod = introductoryPrice?.subscriptionPeriod {
                let c = trialPeriod.numberOfUnits

                if trialPeriod.unit == .day {
                    return ""
                }

                if trialPeriod.unit == .month {
                    return "\(4 * c)"
                }

                if trialPeriod.unit == .week {
                    return "\(1 * c)"
                }

                if trialPeriod.unit == .year {
                    return "\(52 * c)"
                }

            }

            return "0"
        }
    }
    
    var trialPeriodMonths: String {
        get {
            if let trialPeriod = introductoryPrice?.subscriptionPeriod {
                let c = trialPeriod.numberOfUnits

                if trialPeriod.unit == .day {
                    return ""
                }

                if trialPeriod.unit == .month {
                    return "\(c * 1)"
                }

                if trialPeriod.unit == .week {
                    return ""
                }

                if trialPeriod.unit == .year {
                    return "\(c * 12)"
                }

            }

            return "0"
        }
    }
    
    var trialPeriodYears: String {
        get {
            if let trialPeriod = introductoryPrice?.subscriptionPeriod {
                let c = trialPeriod.numberOfUnits

                if trialPeriod.unit == .day {
                    return ""
                }

                if trialPeriod.unit == .month {
                    return ""
                }

                if trialPeriod.unit == .week {
                    return ""
                }

                if trialPeriod.unit == .year {
                    return "\(c)"
                }

            }

            return "0"
        }
    }

    var trialPeriodText: String {
        get {

            if let trialPeriod = introductoryPrice?.subscriptionPeriod {

                let units = trialPeriod.numberOfUnits

                if trialPeriod.unit == .day {
                    return "\(units)-day"
                }

                if trialPeriod.unit == .month {
                    return "\(units * 30)-day"
                }

                if trialPeriod.unit == .week {
                    return "\(units * 7)-day"
                }

                if trialPeriod.unit == .year {
                    return "\(units * 365)-day"
                }
            }

            return ""
        }
    }
}
