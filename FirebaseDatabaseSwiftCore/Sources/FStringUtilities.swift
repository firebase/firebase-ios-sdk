//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 28/10/2021.
//

// NOTE: If deployment target moved to iOS 13 or above, CommonCrypto could be skipped entirely
#if canImport(CommonCrypto)
import CommonCrypto

extension Data {
    func sha1() -> Data {
        // Use CC_SHA1
        var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(self.count), &digest)
        }
        return Data(bytes: digest, count: Int(CC_SHA1_DIGEST_LENGTH))
    }
}
#elseif os(Linux) || os(Windows) || os(Android) || os(FreeBSD)
import Crypto
extension Data {
    func sha1() -> Data {
        // Use Insecure.SHA1
        return Data(Insecure.SHA1.hash(data: self))
    }
}
#endif

import Foundation

@objc public class FStringUtilities: NSObject {
    @objc public static func base64EncodedSha1(_ input: String) -> String {
        FStringUtilitiesSwift.base64EncodedSha1(input)
    }

    @objc public static func urlDecoded(_ url: String) -> String {
        FStringUtilitiesSwift.urlDecoded(url)
    }

    @objc public static func urlEncoded(_ input: String) -> String {
        FStringUtilitiesSwift.urlEncoded(input)
    }
    @objc public static func sanitizedForUserAgent(_ str: String) -> String {
        FStringUtilitiesSwift.sanitizedForUserAgent(str)
    }
}

enum FStringUtilitiesSwift {
    static func base64EncodedSha1(_ input: String) -> String  {
        let data = Data(input.utf8)
        return data.sha1().base64EncodedString()
    }

    static func urlDecoded(_ url: String) -> String {
        let replaced = url.replacingOccurrences(of: "+", with: " ")
        // This is kind of a hack, but is generally how the js client works. We
        // could run into trouble if some piece is a correctly escaped %-sequence,
        // and another isn't. But, that's bad input anyways...
        if let decoded = replaced.removingPercentEncoding {
            return decoded
        } else {
            return replaced
        }
    }

    static let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_~")
    static func urlEncoded(_ url: String) -> String {
        // Didn't seem like there was an Apple NSCharacterSet that had our version
        // of the encoding So I made my own, following RFC 2396
        // https://www.ietf.org/rfc/rfc2396.txt allowedCharacters = alphanum | "-" |
        // "_" | "~"
        url.addingPercentEncoding(withAllowedCharacters: allowedCharacters)!
    }

    static func sanitizedForUserAgent(_ str: String) -> String {
        str.replacingOccurrences(of: "/|_",
                                 with: "|",
                                 options: .regularExpression,
                                 range: str.startIndex..<str.endIndex)
    }
}
