//
//  File.swift
//  File
//
//  Created by Morten Bek Ditlevsen on 14/09/2021.
//

#warning("TODO: Replace with swift-crypto for cross-platform support")
import CommonCrypto
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

@objc public class Foo: NSObject {
    @objc public static func base64EncodedSha1(_ input: String) -> String  {
        FUtilitiesSwift.base64EncodedSha1(input)
    }
}

enum FUtilitiesSwift {
    enum FDataHashVersion {
        case v1
        case v2
    }
    static let maxName = "[MAX_NAME]"
    static let minName = "[MIN_NAME]"

    static func base64EncodedSha1(_ input: String) -> String  {
        let data = Data(input.utf8)
        var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        let output = Data(bytes: digest, count: Int(CC_SHA1_DIGEST_LENGTH))
        return output.base64EncodedString()
    }

    static func intForString(_ string: String) -> Int? {
        var intVal = 0
        if tryParseStringToInt(string, integer: &intVal) {
            return intVal
        }
        return nil
    }
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

    static func ieee754String(for number: NSNumber) -> String {
        var d = number.doubleValue
        let capacity = MemoryLayout<Double>.size
        let bytes = withUnsafePointer(to: &d) {
            $0.withMemoryRebound(to: UInt8.self, capacity: capacity) {
                Array(UnsafeBufferPointer(start: $0, count: capacity))
            }
        }

        let output = bytes
            .reversed()
            .map { String(format: "%02x", $0) }
            .joined()
        return output
    }

    static func appendHashRepresentation(for leafNode: FNode, to output: inout String, hashVersion: FDataHashVersion) {
        if !leafNode.getPriority().isEmpty {
            output += "priority:"
            appendHashRepresentation(for: leafNode.getPriority(),
                                        to: &output,
                                        hashVersion: hashVersion)
            output += ":"
        }
        let jsType = getJavascriptType(leafNode.val())
        output += jsType.rawValue + ":"
        switch jsType {
        case .object:
            fatalError("Unknown value for hashing: \(leafNode)")

        case .boolean:
            let numberVal = (leafNode.val() as? NSNumber) ?? NSNumber(booleanLiteral: false)
            output += numberVal.boolValue ? "true" : "false"
        case .number:
            let numberVal = (leafNode.val() as? NSNumber) ?? NSNumber(integerLiteral: 0)

            output += ieee754String(for: numberVal)
        case .string:
            let stringVal = (leafNode.val() as? String) ?? ""
            switch hashVersion {
            case .v1:
                output += stringVal
            case .v2:
                appendHashV2Representation(for: stringVal, to: &output)
            }
        case .null:
            ()
        }
    }
    static func appendHashV2Representation(for string: String, to output: inout String) {
        output += "\""
        output += string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        output += "\""
    }
}

