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

#if compiler(>=6.4)
  /// The lenient, partial JSON parser behind ``GeneratedContent/init(json:)``.
  ///
  /// The rules match the observable behavior of Apple's framework. Parsing runs in two passes,
  /// each with its own error message:
  ///
  /// 1. **Completion check.** A character-level scan that tracks open containers and object
  ///    key/colon/value positions, and decides whether the text could be completed into JSON. It
  ///    treats every run of scalar characters (`0-9 + - . e E` and the letters of `true`, `false`,
  ///    and `null`) as one token without validating it, and it's lax about commas. Failures throw
  ///    ``cannotCompleteMessage``.
  /// 2. **Conversion.** A recursive-descent parser that builds the ``ContentNode`` tree and
  ///    validates tokens. Failures throw ``cannotConvertMessage``.
  ///
  /// Partial input rules:
  ///
  /// - Unclosed strings, arrays, and objects are kept and marked incomplete.
  /// - A number is incomplete when its token runs to the end of the text, so top-level numbers are
  ///   never complete. Trailing `.`, `e`, `E`, `+`, and `-` are trimmed from such a number (`12.` →
  ///   12, `1e+` → 1); if nothing is left, the value is dropped (`{"a": -` → `{}`) or, at the top
  ///   level, the parse fails.
  /// - Partial literals (`tr`, `nul`) fail.
  /// - An incomplete escape at the end of a string is dropped; a lone high surrogate fails.
  /// - A key without a value is dropped. Duplicate keys keep the first value. Trailing commas are
  ///   accepted. Parsed objects have no explicit key order.
  /// - Text nested deeper than ``maximumDepth`` fails with ``tooDeepMessage`` followed by the
  ///   depth (no `Text:` line), after the completion check and before conversion. The depth is the
  ///   largest number of open arrays and objects around any token: a container, a scalar or string
  ///   value (even partial), or a closed key. An unclosed key doesn't count. For example, 121
  ///   nested empty arrays parse, and 122 fail. The limit also keeps the recursive conversion and
  ///   serialization well within a secondary thread's stack.
  enum PartialJSONParser {
    /// The largest nesting depth the parser accepts.
    static let maximumDepth = 120

    /// The message prefix for text nested deeper than ``maximumDepth``.
    static let tooDeepMessage = "The JSON is nested too deeply. Depth: "

    /// The message for text that can't be completed into valid JSON.
    static let cannotCompleteMessage = "The text can't be completed into valid JSON"

    /// The message for text that can't be converted into generated content.
    static let cannotConvertMessage = "The text couldn't be converted to generated content"

    /// Parses possibly incomplete JSON text.
    ///
    /// - Parameter text: The JSON text.
    /// - Returns: The parsed node.
    /// - Throws: ``GeneratedContent/ParsingError`` with the parser's messages.
    static func parse(_ text: String) throws(GeneratedContent.ParsingError) -> ContentNode {
      let bytes = Array(text.utf8)
      guard let depth = CompletionChecker.maximumDepth(of: bytes) else {
        throw error(cannotCompleteMessage, text: text)
      }
      guard depth <= maximumDepth else {
        throw GeneratedContent.ParsingError(
          rawContent: text, debugDescription: tooDeepMessage + "\(depth)")
      }
      var converter = Converter(bytes: bytes)
      guard let node = converter.parseDocument() else {
        throw error(cannotConvertMessage, text: text)
      }
      return node
    }

    /// Creates a parsing error with the parser's message format.
    ///
    /// - Parameters:
    ///   - message: The first line of the debug description.
    ///   - text: The text that failed to parse.
    /// - Returns: A parsing error whose `rawContent` is `text`.
    private static func error(_ message: String, text: String) -> GeneratedContent.ParsingError {
      GeneratedContent.ParsingError(rawContent: text, debugDescription: "\(message)\nText: \(text)")
    }
  }

  // MARK: - Byte classes

  extension UInt8 {
    /// ASCII `"`.
    fileprivate static let quote = UInt8(ascii: "\"")
    /// ASCII `\`.
    fileprivate static let backslash = UInt8(ascii: "\\")
    /// ASCII `{`.
    fileprivate static let openBrace = UInt8(ascii: "{")
    /// ASCII `}`.
    fileprivate static let closeBrace = UInt8(ascii: "}")
    /// ASCII `[`.
    fileprivate static let openBracket = UInt8(ascii: "[")
    /// ASCII `]`.
    fileprivate static let closeBracket = UInt8(ascii: "]")
    /// ASCII `,`.
    fileprivate static let comma = UInt8(ascii: ",")
    /// ASCII `:`.
    fileprivate static let colon = UInt8(ascii: ":")

    /// Whether the byte is JSON whitespace.
    fileprivate var isJSONWhitespace: Bool {
      self == 0x20 || self == 0x09 || self == 0x0A || self == 0x0D
    }

    /// Whether the byte is an ASCII digit.
    fileprivate var isDigit: Bool {
      self >= UInt8(ascii: "0") && self <= UInt8(ascii: "9")
    }

    /// Whether the byte can start a scalar token (a number or a literal).
    fileprivate var startsScalar: Bool {
      isDigit || self == UInt8(ascii: "-") || self == UInt8(ascii: "+")
        || self == UInt8(ascii: "t") || self == UInt8(ascii: "f") || self == UInt8(ascii: "n")
    }

    /// Whether the byte can continue a scalar token: number characters and the letters of `true`,
    /// `false`, and `null`.
    fileprivate var continuesScalar: Bool {
      if isDigit {
        return true
      }
      switch self {
      case UInt8(ascii: "+"), UInt8(ascii: "-"), UInt8(ascii: "."), UInt8(ascii: "e"),
        UInt8(ascii: "E"), UInt8(ascii: "t"), UInt8(ascii: "r"), UInt8(ascii: "u"),
        UInt8(ascii: "f"), UInt8(ascii: "a"), UInt8(ascii: "l"), UInt8(ascii: "s"),
        UInt8(ascii: "n"):
        return true
      default:
        return false
      }
    }

    /// Whether the byte can be trimmed from the end of a number cut off by the end of the text.
    fileprivate var isTrimmableNumberSuffix: Bool {
      switch self {
      case UInt8(ascii: "."), UInt8(ascii: "e"), UInt8(ascii: "E"), UInt8(ascii: "+"),
        UInt8(ascii: "-"):
        return true
      default:
        return false
      }
    }

    /// The value of the byte as a hexadecimal digit, if it is one.
    fileprivate var hexValue: UInt32? {
      switch self {
      case UInt8(ascii: "0")...UInt8(ascii: "9"): return UInt32(self - UInt8(ascii: "0"))
      case UInt8(ascii: "a")...UInt8(ascii: "f"): return UInt32(self - UInt8(ascii: "a") + 10)
      case UInt8(ascii: "A")...UInt8(ascii: "F"): return UInt32(self - UInt8(ascii: "A") + 10)
      default: return nil
      }
    }
  }

  // MARK: - Pass 1: completion check

  /// Decides whether text could be completed into valid JSON.
  private enum CompletionChecker {
    /// Where the scan is inside an object.
    enum ObjectPosition {
      /// After `{` or `,`: expecting a key, `}`, or (laxly) another `,`.
      case expectingKey
      /// After a key: expecting `:`.
      case expectingColon
      /// After `:`: expecting a value.
      case expectingValue
      /// After a value: expecting `,` or `}`.
      case afterValue
    }

    /// An open container.
    enum Frame {
      /// An array. Arrays don't track separators.
      case array
      /// An object at the given position.
      case object(ObjectPosition)
    }

    /// Checks whether `bytes` could be completed into valid JSON and measures its nesting.
    ///
    /// - Parameter bytes: The UTF-8 text.
    /// - Returns: The largest number of open containers around any token (see
    ///   ``PartialJSONParser``), or `nil` if the text contains content that can't be part of valid
    ///   JSON.
    static func maximumDepth(of bytes: [UInt8]) -> Int? {
      var stack: [Frame] = []
      var index = 0
      var depth = 0

      /// Records a token at the current nesting depth.
      func noteToken() {
        depth = max(depth, stack.count)
      }

      /// Records that a value finished in the innermost container.
      func finishValue() {
        if case .object(.expectingValue)? = stack.last {
          stack[stack.count - 1] = .object(.afterValue)
        }
      }

      while index < bytes.count {
        let byte = bytes[index]
        if byte.isJSONWhitespace {
          index += 1
          continue
        }
        if case .object(let position)? = stack.last {
          switch position {
          case .expectingKey:
            if byte == .quote {
              let end = endOfString(in: bytes, from: index)
              if end.isClosed {
                noteToken()
              }
              index = end.index
              stack[stack.count - 1] = .object(.expectingColon)
            } else if byte == .closeBrace {
              stack.removeLast()
              finishValue()
              index += 1
            } else if byte == .comma {
              index += 1
            } else {
              return nil
            }
            continue
          case .expectingColon:
            guard byte == .colon else { return nil }
            stack[stack.count - 1] = .object(.expectingValue)
            index += 1
            continue
          case .afterValue:
            if byte == .comma {
              stack[stack.count - 1] = .object(.expectingKey)
            } else if byte == .closeBrace {
              stack.removeLast()
              finishValue()
            } else {
              return nil
            }
            index += 1
            continue
          case .expectingValue:
            break
          }
        }

        // A value position: the top level, inside an array, or after `:` in an object.
        if byte == .openBrace || byte == .openBracket {
          noteToken()
          finishValue()
          stack.append(byte == .openBrace ? .object(.expectingKey) : .array)
          index += 1
        } else if byte == .quote {
          noteToken()
          index = endOfString(in: bytes, from: index).index
          finishValue()
        } else if byte.startsScalar {
          noteToken()
          while index < bytes.count, bytes[index].continuesScalar {
            index += 1
          }
          finishValue()
        } else if case .array? = stack.last, byte == .closeBracket {
          stack.removeLast()
          finishValue()
          index += 1
        } else if case .array? = stack.last, byte == .comma {
          index += 1
        } else {
          return nil
        }
      }
      return depth
    }

    /// Finds the end of the string that starts at `start`.
    ///
    /// - Parameters:
    ///   - bytes: The UTF-8 text.
    ///   - start: The index of the opening quote.
    /// - Returns: The index just past the closing quote (or the end of the text if the string isn't
    ///   closed), and whether the closing quote was found.
    static func endOfString(in bytes: [UInt8], from start: Int) -> (index: Int, isClosed: Bool) {
      var index = start + 1
      while index < bytes.count {
        switch bytes[index] {
        case .quote:
          return (index + 1, true)
        case .backslash:
          index += 2
        default:
          index += 1
        }
      }
      return (bytes.count, false)
    }
  }

  // MARK: - Pass 2: conversion

  /// Converts text that passed the completion check into a node tree.
  private struct Converter {
    /// The result of parsing one string.
    struct ParsedString {
      /// The decoded string, without any incomplete trailing escape.
      var value: String
      /// Whether the closing quote was found.
      var isComplete: Bool
    }

    /// The UTF-8 text.
    let bytes: [UInt8]

    /// The current read position.
    var index = 0

    /// Creates a converter for the given text.
    ///
    /// - Parameter bytes: The UTF-8 text.
    init(bytes: [UInt8]) {
      self.bytes = bytes
    }

    /// Whether the read position is at the end of the text.
    var isAtEnd: Bool { index >= bytes.count }

    /// Advances past whitespace.
    mutating func skipWhitespace() {
      while index < bytes.count, bytes[index].isJSONWhitespace {
        index += 1
      }
    }

    /// Parses the whole text as a single value.
    ///
    /// - Returns: The node, or `nil` if the text can't be converted.
    mutating func parseDocument() -> ContentNode? {
      skipWhitespace()
      guard !isAtEnd, let node = try? parseValue() else { return nil }
      skipWhitespace()
      return isAtEnd ? node : nil
    }

    /// The conversion failed.
    struct Failure: Error {}

    /// Parses the value at the read position, which must be a non-whitespace byte.
    ///
    /// - Returns: The node, or `nil` if the value was cut off before it had any content (a number
    ///   that is only a sign, for example) and should be dropped.
    /// - Throws: ``Failure`` if the value is invalid.
    mutating func parseValue() throws(Failure) -> ContentNode? {
      switch bytes[index] {
      case .openBrace:
        return try parseObject()
      case .openBracket:
        return try parseArray()
      case .quote:
        let string = try parseString()
        return ContentNode(.string(string.value), isComplete: string.isComplete)
      case UInt8(ascii: "t"), UInt8(ascii: "f"), UInt8(ascii: "n"):
        return try parseLiteral()
      case let byte where byte.startsScalar:
        return try parseNumber()
      default:
        throw Failure()
      }
    }

    /// Parses an object starting at `{`.
    ///
    /// - Returns: The object node, complete only if it's closed.
    /// - Throws: ``Failure`` if the object is malformed.
    mutating func parseObject() throws(Failure) -> ContentNode {
      index += 1
      var properties: [String: ContentNode] = [:]

      /// The object so far, cut off by the end of the text.
      func incomplete() -> ContentNode {
        ContentNode(.object(properties: properties, order: nil), isComplete: false)
      }

      while true {
        skipWhitespace()
        guard !isAtEnd else { return incomplete() }
        if bytes[index] == .closeBrace {
          index += 1
          return ContentNode(.object(properties: properties, order: nil))
        }
        guard bytes[index] == .quote else { throw Failure() }
        let key = try parseString()
        guard key.isComplete else { return incomplete() }
        skipWhitespace()
        guard !isAtEnd else { return incomplete() }
        guard bytes[index] == .colon else { throw Failure() }
        index += 1
        skipWhitespace()
        guard !isAtEnd else { return incomplete() }
        guard let value = try parseValue() else { return incomplete() }
        if properties[key.value] == nil {
          properties[key.value] = value
        }
        skipWhitespace()
        guard !isAtEnd else { return incomplete() }
        switch bytes[index] {
        case .comma:
          index += 1
        case .closeBrace:
          index += 1
          return ContentNode(.object(properties: properties, order: nil))
        default:
          throw Failure()
        }
      }
    }

    /// Parses an array starting at `[`.
    ///
    /// - Returns: The array node, complete only if it's closed.
    /// - Throws: ``Failure`` if the array is malformed.
    mutating func parseArray() throws(Failure) -> ContentNode {
      index += 1
      var elements: [ContentNode] = []

      /// The array so far, cut off by the end of the text.
      func incomplete() -> ContentNode {
        ContentNode(.array(elements), isComplete: false)
      }

      while true {
        skipWhitespace()
        guard !isAtEnd else { return incomplete() }
        if bytes[index] == .closeBracket {
          index += 1
          return ContentNode(.array(elements))
        }
        guard let element = try parseValue() else { return incomplete() }
        elements.append(element)
        skipWhitespace()
        guard !isAtEnd else { return incomplete() }
        switch bytes[index] {
        case .comma:
          index += 1
        case .closeBracket:
          index += 1
          return ContentNode(.array(elements))
        default:
          throw Failure()
        }
      }
    }

    /// Scans a scalar token at the read position.
    ///
    /// - Returns: The token's bytes and whether it runs to the end of the text.
    mutating func scanScalarToken() -> (token: ArraySlice<UInt8>, reachesEnd: Bool) {
      let start = index
      while index < bytes.count, bytes[index].continuesScalar {
        index += 1
      }
      return (bytes[start..<index], isAtEnd)
    }

    /// Parses `true`, `false`, or `null`. Partial literals fail.
    ///
    /// - Returns: The literal node, which is always complete.
    /// - Throws: ``Failure`` if the token isn't exactly a literal.
    mutating func parseLiteral() throws(Failure) -> ContentNode {
      let token = scanScalarToken().token
      if token.elementsEqual("true".utf8) {
        return ContentNode(.bool(true))
      }
      if token.elementsEqual("false".utf8) {
        return ContentNode(.bool(false))
      }
      if token.elementsEqual("null".utf8) {
        return .null
      }
      throw Failure()
    }

    /// Parses a number.
    ///
    /// - Returns: The number node, incomplete if its token runs to the end of the text, or `nil` if
    ///   the number was cut off before its first digit.
    /// - Throws: ``Failure`` if the token isn't a valid JSON number.
    mutating func parseNumber() throws(Failure) -> ContentNode? {
      var (token, reachesEnd) = scanScalarToken()
      if reachesEnd {
        while let last = token.last, last.isTrimmableNumberSuffix {
          token.removeLast()
        }
        if token.isEmpty {
          return nil
        }
      }
      // JSON has no NaN or infinity, so a number too large for `Double` doesn't parse.
      guard Converter.isValidNumber(token),
        let value = Double(String(decoding: token, as: UTF8.self)),
        value.isFinite
      else {
        throw Failure()
      }
      return ContentNode(.number(value), isComplete: !reachesEnd)
    }

    /// Returns whether `token` matches the JSON number grammar
    /// `-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?`.
    ///
    /// - Parameter token: The number's bytes.
    /// - Returns: Whether the token is a valid JSON number.
    static func isValidNumber(_ token: ArraySlice<UInt8>) -> Bool {
      var index = token.startIndex

      /// Consumes digits and returns how many there were.
      func digits() -> Int {
        let start = index
        while index < token.endIndex, token[index].isDigit {
          index += 1
        }
        return index - start
      }

      if index < token.endIndex, token[index] == UInt8(ascii: "-") {
        index += 1
      }
      guard index < token.endIndex else { return false }
      if token[index] == UInt8(ascii: "0") {
        index += 1
      } else if digits() == 0 {
        return false
      }
      if index < token.endIndex, token[index] == UInt8(ascii: ".") {
        index += 1
        guard digits() > 0 else { return false }
      }
      if index < token.endIndex,
        token[index] == UInt8(ascii: "e") || token[index] == UInt8(ascii: "E")
      {
        index += 1
        if index < token.endIndex,
          token[index] == UInt8(ascii: "+") || token[index] == UInt8(ascii: "-")
        {
          index += 1
        }
        guard digits() > 0 else { return false }
      }
      return index == token.endIndex
    }

    /// Parses a string starting at `"`.
    ///
    /// - Returns: The decoded string and whether it was closed. An incomplete escape at the end of
    ///   the text is dropped.
    /// - Throws: ``Failure`` for raw control characters, invalid escapes, and unpaired surrogates.
    mutating func parseString() throws(Failure) -> ParsedString {
      index += 1
      var scalars = String.UnicodeScalarView()
      var segmentStart = index
      var pendingHighSurrogate: UInt32?

      /// Appends the raw UTF-8 bytes since `segmentStart`.
      func flush(upTo end: Int) {
        if segmentStart < end {
          scalars.append(
            contentsOf: String(decoding: bytes[segmentStart..<end], as: UTF8.self)
              .unicodeScalars)
        }
      }

      while index < bytes.count {
        let byte = bytes[index]
        if byte == .quote {
          guard pendingHighSurrogate == nil else { throw Failure() }
          flush(upTo: index)
          index += 1
          return ParsedString(value: String(scalars), isComplete: true)
        }
        if byte < 0x20 {
          throw Failure()
        }
        if byte != .backslash {
          guard pendingHighSurrogate == nil else { throw Failure() }
          index += 1
          continue
        }

        flush(upTo: index)
        // An escape cut off by the end of the text is dropped.
        segmentStart = bytes.count
        guard index + 1 < bytes.count else {
          index = bytes.count
          break
        }
        let escape = bytes[index + 1]
        if escape == UInt8(ascii: "u") {
          let digitsStart = index + 2
          let digitsEnd = min(digitsStart + 4, bytes.count)
          var codeUnit: UInt32 = 0
          for digit in bytes[digitsStart..<digitsEnd] {
            guard let value = digit.hexValue else { throw Failure() }
            codeUnit = codeUnit << 4 | value
          }
          guard digitsEnd - digitsStart == 4 else {
            index = bytes.count
            break
          }
          index = digitsEnd
          switch codeUnit {
          case 0xD800...0xDBFF:
            guard pendingHighSurrogate == nil else { throw Failure() }
            pendingHighSurrogate = codeUnit
          case 0xDC00...0xDFFF:
            guard let high = pendingHighSurrogate,
              let scalar = Unicode.Scalar(0x10000 + ((high - 0xD800) << 10) + (codeUnit - 0xDC00))
            else {
              throw Failure()
            }
            pendingHighSurrogate = nil
            scalars.append(scalar)
          default:
            guard pendingHighSurrogate == nil, let scalar = Unicode.Scalar(codeUnit) else {
              throw Failure()
            }
            scalars.append(scalar)
          }
        } else {
          guard pendingHighSurrogate == nil else { throw Failure() }
          let scalar: Unicode.Scalar
          switch escape {
          case .quote: scalar = "\""
          case .backslash: scalar = "\\"
          case UInt8(ascii: "/"): scalar = "/"
          case UInt8(ascii: "b"): scalar = "\u{08}"
          case UInt8(ascii: "f"): scalar = "\u{0C}"
          case UInt8(ascii: "n"): scalar = "\n"
          case UInt8(ascii: "r"): scalar = "\r"
          case UInt8(ascii: "t"): scalar = "\t"
          default: throw Failure()
          }
          scalars.append(scalar)
          index += 2
        }
        segmentStart = index
      }

      // The text ended inside the string.
      guard pendingHighSurrogate == nil else { throw Failure() }
      flush(upTo: index)
      return ParsedString(value: String(scalars), isComplete: false)
    }
  }
#endif  // compiler(>=6.4)
