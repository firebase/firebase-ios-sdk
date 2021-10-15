//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 11/10/2021.
//

import Foundation

let kServerValueSubKey = ".sv"
let kFirebaseMaxLeafSize = 1024 * 1024 * 10 // 10 MB

@objc public class FValidationSwiftFoo: NSObject {
    @objc public static func validatePriorityValue(_ value: Any) -> Bool {
        FValidationSwift.validatePriorityValue(value)
    }
}

public enum FValidationSwift {
    // MARK: Snapshot validation
    public static func validateFrom(_ fn: String, isValidPriorityValue value: Any, withPath path: [String]) {
        _ = validateFrom(fn, isValidPriorityValue: value, withPath: path, throwError: true)
    }

    /**
     * Returns YES if priority is valid.
     */
    public static func validatePriorityValue(_ value: Any) -> Bool {
        validateFrom("", isValidPriorityValue: value, withPath: [], throwError: false)
    }

    /**
     * Helper for validating priorities.  If passed true for throwError, it'll throw
     * descriptive errors on validation problems.  Else, it'll just return true/false.
     */
    static func validateFrom(_ fn: String,
        isValidPriorityValue value: Any,
                    withPath path: [String],
                  throwError: Bool) -> Bool {
        let handleError: (String) -> Bool = { type in
            if throwError {
                let pathString = path.prefix(50).joined(separator: ".")
                fatalError("(\(fn)) Cannot store \(type) as priority at path: \(pathString).")
            } else {
                return false
            }
        }

        if let numberValue = value as? NSNumber {
            guard !NSDecimalNumber.notANumber.isEqual(to: numberValue) else {
                return handleError("NaN")
            }
            if numberValue === kCFBooleanTrue || numberValue === kCFBooleanFalse {
                return handleError("true/false")
            }
        } else if let dval = value as? NSDictionary {
            if dval[kServerValueSubKey] != nil {
                if dval.count > 1 {
                    return handleError("other keys with server value keys")
                }
            } else {
                return handleError("an NSDictionary")
            }
        } else if value is NSArray {
            return handleError("an NSArray")
        }
        // It's valid!
        return true
    }

    static func validateFrom(_ fn: String, isValidLeafValue value: Any?, withPath path: [String]) -> Bool {
        let handleError: (String) -> Never = { message in
            let pathString = path.prefix(50).joined(separator: ".")
            fatalError("(\(fn)) \(message) \(pathString).")
        }

        if let theString = value as? String {
            // Try to avoid conversion to bytes if possible
            if theString.maximumLengthOfBytes(using: .utf8) > kFirebaseMaxLeafSize &&
                theString.lengthOfBytes(using: .utf8) > kFirebaseMaxLeafSize {
                handleError("String exceeds max size of \(kFirebaseMaxLeafSize) utf8 bytes:")
            }
            return true
        } else if let numberVal = value as? NSNumber {
            // Cannot store NaN, but otherwise can store NSNumbers.
            guard !NSDecimalNumber.notANumber.isEqual(to: numberVal) else {
                handleError("Cannot store NaN at path:")
            }
            return true
        } else if let dval = value as? NSDictionary {
            if dval[kServerValueSubKey] != nil {
                guard dval.count <= 1 else {
                    handleError("Cannot store other keys with server value keys. ")
                }
                return true
            }
            return false
        } else if value == nil || (value as? NSNull) === NSNull() {
            // Null is valid type to store at leaf
            return true
        }
        return false
    }

    static func parseAndValidateKey(_ keyId: Any, fromFunction fn: String, path: [String]) -> String {
        guard let keyId = keyId as? String else {
            let pathString = path.prefix(50).joined(separator: ".")
            fatalError("(\(fn)) Non-string keys are not allowed in object at path: \(pathString)")
        }
        return keyId
    }

    static func validateFrom(_ fn: String, validDictionaryKey keyId: Any, withPath path: [String]) -> String {
        let key = parseAndValidateKey(keyId, fromFunction: fn, path: path)
        if key != kPayloadPriority &&
            key != kPayloadValue &&
            key != kServerValueSubKey &&
            !isValidKey(key) {
                let pathString = path.prefix(50).joined(separator: ".")
                fatalError("(\(fn)) Invalid key in object at path: \(pathString). Keys must be non-empty and cannot contain '/' '.' '#' '$' '[' or ']'")
            }
        return key
    }
    
    static func validateFrom(_ fn: String, validUpdateDictionaryKey keyId: Any, withValue value: Any) -> String {
        let pathKey = parseAndValidateKey(keyId, fromFunction: fn, path: [])
        let path = FPath(with: pathKey)
        var keyNum = 0
        path.enumerateComponents { key, _ in
            if key == kPayloadPriority && keyNum == path.length() - 1 {
                validateFrom(fn, isValidPriorityValue: value, withPath: [])
            } else {
                keyNum += 1
                if !isValidKey(key) {
                    fatalError("(\(fn)) Invalid key in object. Keys must be non-empty and cannot contain '.' '#' '$' '[' or ']'")
                }
            }
        }
        return pathKey
    }

    static func validateFrom(_ fn: String, validKey key: String) {
        guard isValidKey(key) else {
            fatalError("(\(fn)) Must be a non-empty string and not contain '/' '.' '#' '$' '[' or ']'")
        }
    }

    static var invalidPathCharacters: CharacterSet = CharacterSet(charactersIn: "[].#$")

    static func isValidPathString(_ pathString: String) -> Bool {
        !pathString.isEmpty && pathString.rangeOfCharacter(from: invalidPathCharacters) == nil
    }

    static func validateFrom(_ fn: String, validPathString pathString: String) {
        guard isValidPathString(pathString) else {
            fatalError("(\(fn)) Must be a non-empty string and not contain '.' '#' '$' '[' or ']'")
        }
    }

//    static func validateFrom(_ fn: String, validRootPathString pathString: String) {
//        var tempPath = pathString
//        // HACK: Obj-C regex are kinda' slow.  Do a plain string search first before
//        // bothering with the regex.
//        if (pathString.range(of: ".info").location != NSNotFound) {
//        }
//    }
    /*
     + (void)validateFrom:(NSString *)fn validRootPathString:(NSString *)pathString {
         static dispatch_once_t token;
         static NSRegularExpression *dotInfoRegex = nil;
         dispatch_once(&token, ^{
           dotInfoRegex = [NSRegularExpression
               regularExpressionWithPattern:@"^\\/*\\.info(\\/|$)"
                                    options:0
                                      error:nil];
         });

         NSString *tempPath = pathString;
         // HACK: Obj-C regex are kinda' slow.  Do a plain string search first before
         // bothering with the regex.
         if ([pathString rangeOfString:@".info"].location != NSNotFound) {
             tempPath = [dotInfoRegex
                 stringByReplacingMatchesInString:pathString
                                          options:0
                                            range:NSMakeRange(0, pathString.length)
                                     withTemplate:@"/"];
         }
         [self validateFrom:fn validPathString:tempPath];
     }
     */
     */

    static var invalidKeyCharacters: CharacterSet = CharacterSet(charactersIn: "[].#$/")
    static func isValidKey(_ key: String) -> Bool {
        !key.isEmpty && key.rangeOfCharacter(from: invalidKeyCharacters) == nil
    }
}
