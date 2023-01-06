// This file is derived from
// swift-protobuf/Sources/SwiftProtobuf/Google_Protobuf_Duration+Extensions.swift

// Sources/SwiftProtobuf/Google_Protobuf_Duration+Extensions.swift - Extensions for Duration type
//
// Copyright (c) 2014 - 2016 Apple Inc. and the project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See LICENSE.txt for license information:
// https://github.com/apple/swift-protobuf/blob/main/LICENSE.txt
//
// -----------------------------------------------------------------------------
///
/// Extends the generated Duration struct with various custom behaviors:
/// * JSON coding and decoding
/// * Arithmetic operations
///
// -----------------------------------------------------------------------------

import Foundation

private let minDurationSeconds: Int64 = -maxDurationSeconds
private let maxDurationSeconds: Int64 = 315576000000

func parseDuration(text: String) throws -> (Int64, Int32) {
  var digits = [Character]()
  var digitCount = 0
  var total = 0
  var chars = text.makeIterator()
  var seconds: Int64?
  var nanos: Int32 = 0
  var isNegative = false
  while let c = chars.next() {
    switch c {
    case "-":
      // Only accept '-' as very first character
      if total > 0 {
        throw JSONDecodingError.malformedDuration
      }
      digits.append(c)
      isNegative = true
    case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
      digits.append(c)
      digitCount += 1
    case ".":
      if let _ = seconds {
        throw JSONDecodingError.malformedDuration
      }
      let digitString = String(digits)
      if let s = Int64(digitString),
         s >= minDurationSeconds && s <= maxDurationSeconds {
        seconds = s
      } else {
        throw JSONDecodingError.malformedDuration
      }
      digits.removeAll()
      digitCount = 0
    case "s":
      if let _ = seconds {
        // Seconds already set, digits holds nanos
        while (digitCount < 9) {
          digits.append(Character("0"))
          digitCount += 1
        }
        while digitCount > 9 {
          digits.removeLast()
          digitCount -= 1
        }
        let digitString = String(digits)
        if let rawNanos = Int32(digitString) {
          if isNegative {
            nanos = -rawNanos
          } else {
            nanos = rawNanos
          }
        } else {
          throw JSONDecodingError.malformedDuration
        }
      } else {
        // No fraction, we just have an integral number of seconds
        let digitString = String(digits)
        if let s = Int64(digitString),
           s >= minDurationSeconds && s <= maxDurationSeconds {
          seconds = s
        } else {
          throw JSONDecodingError.malformedDuration
        }
      }
      // Fail if there are characters after 's'
      if chars.next() != nil {
        throw JSONDecodingError.malformedDuration
      }
      return (seconds!, nanos)
    default:
      throw JSONDecodingError.malformedDuration
    }
    total += 1
  }
  throw JSONDecodingError.malformedDuration
}

enum JSONDecodingError: Error {
  /// A JSON Duration could not be parsed
  case malformedDuration
}
