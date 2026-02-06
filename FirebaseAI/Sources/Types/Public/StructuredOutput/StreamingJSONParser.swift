// Copyright 2026 Google LLC
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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class StreamingJSONParser {
  private let input: [UnicodeScalar]
  private var index: Int

  init(_ json: String) {
    input = Array(json.unicodeScalars)
    index = 0
  }

  private func skipWhitespace() {
    while index < input.count {
      let char = input[index]
      if !CharacterSet.whitespacesAndNewlines.contains(char) {
        break
      }
      index += 1
    }
  }

  private func peek() -> UnicodeScalar? {
    guard index < input.count else { return nil }
    return input[index]
  }

  private func advance() -> UnicodeScalar {
    let char = input[index]
    index += 1
    return char
  }

  func parse() -> ModelOutput? {
    skipWhitespace()
    guard let char = peek() else { return nil }

    switch char {
    case "{": return parseObject()
    case "[": return parseArray()
    case "\"": return parseString()
    case "t", "f": return parseBool()
    case "n": return parseNull()
    case "-", "0" ... "9": return parseNumber()
    default: return nil
    }
  }

  private func parseObject() -> ModelOutput {
    _ = advance() // consume '{'
    var properties: [String: ModelOutput] = [:]
    var orderedKeys: [String] = []

    while true {
      skipWhitespace()

      if let char = peek(), char == "}" {
        _ = advance()
        break
      }
      if peek() == nil {
        break
      }

      // Expecting a key (string)
      if peek() != "\"" {
        break
      }

      let keyOutput = parseString()
      guard case let .string(key) = keyOutput.kind else {
        break
      }

      skipWhitespace()

      if let char = peek(), char == ":" {
        _ = advance()
      } else {
        break
      }

      skipWhitespace()

      if let value = parse() {
        properties[key] = value
        orderedKeys.append(key)
      } else {
        // Missing value or partial value (like "1" that returned nil).
        // We don't add this key.
        break
      }

      skipWhitespace()

      if let char = peek() {
        if char == "," {
          _ = advance()
        } else if char == "}" {
          _ = advance()
          break
        } else {
          break
        }
      } else {
        break
      }
    }

    return ModelOutput(kind: .structure(properties: properties, orderedKeys: orderedKeys))
  }

  private func parseArray() -> ModelOutput {
    _ = advance() // consume '['
    var elements: [ModelOutput] = []

    while true {
      skipWhitespace()

      if let char = peek(), char == "]" {
        _ = advance()
        break
      }
      if peek() == nil {
        break
      }

      if let value = parse() {
        elements.append(value)
      } else {
        break
      }

      skipWhitespace()

      if let char = peek() {
        if char == "," {
          _ = advance()
        } else if char == "]" {
          _ = advance()
          break
        } else {
          break
        }
      } else {
        break
      }
    }
    return ModelOutput(kind: .array(elements))
  }

  private func parseString() -> ModelOutput {
    _ = advance() // consume '"'
    var currentString = ""

    while let char = peek() {
      if char == "\"" {
        _ = advance()
        break
      }

      if char == "\\" {
        _ = advance()
        guard let escapeChar = peek() else { break }

        switch escapeChar {
        case "\"", "\\", "/":
          currentString.append(Character(escapeChar))
          _ = advance()
        case "b":
          currentString.append("\u{08}")
          _ = advance()
        case "f":
          currentString.append("\u{0C}")
          _ = advance()
        case "n":
          currentString.append("\n")
          _ = advance()
        case "r":
          currentString.append("\r")
          _ = advance()
        case "t":
          currentString.append("\t")
          _ = advance()
        case "u":
          if index + 5 <= input.count {
            _ = advance() // consume 'u'
            var hexString = ""
            var validHex = true
            for _ in 0 ..< 4 {
              guard let h = peek() else { validHex = false; break }
              if CharacterSet(charactersIn: "0123456789ABCDEFabcdef").contains(h) {
                hexString.append(Character(h))
                _ = advance()
              } else {
                validHex = false; break
              }
            }

            if validHex, let codePoint = Int(hexString, radix: 16),
               let scalar = UnicodeScalar(codePoint) {
              currentString.append(Character(scalar))
            } else {
              // Invalid hex or failure to create scalar. Return partial.
              return ModelOutput(kind: .string(currentString))
            }
          } else {
            // Incomplete unicode escape.
            return ModelOutput(kind: .string(currentString))
          }
        default:
          _ = advance()
        }
      } else {
        currentString.append(Character(char))
        _ = advance()
      }
    }

    return ModelOutput(kind: .string(currentString))
  }

  private func parseBool() -> ModelOutput? {
    if let char = peek(), char == "t" {
      if index + 4 <= input.count {
        let start = index
        if input[start] == "t", input[start + 1] == "r", input[start + 2] == "u",
           input[start + 3] == "e" {
          index += 4
          return ModelOutput(kind: .bool(true))
        }
      }
    } else if let char = peek(), char == "f" {
      if index + 5 <= input.count {
        let start = index
        if input[start] == "f", input[start + 1] == "a", input[start + 2] == "l",
           input[start + 3] == "s", input[start + 4] == "e" {
          index += 5
          return ModelOutput(kind: .bool(false))
        }
      }
    }
    return nil
  }

  private func parseNull() -> ModelOutput? {
    if index + 4 <= input.count {
      let start = index
      if input[start] == "n", input[start + 1] == "u", input[start + 2] == "l",
         input[start + 3] == "l" {
        index += 4
        return ModelOutput(kind: .null)
      }
    }
    return nil
  }

  private func parseNumber() -> ModelOutput? {
    let start = index
    // Optional minus sign
    if index < input.count && input[index] == "-" {
      index += 1
    }

    // Integer part
    if index < input.count && input[index] == "0" {
      index += 1
    } else if index < input.count && CharacterSet(charactersIn: "123456789")
      .contains(input[index]) {
      index += 1
      while index < input.count, CharacterSet(charactersIn: "0123456789").contains(input[index]) {
        index += 1
      }
    } else {
      // Invalid number start
      return nil
    }

    // Fraction part
    if index < input.count && input[index] == "." {
      index += 1
      while index < input.count, CharacterSet(charactersIn: "0123456789").contains(input[index]) {
        index += 1
      }
    }

    // Exponent part
    if index < input.count && (input[index] == "e" || input[index] == "E") {
      index += 1
      if index < input.count, input[index] == "+" || input[index] == "-" {
        index += 1
      }
      while index < input.count, CharacterSet(charactersIn: "0123456789").contains(input[index]) {
        index += 1
      }
    }

    // Check terminator
    guard let char = peek() else {
      // EOF - incomplete number
      return nil
    }

    if CharacterSet.whitespacesAndNewlines
      .contains(char) || char == "," || char == "]" || char == "}" {
      let numberString = String(String.UnicodeScalarView(input[start ..< index]))
      if let doubleVal = Double(numberString) {
        return ModelOutput(kind: .number(doubleVal))
      }
    }
    return nil
  }
}
