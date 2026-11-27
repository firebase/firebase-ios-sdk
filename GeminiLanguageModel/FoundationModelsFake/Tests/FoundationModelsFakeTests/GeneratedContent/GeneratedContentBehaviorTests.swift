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
  import Foundation
  import Testing

  @testable import FoundationModelsFake

  /// `GeneratedContent` behavior that matches Apple's framework. None of these cases branch by
  /// platform, so they also run on Linux.
  @Suite("GeneratedContent behavior")
  struct GeneratedContentBehaviorTests {
    /// A `uniquingKeysWith` combiner used by these tests.
    enum Combiner: String, CaseIterable, Sendable {
      /// Keeps the first value.
      case first
      /// Keeps the second value.
      case second
      /// Adds the two values.
      case sum
      /// Returns a constant.
      case constant
      /// Returns a fresh copy of the first value.
      case copyOfFirst
      /// Returns a fresh copy of the second value.
      case copyOfSecond

      /// Combines two values.
      ///
      /// - Parameters:
      ///   - first: The existing value.
      ///   - second: The new value.
      /// - Returns: The combined value.
      func combine(_ first: GeneratedContent, _ second: GeneratedContent) throws -> GeneratedContent
      {
        switch self {
        case .first: return first
        case .second: return second
        case .sum: return GeneratedContent(try first.value(Int.self) + second.value(Int.self))
        case .constant: return GeneratedContent(99)
        case .copyOfFirst: return GeneratedContent(kind: first.kind)
        case .copyOfSecond: return GeneratedContent(kind: second.kind)
        }
      }
    }

    /// Apple's results for `GeneratedContent(properties:uniquingKeysWith:)`.
    static let uniquingCases: [(combiner: Combiner, pairs: [(String, Int)], json: String)] = [
      (.sum, [("a", 1), ("b", 2), ("a", 3)], #"{"b": 2, "a": 4}"#),
      (.first, [("a", 1), ("b", 2), ("a", 1)], #"{"a": 1, "b": 2}"#),
      (.second, [("a", 1), ("b", 2), ("a", 1)], #"{"a": 1, "b": 2}"#),
      (.second, [("a", 1), ("b", 2), ("a", 3), ("c", 4), ("a", 5)], #"{"b": 2, "c": 4, "a": 5}"#),
      (.first, [("a", 1), ("b", 2), ("a", 3), ("c", 4), ("a", 5)], #"{"a": 1, "b": 2, "c": 4}"#),
      (.sum, [("a", 1), ("b", 2), ("a", 3), ("c", 4), ("a", 5)], #"{"b": 2, "c": 4, "a": 9}"#),
      (.constant, [("a", 1), ("b", 2), ("a", 3)], #"{"b": 2, "a": 99}"#),
      (.copyOfFirst, [("a", 1), ("b", 2), ("a", 3)], #"{"a": 1, "b": 2}"#),
      (.copyOfSecond, [("a", 1), ("b", 2), ("a", 3)], #"{"b": 2, "a": 3}"#),
    ]

    @Test(arguments: uniquingCases.indices)
    func uniquingKeysOrderMatchesApple(_ index: Int) throws {
      let testCase = Self.uniquingCases[index]
      let pairs = testCase.pairs.map { ($0.0, $0.1 as any ConvertibleToGeneratedContent) }

      let content = try GeneratedContent(
        properties: pairs, uniquingKeysWith: testCase.combiner.combine)

      #expect(content.jsonString == testCase.json, "\(testCase.combiner) \(testCase.pairs)")
    }

    @Test
    func keepingTheFirstValueWithAnIDKeepsItsPosition() {
      let pairs: [(String, any ConvertibleToGeneratedContent)] = [
        ("a", 1), ("b", 2), ("a", GeneratedContent(3, id: GenerationID())),
      ]

      let content = GeneratedContent(properties: pairs, uniquingKeysWith: { first, _ in first })

      #expect(content.jsonString == #"{"a": 1, "b": 2}"#)
    }

    /// Apple's `value(Decimal.self)` results for numbers stored as `Double`.
    static let decimalFromDouble: [(Double, String)] = [
      (0.1, "0.1"), (5, "5"), (1.2345678901234567e19, "12345678901234567168"), (-2.5, "-2.5"),
      (1e-7, "0.0000001"), (3.75, "3.75"), (1e20, "100000000000000000000"), (0.3, "0.3"),
      (1.1, "1.1"), (123.456, "123.45599999999997952"),
    ]

    @Test(arguments: decimalFromDouble)
    func decimalFromContentMatchesApple(value: Double, expected: String) throws {
      let decimal = try GeneratedContent(value).value(Decimal.self)

      #expect(decimal.description == expected)
    }

    /// Apple's `GeneratedContent(_: Decimal).jsonString` results, which follow
    /// `NSDecimalNumber.doubleValue` rather than the nearest double.
    static let decimalToContent: [(String, String)] = [
      ("12345678901234567890.123", "1.234567890123457e+19"), ("0.1", "0.1"), ("3.75", "3.75"),
      ("1e-7", "1.0000000000000002e-07"),
      ("123456789012345678901234567890", "1.2345678901234568e+29"),
      ("-0.000001", "-1.0000000000000002e-06"),
      ("0.3333333333333333333333333", "0.3333333333333333"),
      ("18446744073709551615.5", "1.8446744073709552e+19"), ("1.5e30", "1.5e+30"), ("0", "0"),
    ]

    @Test(arguments: decimalToContent)
    func decimalToContentMatchesApple(decimal: String, expected: String) throws {
      let value = try #require(Decimal(string: decimal))

      let content = GeneratedContent(value)

      #expect(content.jsonString == expected)
    }

    // MARK: - Nesting limit

    /// Builds deeply nested text.
    ///
    /// - Parameters:
    ///   - prefix: Text that opens one level, repeated `count` times.
    ///   - count: The number of levels.
    ///   - suffix: Text appended after the levels.
    /// - Returns: The text.
    static func nested(_ prefix: String, _ count: Int, _ suffix: String = "") -> String {
      String(repeating: prefix, count: count) + suffix
    }

    /// Apple's results for deeply nested input: the depth in "Too many nested arrays or
    /// dictionaries. Depth: <n>", or `nil` when the text parses.
    static let nestingCases: [(label: String, json: String, depth: Int?)] = [
      ("121 arrays", nested("[", 121), nil),
      ("122 arrays", nested("[", 122), 121),
      ("122 closed arrays", nested("[", 122, String(repeating: "]", count: 122)), 121),
      ("1,000,000 arrays", nested("[", 1_000_000), 999_999),
      ("120 arrays and a number", nested("[", 120, "1"), nil),
      ("121 arrays and a number", nested("[", 121, "1"), 121),
      ("121 arrays and a partial string", nested("[", 121, "\"x"), 121),
      ("121 arrays and a partial literal", nested("[", 121, "tr"), 121),
      ("120 objects", nested(#"{"a":"#, 120), nil),
      ("121 objects", nested(#"{"a":"#, 121), 121),
      ("200 objects", nested(#"{"a":"#, 200), 200),
      ("121 objects, unclosed last key", nested(#"{"a":"#, 120, #"{"b"#), nil),
      ("122 objects, unclosed last key", nested(#"{"a":"#, 121, #"{"b"#), 121),
      ("mixed", "[" + nested(#"{"a":"#, 64) + nested("[", 64, "1"), 129),
    ]

    @Test(arguments: nestingCases.indices)
    func nestingLimitMatchesApple(_ index: Int) throws {
      let testCase = Self.nestingCases[index]

      let outcome = Result { try GeneratedContent(json: testCase.json) }

      switch (outcome, testCase.depth) {
      case (.success, nil):
        break
      case (.failure(let error as GeneratedContent.ParsingError), let depth?):
        #expect(
          error.debugDescription == PartialJSONParser.tooDeepMessage + "\(depth)",
          "\(testCase.label)"
        )
        #expect(error.rawContent == testCase.json)
      default:
        Issue.record("\(testCase.label): unexpected outcome \(outcome)")
      }
    }

    @Test
    func completionErrorsTakePrecedenceOverDepth() throws {
      let json = Self.nested("[", 129, "1") + String(repeating: "]", count: 128) + " x"

      let error = try #require(throws: GeneratedContent.ParsingError.self) {
        try GeneratedContent(json: json)
      }

      #expect(
        error.debugDescription == PartialJSONParser.cannotCompleteMessage + "\nText: \(json)"
      )
    }

    @Test
    func conversionErrorsComeAfterTheDepthCheck() throws {
      let json = Self.nested("[", 120, "tr")

      let error = try #require(throws: GeneratedContent.ParsingError.self) {
        try GeneratedContent(json: json)
      }

      #expect(
        error.debugDescription == PartialJSONParser.cannotConvertMessage + "\nText: \(json)"
      )
    }

    @Test
    func nestingAtTheLimitRoundTrips() throws {
      let complete = Self.nested("[", 121, String(repeating: "]", count: 121))

      let completeContent = try GeneratedContent(json: complete)
      let partialContent = try GeneratedContent(json: Self.nested("[", 121))

      #expect(completeContent.isComplete)
      #expect(completeContent.jsonString == complete)
      #expect(!partialContent.isComplete)
      #expect(partialContent.jsonString == complete)
      #expect(completeContent != partialContent)
    }

    // MARK: - Non-finite numbers

    @Test(arguments: ["1e400", "-1e400", "[1e999]", #"{"a": 1e400}"#])
    func numbersOutsideTheDoubleRangeDontParse(json: String) {
      #expect(throws: GeneratedContent.ParsingError.self) {
        try GeneratedContent(json: json)
      }
    }

    @Test
    func numbersThatUnderflowParseAsZero() throws {
      let content = try GeneratedContent(json: "[1e-400]")

      let elements = try [Double](content)

      #expect(elements == [0])
    }

    @Test(arguments: [Double.infinity, -Double.infinity, Double.nan])
    func conversionErrorsForNonFiniteNumbersDontTrap(value: Double) throws {
      let content = GeneratedContent(kind: .number(value))

      let error = try #require(throws: GeneratedContent.ParsingError.self) {
        try String(content)
      }

      #expect(error.debugDescription.contains(value.description))
    }
  }
#endif  // compiler(>=6.4)
