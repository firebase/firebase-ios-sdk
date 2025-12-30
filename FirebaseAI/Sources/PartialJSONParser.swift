// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// A parser that attempts to parse partial JSON strings into `JSONValue`.
///
/// This parser is tolerant of incomplete JSON structures (e.g., unclosed objects, arrays, strings)
/// and attempts to return the valid structure parsed so far. This is useful for streaming
/// applications where JSON is received in chunks.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class PartialJSONParser {
  private let input: [Character]
  private var index: Int
  private let length: Int

  init(input: String) {
    self.input = Array(input)
    index = 0
    length = self.input.count
  }

  /// Parses the input string into a `JSONValue`.
  /// Returns `nil` if the input is empty or cannot be parsed as a value.
  func parse() -> JSONValue? {
    skipWhitespace()
    if index >= length {
      return nil
    }
    return parseValue()
  }

  private func parseValue() -> JSONValue? {
    skipWhitespace()
    if index >= length { return nil }

    let char = input[index]
    switch char {
    case "{":
      return parseObject()
    case "[":
      return parseArray()
    case "\"":
      return parseString()
    case "t":
      return parseTrue()
    case "f":
      return parseFalse()
    case "n":
      return parseNull()
    case "-", "0" ... "9":
      return parseNumber()
    default:
      // If we encounter an unexpected character, we might be in an invalid state.
      return nil
    }
  }

  private func parseObject() -> JSONValue {
    // Consume '{'
    index += 1

    var object: JSONObject = [:]

    while index < length {
      skipWhitespace()
      if index >= length {
        // EOF inside object, return what we have
        return .object(object)
      }

      let char = input[index]
      if char == "}" {
        index += 1
        return .object(object)
      }

      // Expect key
      if char == "\"" {
        // Parse key
        // parseString returns .string(val) or .null (actually never .null if called on quote)
        if case let .string(key) = parseString() {
          skipWhitespace()

          // Expect ':'
          if index < length, input[index] == ":" {
            index += 1 // consume ':'
            if let value = parseValue() {
              object[key] = value
            }
            // If value is nil (EOF), we ignore this key
          }
        }
      } else {
        // Unexpected character in object, maybe a comma?
        if char == "," {
          index += 1
          continue
        }
        // Invalid or unexpected, abort and return what we have
        return .object(object)
      }
    }

    return .object(object)
  }

  private func parseArray() -> JSONValue {
    // Consume '['
    index += 1

    var array: [JSONValue] = []

    while index < length {
      skipWhitespace()
      if index >= length {
        return .array(array)
      }

      let char = input[index]
      if char == "]" {
        index += 1
        return .array(array)
      }

      if char == "," {
        index += 1
        continue
      }

      if let value = parseValue() {
        array.append(value)
      } else {
        // EOF or invalid
        return .array(array)
      }
    }

    return .array(array)
  }

  private func parseString() -> JSONValue {
    // Consume '"'
    index += 1

    var string = ""
    var escaped = false

    while index < length {
      let char = input[index]
      index += 1

      if escaped {
        // Handle basic escapes
        switch char {
        case "\"": string.append("\"")
        case "\\": string.append("\\")
        case "/": string.append("/")
        case "b": string.append("\u{08}")
        case "f": string.append("\u{0C}")
        case "n": string.append("\n")
        case "r": string.append("\r")
        case "t": string.append("\t")
        case "u":
          // Unicode escape
          // Need 4 chars
          if index + 4 <= length {
            let hex = String(input[index ..< index + 4])
            if let scalar = Int(hex, radix: 16), let uScalar = UnicodeScalar(scalar) {
              string.append(Character(uScalar))
              index += 4
            } else {
              // Invalid unicode, just append u...
              string.append("\\u")
            }
          } else {
            // Incomplete unicode
            string.append("\\u")
            // And we are probably near EOF
          }
        default:
          string.append(char)
        }
        escaped = false
      } else {
        if char == "\"" {
          return .string(string)
        } else if char == "\\" {
          escaped = true
        } else {
          string.append(char)
        }
      }
    }

    // Hit EOF without closing quote
    // Return what we have
    return .string(string)
  }

  private func parseNumber() -> JSONValue? {
    let start = index
    var tempIndex = index

    // Consume all possible numeric characters
    while tempIndex < length {
      let char = input[tempIndex]
      if "0123456789-+.eE".contains(char) {
        tempIndex += 1
      } else {
        break
      }
    }

    // Backtrack from the end of the numeric-like segment to find the longest valid Double.
    var potentialEndIndex = tempIndex
    while potentialEndIndex > start {
      let numberString = String(input[start ..< potentialEndIndex])
      if let double = Double(numberString) {
        // Found a valid number. Commit index and return.
        index = potentialEndIndex
        return .number(double)
      }
      potentialEndIndex -= 1
    }

    // No valid number prefix found. Don't advance index.
    return nil
  }

  private func parseTrue() -> JSONValue? {
    // Expect "true"
    if match("true") { return .bool(true) }
    return nil
  }

  private func parseFalse() -> JSONValue? {
    if match("false") { return .bool(false) }
    return nil
  }

  private func parseNull() -> JSONValue? {
    if match("null") { return .null }
    return nil
  }

  private func match(_ string: String) -> Bool {
    let chars = Array(string)
    if index + chars.count <= length {
      if Array(input[index ..< index + chars.count]) == chars {
        index += chars.count
        return true
      }
    }
    return false
  }

  private func skipWhitespace() {
    while index < length {
      let char = input[index]
      if char.isWhitespace {
        index += 1
      } else {
        break
      }
    }
  }
}
