//
//  File.swift
//  File
//
//  Created by Morten Bek Ditlevsen on 14/09/2021.
//

import Foundation

func tryParseStringToInt(_ str: String, integer: inout Int) -> Bool {
    // First do some cheap checks (NOTE: The below checks are significantly
    // faster than an equivalent regex :-( ).
    let length = str.count
    if length > 11 || length == 0 {
        return false
    }
    var value: Int64 = 0
    var negative = false
    var i = str.startIndex
    if str[i] == "-" {
        if length == 1 {
            return false
        }
        negative = true
        i = str.index(after: i)
    }
    for c in str[i...] {
        // Must be a digit, or '-' if it's the first char.
        if c < "0" || c > "9" {
            return false
        } else {
            let charValue = c.asciiValue! - ("0" as Character).asciiValue!
            value = value * 10 + Int64(charValue)
        }
    }

    value = (negative) ? -value : value;

    if value < Int32.min || value > Int32.max {
        return false
    } else {
        integer = Int(value)
        return true
    }
}

enum FUtilitiesSwift {
    static let maxName = "[MAX_NAME]"
    static let minName = "[MIN_NAME]"
    static func compareKey(_ a: String, _ b: String) -> ComparisonResult {
        if a == b { return .orderedSame }
        else if a == FUtilitiesSwift.minName || b == FUtilitiesSwift.maxName { return .orderedAscending }
        else if a == FUtilitiesSwift.maxName || b == FUtilitiesSwift.minName { return .orderedDescending }
        else {
            var aAsInt: Int = 0
            var bAsInt: Int = 0
            if tryParseStringToInt(a, integer: &aAsInt) {
                if tryParseStringToInt(b, integer: &bAsInt) {
                    if aAsInt > bAsInt {
                        return .orderedDescending
                    } else if aAsInt < bAsInt {
                        return .orderedAscending
                    } else if a.count > b.count {
                        return .orderedDescending
                    } else if a.count < b.count {
                        return .orderedAscending
                    } else {
                        return .orderedSame
                    }
                } else {
                    return .orderedAscending
                }
            } else if tryParseStringToInt(b, integer: &bAsInt) {
                return .orderedDescending
            } else {
                // Perform literal character by character search to prevent a > b &&
                // b > a issues. Note that calling -(NSString
                // *)decomposedStringWithCanonicalMapping also works.
                return a.compare(b, options: .literal)
            }
        }
    }
}

