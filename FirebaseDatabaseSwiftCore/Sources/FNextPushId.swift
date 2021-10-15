//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 11/10/2021.
//

import Foundation

let PUSH_CHARS =
    "-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz"

let MIN_PUSH_CHAR: Character = "-"

let MAX_PUSH_CHAR: Character = "z"

let MAX_KEY_LEN = 786

@objc public class FNextPushId: NSObject {
    private static var lastPushTime: Int64 = 0
    private static var lastRandChars: [UInt8] = Array<UInt8>(repeating: 0, count: 12)
    @objc public static func get(_ currentTime: TimeInterval) -> String {
        var now: Int64 = Int64(currentTime * 1000)
        let duplicateTime = now == lastPushTime
        lastPushTime = now

        var timeStampChars: String = ""
        for _ in 0 ..< 8 {
            let offset = Int(now % 64)
            let index = PUSH_CHARS.index(PUSH_CHARS.startIndex, offsetBy: offset)
            timeStampChars.append(PUSH_CHARS[index])
            now = now / 64
        }

        var id: String = String(timeStampChars.reversed())
        if !duplicateTime {
            for i in (0 ..< 12).reversed() {
                lastRandChars[i] = UInt8(arc4random() % 64)
            }
        } else {
            var j = 0
            for i in (0 ..< 12).reversed() {
                j = i
                guard lastRandChars[i] == 63 else { break }
                lastRandChars[i] = 0
            }
            lastRandChars[j] += 1
        }
        for i in 0 ..< 12 {
            let offset = Int(lastRandChars[i])
            let index = PUSH_CHARS.index(PUSH_CHARS.startIndex, offsetBy: offset)
            id.append(PUSH_CHARS[index])
        }

        return id
    }

    @objc public static func successor(_ key: String) -> String {
        var keyAsInt: Int = 0
        if tryParseStringToInt(key, integer: &keyAsInt) {
            if keyAsInt == Int(Int32.max) {
                return String(MIN_PUSH_CHAR)
            }
            return "\(keyAsInt + 1)"
        }
        if key.count < MAX_KEY_LEN {
            return key + String(MIN_PUSH_CHAR)
        }

        var next = key
        guard let index = next.lastIndex(where: { $0 != MAX_PUSH_CHAR }) else {
            // `successor` was called on the largest possible key, so return the
            // maxName, which sorts larger than all keys.
            return FUtilitiesSwift.maxName
        }
        let source = next[index]

        if let sourceIndex = PUSH_CHARS.firstIndex(of: source) {
            let sourcePlusOne = PUSH_CHARS[PUSH_CHARS.index(sourceIndex, offsetBy: 1)]
            next.replaceSubrange(index...index, with: String(sourcePlusOne))
            return String(next[next.startIndex...index])
        }
        fatalError("Existing implementation crashes if 'source' character is not included in PUSH_CHARS, so we may as well do the same...")
    }

    // `key` is assumed to be non-empty
    #warning("It would perhaps be good to assert this, or even to support this, because even though keys can't be empty, queryBefore for instance may make sence on an empty String...")
    // In this implementation 'key' is not assumed to be non-empty, but the key that comes
    // before the empty string is Int32.max
    @objc public static func predecessor(_ key: String) -> String {
        var keyAsInt: Int = 0
        if tryParseStringToInt(key, integer: &keyAsInt) {
            if keyAsInt == Int(Int32.min) {
                return FUtilitiesSwift.minName
            }
            return "\(keyAsInt - 1)"
        }
        if key.last == MIN_PUSH_CHAR {
            if key.count == 1 {
                return "\(Int32.max)"
            }
            // If the last character is the smallest possible character, then the
            // next smallest string is the prefix of `key` without it.
            return String(key.dropLast())
        }
        var next = key
        // Replace the last character with its immedate predecessor, and fill the
        // suffix of the key with MAX_PUSH_CHAR. This is the lexicographically
        // largest possible key smaller than `key`.
        guard let curr = next.last else {
            return "\(Int32.max)"
        }
        if let sourceIndex = PUSH_CHARS.firstIndex(of: curr) {
            let sourceMinusOne = PUSH_CHARS[PUSH_CHARS.index(sourceIndex, offsetBy: -1)]
            let index = next.index(before: next.endIndex)
            next.replaceSubrange(index...index, with: String(sourceMinusOne))
            return next.padding(toLength: MAX_KEY_LEN, withPad: String(MAX_PUSH_CHAR), startingAt: 0)
        }
        fatalError("Existing implementation crashes if 'curr' character is not included in PUSH_CHARS, so we may as well do the same...")

    }
}
