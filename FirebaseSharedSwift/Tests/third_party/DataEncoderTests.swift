// This file is derived from swift/test/stdlib/TestJSONEncoder.swift

// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import FirebaseSharedSwift
import Swift
import Foundation

// MARK: - Test Suite

import XCTest

class TestFirebaseDataEncoder: XCTestCase {
  // MARK: - Encoding Top-Level Empty Types

  func testEncodingTopLevelEmptyStruct() {
    let empty = EmptyStruct()
    _testRoundTrip(of: empty, expected: _emptyDictionary)
  }

  func testEncodingTopLevelEmptyClass() {
    let empty = EmptyClass()
    _testRoundTrip(of: empty, expected: _emptyDictionary)
  }

  // MARK: - Encoding Top-Level Single-Value Types

  func testEncodingTopLevelSingleValueEnum() {
    _testRoundTrip(of: Switch.off)
    _testRoundTrip(of: Switch.on)
  }

  func testEncodingTopLevelSingleValueStruct() {
    _testRoundTrip(of: Timestamp(3_141_592_653))
  }

  func testEncodingTopLevelSingleValueClass() {
    _testRoundTrip(of: Counter())
  }

  // MARK: - Encoding Top-Level Structured Types

  func testEncodingTopLevelStructuredStruct() {
    // Address is a struct type with multiple fields.
    let address = Address.testValue
    _testRoundTrip(of: address)
  }

  func testEncodingTopLevelStructuredClass() {
    // Person is a class with multiple fields.
    let expected = ["name": "Johnny Appleseed", "email": "appleseed@apple.com"]
    let person = Person.testValue
    _testRoundTrip(of: person, expected: expected)
  }

  func testEncodingTopLevelStructuredSingleStruct() {
    // Numbers is a struct which encodes as an array through a single value container.
    let numbers = Numbers.testValue
    _testRoundTrip(of: numbers)
  }

  func testEncodingTopLevelStructuredSingleClass() {
    // Mapping is a class which encodes as a dictionary through a single value container.
    let mapping = Mapping.testValue
    _testRoundTrip(of: mapping)
  }

  func testEncodingTopLevelDeepStructuredType() {
    // Company is a type with fields which are Codable themselves.
    let company = Company.testValue
    _testRoundTrip(of: company)
  }

  func testEncodingClassWhichSharesEncoderWithSuper() {
    // Employee is a type which shares its encoder & decoder with its superclass, Person.
    let employee = Employee.testValue
    _testRoundTrip(of: employee)
  }

  func testEncodingTopLevelNullableType() {
    // EnhancedBool is a type which encodes either as a Bool or as nil.
    _testRoundTrip(of: EnhancedBool.true, expected: true)
    _testRoundTrip(of: EnhancedBool.false, expected: false)
    _testRoundTrip(of: EnhancedBool.fileNotFound, expected: NSNull())
  }

  func testEncodingMultipleNestedContainersWithTheSameTopLevelKey() {
    struct Model: Codable, Equatable {
      let first: String
      let second: String

      init(from coder: Decoder) throws {
        let container = try coder.container(keyedBy: TopLevelCodingKeys.self)

        let firstNestedContainer = try container.nestedContainer(
          keyedBy: FirstNestedCodingKeys.self,
          forKey: .top
        )
        first = try firstNestedContainer.decode(String.self, forKey: .first)

        let secondNestedContainer = try container.nestedContainer(
          keyedBy: SecondNestedCodingKeys.self,
          forKey: .top
        )
        second = try secondNestedContainer.decode(String.self, forKey: .second)
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: TopLevelCodingKeys.self)

        var firstNestedContainer = container.nestedContainer(
          keyedBy: FirstNestedCodingKeys.self,
          forKey: .top
        )
        try firstNestedContainer.encode(first, forKey: .first)

        var secondNestedContainer = container.nestedContainer(
          keyedBy: SecondNestedCodingKeys.self,
          forKey: .top
        )
        try secondNestedContainer.encode(second, forKey: .second)
      }

      init(first: String, second: String) {
        self.first = first
        self.second = second
      }

      static var testValue: Model {
        return Model(first: "Johnny Appleseed",
                     second: "appleseed@apple.com")
      }

      enum TopLevelCodingKeys: String, CodingKey {
        case top
      }

      enum FirstNestedCodingKeys: String, CodingKey {
        case first
      }

      enum SecondNestedCodingKeys: String, CodingKey {
        case second
      }
    }

    let model = Model.testValue
    if #available(OSX 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *) {
      let expected = ["top": ["first": "Johnny Appleseed", "second": "appleseed@apple.com"]]
      _testRoundTrip(of: model, expected: expected)
    } else {
      _testRoundTrip(of: model)
    }
  }

  // NOTE: This test causes a precondition error, so I am uncertain about how it ought to be tested.
//  func testEncodingConflictedTypeNestedContainersWithTheSameTopLevelKey() {
//    struct Model : Encodable, Equatable {
//      let first: String
//
//      func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: TopLevelCodingKeys.self)
//
//        var firstNestedContainer = container.nestedContainer(keyedBy: FirstNestedCodingKeys.self, forKey: .top)
//        try firstNestedContainer.encode(self.first, forKey: .first)
//
//        // The following line would fail as it attempts to re-encode into already encoded container is invalid. This will always fail
//        var secondNestedContainer = container.nestedUnkeyedContainer(forKey: .top)
//        try secondNestedContainer.encode("second")
//      }
//
//      init(first: String) {
//        self.first = first
//      }
//
//      static var testValue: Model {
//        return Model(first: "Johnny Appleseed")
//      }
//
//      enum TopLevelCodingKeys : String, CodingKey {
//        case top
//      }
//      enum FirstNestedCodingKeys : String, CodingKey {
//        case first
//      }
//    }
//
//    let model = Model.testValue
//    // This following test would fail as it attempts to re-encode into already encoded container is invalid. This will always fail
//    if #available(OSX 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *) {
//      _testEncodeFailure(of: model)
//    } else {
//      _testEncodeFailure(of: model)
//    }
//  }

  // MARK: - Date Strategy Tests

  // Disabled for now till we resolve rdar://52618414
  func x_testEncodingDate() {
    func formattedLength(of value: Double) -> Int {
      let empty = UnsafeMutablePointer<Int8>.allocate(capacity: 0)
      defer { empty.deallocate() }
      let length = snprintf(ptr: empty, 0, "%0.*g", DBL_DECIMAL_DIG, value)
      return Int(length)
    }

    // Duplicated to handle a special case
    func localTestRoundTrip<T: Codable & Equatable>(of value: T) {
      var payload: Any! = nil
      do {
        let encoder = FirebaseDataEncoder()
        payload = try encoder.encode(value)
      } catch {
        XCTFail("Failed to encode \(T.self): \(error)")
      }

      do {
        let decoder = FirebaseDataDecoder()
        let decoded = try decoder.decode(T.self, from: payload!)

        /// `snprintf`'s `%g`, which `JSONSerialization` uses internally for double values, does not respect
        /// our precision requests in every case. This bug effects Darwin, FreeBSD, and Linux currently
        /// causing this test (which uses the current time) to fail occasionally.
        if formattedLength(of: (decoded as! Date).timeIntervalSinceReferenceDate) >
          DBL_DECIMAL_DIG +
          2 {
          let adjustedTimeIntervalSinceReferenceDate: (Date) -> Double = { date in
            let adjustment = pow(10, Double(DBL_DECIMAL_DIG))
            return Double(floor(adjustment * date.timeIntervalSinceReferenceDate)
              .rounded() / adjustment)
          }

          let decodedAprox = adjustedTimeIntervalSinceReferenceDate(decoded as! Date)
          let valueAprox = adjustedTimeIntervalSinceReferenceDate(value as! Date)
          XCTAssertEqual(
            decodedAprox,
            valueAprox,
            "\(T.self) did not round-trip to an equal value after DBL_DECIMAL_DIG adjustment \(decodedAprox) != \(valueAprox)."
          )
          return
        }

        XCTAssertEqual(
          decoded,
          value,
          "\(T.self) did not round-trip to an equal value. \((decoded as! Date).timeIntervalSinceReferenceDate) != \((value as! Date).timeIntervalSinceReferenceDate)"
        )
      } catch {
        XCTFail("Failed to decode \(T.self): \(error)")
      }
    }

    // Test the above `snprintf` edge case evaluation with a known triggering case
    let knownBadDate = Date(timeIntervalSinceReferenceDate: 0.0021413276231263384)
    localTestRoundTrip(of: knownBadDate)

    localTestRoundTrip(of: Date())

    // Optional dates should encode the same way.
    localTestRoundTrip(of: Optional(Date()))
  }

  func testEncodingDateSecondsSince1970() {
    // Cannot encode an arbitrary number of seconds since we've lost precision since 1970.
    let seconds = 1000.0
    let expected = 1000

    _testRoundTrip(of: Date(timeIntervalSince1970: seconds),
                   expected: expected,
                   dateEncodingStrategy: .secondsSince1970,
                   dateDecodingStrategy: .secondsSince1970)

    // Optional dates should encode the same way.
    _testRoundTrip(of: Optional(Date(timeIntervalSince1970: seconds)),
                   expected: expected,
                   dateEncodingStrategy: .secondsSince1970,
                   dateDecodingStrategy: .secondsSince1970)
  }

  func testEncodingDateMillisecondsSince1970() {
    // Cannot encode an arbitrary number of seconds since we've lost precision since 1970.
    let seconds = 1000.0
    let expected = 1_000_000

    _testRoundTrip(of: Date(timeIntervalSince1970: seconds),
                   expected: expected,
                   dateEncodingStrategy: .millisecondsSince1970,
                   dateDecodingStrategy: .millisecondsSince1970)

    // Optional dates should encode the same way.
    _testRoundTrip(of: Optional(Date(timeIntervalSince1970: seconds)),
                   expected: expected,
                   dateEncodingStrategy: .millisecondsSince1970,
                   dateDecodingStrategy: .millisecondsSince1970)
  }

  func testEncodingDateISO8601() {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = .withInternetDateTime

      let timestamp = Date(timeIntervalSince1970: 1000)
      let expected = "\(formatter.string(from: timestamp))"

      _testRoundTrip(of: timestamp,
                     expected: expected,
                     dateEncodingStrategy: .iso8601,
                     dateDecodingStrategy: .iso8601)

      // Optional dates should encode the same way.
      _testRoundTrip(of: Optional(timestamp),
                     expected: expected,
                     dateEncodingStrategy: .iso8601,
                     dateDecodingStrategy: .iso8601)
  }

  func testEncodingDateFormatted() {
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    formatter.timeStyle = .full

    let timestamp = Date(timeIntervalSince1970: 1000)
    let expected = "\(formatter.string(from: timestamp))"

    _testRoundTrip(of: timestamp,
                   expected: expected,
                   dateEncodingStrategy: .formatted(formatter),
                   dateDecodingStrategy: .formatted(formatter))

    // Optional dates should encode the same way.
    _testRoundTrip(of: Optional(timestamp),
                   expected: expected,
                   dateEncodingStrategy: .formatted(formatter),
                   dateDecodingStrategy: .formatted(formatter))
  }

  func testEncodingDateCustom() {
    let timestamp = Date()

    // We'll encode a number instead of a date.
    let encode = { (_ data: Date, _ encoder: Encoder) throws -> Void in
      var container = encoder.singleValueContainer()
      try container.encode(42)
    }
    let decode = { (_: Decoder) throws -> Date in timestamp }

    let expected = 42
    _testRoundTrip(of: timestamp,
                   expected: expected,
                   dateEncodingStrategy: .custom(encode),
                   dateDecodingStrategy: .custom(decode))

    // Optional dates should encode the same way.
    _testRoundTrip(of: Optional(timestamp),
                   expected: expected,
                   dateEncodingStrategy: .custom(encode),
                   dateDecodingStrategy: .custom(decode))
  }

  func testEncodingDateCustomEmpty() {
    let timestamp = Date()

    // Encoding nothing should encode an empty keyed container ({}).
    let encode = { (_: Date, _: Encoder) throws -> Void in }
    let decode = { (_: Decoder) throws -> Date in timestamp }

    let expected: [String: String] = [:]
    _testRoundTrip(of: timestamp,
                   expected: expected,
                   dateEncodingStrategy: .custom(encode),
                   dateDecodingStrategy: .custom(decode))

    // Optional dates should encode the same way.
    _testRoundTrip(of: Optional(timestamp),
                   expected: expected,
                   dateEncodingStrategy: .custom(encode),
                   dateDecodingStrategy: .custom(decode))
  }

  // MARK: - Data Strategy Tests

  func testEncodingData() {
    let data = Data([0xDE, 0xAD, 0xBE, 0xEF])

    let expected = [222, 173, 190, 239]
    _testRoundTrip(of: data,
                   expected: expected,
                   dataEncodingStrategy: .deferredToData,
                   dataDecodingStrategy: .deferredToData)

    // Optional data should encode the same way.
    _testRoundTrip(of: Optional(data),
                   expected: expected,
                   dataEncodingStrategy: .deferredToData,
                   dataDecodingStrategy: .deferredToData)
  }

  func testEncodingDataBase64() {
    let data = Data([0xDE, 0xAD, 0xBE, 0xEF])

    let expected = "3q2+7w=="
    _testRoundTrip(of: data, expected: expected)

    // Optional data should encode the same way.
    _testRoundTrip(of: Optional(data), expected: expected)
  }

  func testEncodingDataBlob() {
    let data = Data([0xDE, 0xAD, 0xBE, 0xEF])

    _testRoundTrip(of: data,
                   expected: data,
                   dataEncodingStrategy: .blob,
                   dataDecodingStrategy: .blob)

    // Optional data should encode the same way.
    _testRoundTrip(of: Optional(data),
                   expected: data,
                   dataEncodingStrategy: .blob,
                   dataDecodingStrategy: .blob)
  }

  func testEncodingData2Blob() {
    let string = "abcdef"
    let data = string.data(using: .utf8)!

    _testRoundTrip(of: data,
                   expected: data,
                   dataEncodingStrategy: .blob,
                   dataDecodingStrategy: .blob)

    // Optional data should encode the same way.
    _testRoundTrip(of: Optional(data),
                   expected: data,
                   dataEncodingStrategy: .blob,
                   dataDecodingStrategy: .blob)
  }

  func testEncodingDataCustom() {
    // We'll encode a number instead of data.
    let encode = { (_ data: Data, _ encoder: Encoder) throws -> Void in
      var container = encoder.singleValueContainer()
      try container.encode(42)
    }
    let decode = { (_: Decoder) throws -> Data in Data() }

    let expected = 42
    _testRoundTrip(of: Data(),
                   expected: expected,
                   dataEncodingStrategy: .custom(encode),
                   dataDecodingStrategy: .custom(decode))

    // Optional data should encode the same way.
    _testRoundTrip(of: Optional(Data()),
                   expected: expected,
                   dataEncodingStrategy: .custom(encode),
                   dataDecodingStrategy: .custom(decode))
  }

  func testEncodingDataCustomEmpty() {
    // Encoding nothing should encode an empty keyed container ({}).
    let encode = { (_: Data, _: Encoder) throws -> Void in }
    let decode = { (_: Decoder) throws -> Data in Data() }

    _testRoundTrip(of: Data(),
                   expected: [:] as [String: String],
                   dataEncodingStrategy: .custom(encode),
                   dataDecodingStrategy: .custom(decode))

    // Optional Data should encode the same way.
    _testRoundTrip(of: Optional(Data()),
                   expected: [:] as [String: String],
                   dataEncodingStrategy: .custom(encode),
                   dataDecodingStrategy: .custom(decode))
  }

  // Tests implicit migration of data that was written with .base64 (String type) using Firestore
  // 10.0 through 10.3 (see PR #10604).
  func testDecodingBase64StringAsBlobData() throws {
    let inputString = "abcdef"
    let data = inputString.data(using: .utf8)!
    let base64String = "YWJjZGVm"

    let encoder = FirebaseDataEncoder()
    encoder.dataEncodingStrategy = .base64
    let payload = try encoder.encode(data)

    XCTAssertEqual(
      base64String,
      try XCTUnwrap(payload as? String, "Encoding did not produce a \(String.self)."),
      "Encoding \"\(inputString)\" did not produce expected the base64 string \"\(base64String)\"."
    )

    let decoder = FirebaseDataDecoder()
    decoder.dataDecodingStrategy = .blob
    let decoded = try decoder.decode(Data.self, from: payload)

    XCTAssertEqual(
      inputString,
      try XCTUnwrap(String(data: decoded, encoding: .utf8)),
      "Decoding base64-encoded payload did not produce original value \"\(inputString)\"."
    )
  }

  // MARK: - Non-Conforming Floating Point Strategy Tests

  func testEncodingNonConformingFloats() {
    _testEncodeFailure(of: Float.infinity)
    _testEncodeFailure(of: Float.infinity)
    _testEncodeFailure(of: -Float.infinity)
    _testEncodeFailure(of: Float.nan)

    _testEncodeFailure(of: Double.infinity)
    _testEncodeFailure(of: -Double.infinity)
    _testEncodeFailure(of: Double.nan)

    // Optional Floats/Doubles should encode the same way.
    _testEncodeFailure(of: Float.infinity)
    _testEncodeFailure(of: -Float.infinity)
    _testEncodeFailure(of: Float.nan)

    _testEncodeFailure(of: Double.infinity)
    _testEncodeFailure(of: -Double.infinity)
    _testEncodeFailure(of: Double.nan)
  }

  func testEncodingNonConformingFloatStrings() {
    let encodingStrategy: FirebaseDataEncoder.NonConformingFloatEncodingStrategy = .convertToString(
      positiveInfinity: "INF",
      negativeInfinity: "-INF",
      nan: "NaN"
    )
    let decodingStrategy: FirebaseDataDecoder.NonConformingFloatDecodingStrategy = .convertFromString(
      positiveInfinity: "INF",
      negativeInfinity: "-INF",
      nan: "NaN"
    )

    _testRoundTrip(of: Float.infinity,
                   expected: "INF",
                   nonConformingFloatEncodingStrategy: encodingStrategy,
                   nonConformingFloatDecodingStrategy: decodingStrategy)
    _testRoundTrip(of: -Float.infinity,
                   expected: "-INF",
                   nonConformingFloatEncodingStrategy: encodingStrategy,
                   nonConformingFloatDecodingStrategy: decodingStrategy)

    // Since Float.nan != Float.nan, we have to use a placeholder that'll encode NaN but actually round-trip.
    _testRoundTrip(of: FloatNaNPlaceholder(),
                   expected: "NaN",
                   nonConformingFloatEncodingStrategy: encodingStrategy,
                   nonConformingFloatDecodingStrategy: decodingStrategy)

    _testRoundTrip(of: Double.infinity,
                   expected: "INF",
                   nonConformingFloatEncodingStrategy: encodingStrategy,
                   nonConformingFloatDecodingStrategy: decodingStrategy)
    _testRoundTrip(of: -Double.infinity,
                   expected: "-INF",
                   nonConformingFloatEncodingStrategy: encodingStrategy,
                   nonConformingFloatDecodingStrategy: decodingStrategy)

    // Since Double.nan != Double.nan, we have to use a placeholder that'll encode NaN but actually round-trip.
    _testRoundTrip(of: DoubleNaNPlaceholder(),
                   expected: "NaN",
                   nonConformingFloatEncodingStrategy: encodingStrategy,
                   nonConformingFloatDecodingStrategy: decodingStrategy)

    // Optional Floats and Doubles should encode the same way.
    _testRoundTrip(of: Optional(Float.infinity),
                   expected: "INF",
                   nonConformingFloatEncodingStrategy: encodingStrategy,
                   nonConformingFloatDecodingStrategy: decodingStrategy)
    _testRoundTrip(of: Optional(-Float.infinity),
                   expected: "-INF",
                   nonConformingFloatEncodingStrategy: encodingStrategy,
                   nonConformingFloatDecodingStrategy: decodingStrategy)
    _testRoundTrip(of: Optional(Double.infinity),
                   expected: "INF",
                   nonConformingFloatEncodingStrategy: encodingStrategy,
                   nonConformingFloatDecodingStrategy: decodingStrategy)
    _testRoundTrip(of: Optional(-Double.infinity),
                   expected: "-INF",
                   nonConformingFloatEncodingStrategy: encodingStrategy,
                   nonConformingFloatDecodingStrategy: decodingStrategy)
  }

  // MARK: - Key Strategy Tests

  private struct EncodeMe: Encodable {
    var keyName: String
    func encode(to coder: Encoder) throws {
      var c = coder.container(keyedBy: _TestKey.self)
      try c.encode("test", forKey: _TestKey(stringValue: keyName)!)
    }
  }

  func testEncodingKeyStrategySnake() {
    let toSnakeCaseTests = [
      ("simpleOneTwo", "simple_one_two"),
      ("myURL", "my_url"),
      ("singleCharacterAtEndX", "single_character_at_end_x"),
      ("thisIsAnXMLProperty", "this_is_an_xml_property"),
      ("single", "single"), // no underscore
      ("", ""), // don't die on empty string
      ("a", "a"), // single character
      ("aA", "a_a"), // two characters
      ("version4Thing", "version4_thing"), // numerics
      ("partCAPS", "part_caps"), // only insert underscore before first all caps
      ("partCAPSLowerAGAIN", "part_caps_lower_again"), // switch back and forth caps.
      ("manyWordsInThisThing", "many_words_in_this_thing"), // simple lowercase + underscore + more
      ("asdfĆqer", "asdf_ćqer"),
      ("already_snake_case", "already_snake_case"),
      ("dataPoint22", "data_point22"),
      ("dataPoint22Word", "data_point22_word"),
      ("_oneTwoThree", "_one_two_three"),
      ("oneTwoThree_", "one_two_three_"),
      ("__oneTwoThree", "__one_two_three"),
      ("oneTwoThree__", "one_two_three__"),
      ("_oneTwoThree_", "_one_two_three_"),
      ("__oneTwoThree", "__one_two_three"),
      ("__oneTwoThree__", "__one_two_three__"),
      ("_test", "_test"),
      ("_test_", "_test_"),
      ("__test", "__test"),
      ("test__", "test__"),
      ("m͉̟̹y̦̳G͍͚͎̳r̤͉̤͕ͅea̲͕t͇̥̼͖U͇̝̠R͙̻̥͓̣L̥̖͎͓̪̫ͅR̩͖̩eq͈͓u̞e̱s̙t̤̺ͅ", "m͉̟̹y̦̳_g͍͚͎̳r̤͉̤͕ͅea̲͕t͇̥̼͖_u͇̝̠r͙̻̥͓̣l̥̖͎͓̪̫ͅ_r̩͖̩eq͈͓u̞e̱s̙t̤̺ͅ"), // because Itai wanted to test this
      ("🐧🐟", "🐧🐟"), // fishy emoji example?
    ]

    for test in toSnakeCaseTests {
      let expected = ["\(test.1)": "test"]
      let encoded = EncodeMe(keyName: test.0)

      let encoder = FirebaseDataEncoder()
      encoder.keyEncodingStrategy = .convertToSnakeCase
      let result = try! encoder.encode(encoded)

      XCTAssertEqual(expected, result as? [String: String])
    }
  }

  func testEncodingKeyStrategyCustom() {
    let expected = ["QQQhello": "test"]
    let encoded = EncodeMe(keyName: "hello")

    let encoder = FirebaseDataEncoder()
    let customKeyConversion = { (_ path: [CodingKey]) -> CodingKey in
      let key = _TestKey(stringValue: "QQQ" + path.last!.stringValue)!
      return key
    }
    encoder.keyEncodingStrategy = .custom(customKeyConversion)
    let result = try! encoder.encode(encoded)

    XCTAssertEqual(expected, result as? [String: String])
  }

  func testEncodingDictionaryStringKeyConversionUntouched() {
    let toEncode = ["leaveMeAlone": "test"]

    let encoder = FirebaseDataEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let result = try! encoder.encode(toEncode)

    XCTAssertEqual(toEncode, result as? [String: String])
  }

  private struct EncodeFailure: Encodable {
    var someValue: Double
  }

  private struct EncodeFailureNested: Encodable {
    var nestedValue: EncodeFailure
  }

  func testEncodingDictionaryFailureKeyPath() {
    let toEncode: [String: EncodeFailure] = ["key": EncodeFailure(someValue: Double.nan)]

    let encoder = FirebaseDataEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    do {
      _ = try encoder.encode(toEncode)
    } catch let EncodingError.invalidValue(_, context) {
      XCTAssertEqual(2, context.codingPath.count)
      XCTAssertEqual("key", context.codingPath[0].stringValue)
      XCTAssertEqual("someValue", context.codingPath[1].stringValue)
    } catch {
      XCTFail("Unexpected error: \(String(describing: error))")
    }
  }

  func testEncodingDictionaryFailureKeyPathNested() {
    let toEncode: [String: [String: EncodeFailureNested]] =
      ["key": ["sub_key": EncodeFailureNested(nestedValue: EncodeFailure(someValue: Double.nan))]]

    let encoder = FirebaseDataEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    do {
      _ = try encoder.encode(toEncode)
    } catch let EncodingError.invalidValue(_, context) {
      XCTAssertEqual(4, context.codingPath.count)
      XCTAssertEqual("key", context.codingPath[0].stringValue)
      XCTAssertEqual("sub_key", context.codingPath[1].stringValue)
      XCTAssertEqual("nestedValue", context.codingPath[2].stringValue)
      XCTAssertEqual("someValue", context.codingPath[3].stringValue)
    } catch {
      XCTFail("Unexpected error: \(String(describing: error))")
    }
  }

  private struct EncodeNested: Encodable {
    let nestedValue: EncodeMe
  }

  private struct EncodeNestedNested: Encodable {
    let outerValue: EncodeNested
  }

  func testEncodingKeyStrategyPath() {
    // Make sure a more complex path shows up the way we want
    // Make sure the path reflects keys in the Swift, not the resulting ones in the structure
    let expected = ["QQQouterValue": ["QQQnestedValue": ["QQQhelloWorld": "test"]]]
    let encoded =
      EncodeNestedNested(outerValue: EncodeNested(nestedValue: EncodeMe(keyName: "helloWorld")))

    let encoder = FirebaseDataEncoder()
    var callCount = 0

    let customKeyConversion = { (_ path: [CodingKey]) -> CodingKey in
      // This should be called three times:
      // 1. to convert 'outerValue' to something
      // 2. to convert 'nestedValue' to something
      // 3. to convert 'helloWorld' to something
      callCount = callCount + 1

      if path.count == 0 {
        XCTFail("The path should always have at least one entry")
      } else if path.count == 1 {
        XCTAssertEqual(["outerValue"], path.map { $0.stringValue })
      } else if path.count == 2 {
        XCTAssertEqual(["outerValue", "nestedValue"], path.map { $0.stringValue })
      } else if path.count == 3 {
        XCTAssertEqual(["outerValue", "nestedValue", "helloWorld"], path.map { $0.stringValue })
      } else {
        XCTFail("The path mysteriously had more entries")
      }

      let key = _TestKey(stringValue: "QQQ" + path.last!.stringValue)!
      return key
    }
    encoder.keyEncodingStrategy = .custom(customKeyConversion)
    let result = try! encoder.encode(encoded)

    XCTAssertEqual(expected, result as? [String: [String: [String: String]]])
    XCTAssertEqual(3, callCount)
  }

  private struct DecodeMe: Decodable {
    let found: Bool
    init(from coder: Decoder) throws {
      let c = try coder.container(keyedBy: _TestKey.self)
      // Get the key that we expect to be passed in (camel case)
      let camelCaseKey = try c.decode(String.self, forKey: _TestKey(stringValue: "camelCaseKey")!)

      // Use the camel case key to decode from the structure. The decoder should convert it to snake case to find it.
      found = try c.decode(Bool.self, forKey: _TestKey(stringValue: camelCaseKey)!)
    }
  }

  func testDecodingKeyStrategyCamel() {
    let fromSnakeCaseTests = [
      ("", ""), // don't die on empty string
      ("a", "a"), // single character
      ("ALLCAPS", "ALLCAPS"), // If no underscores, we leave the word as-is
      ("ALL_CAPS", "allCaps"), // Conversion from screaming snake case
      ("single", "single"), // do not capitalize anything with no underscore
      ("snake_case", "snakeCase"), // capitalize a character
      ("one_two_three", "oneTwoThree"), // more than one word
      ("one_2_three", "one2Three"), // numerics
      ("one2_three", "one2Three"), // numerics, part 2
      ("snake_Ćase", "snakeĆase"), // do not further modify a capitalized diacritic
      ("snake_ćase", "snakeĆase"), // capitalize a diacritic
      ("alreadyCamelCase", "alreadyCamelCase"), // do not modify already camel case
      ("__this_and_that", "__thisAndThat"),
      ("_this_and_that", "_thisAndThat"),
      ("this__and__that", "thisAndThat"),
      ("this_and_that__", "thisAndThat__"),
      ("this_aNd_that", "thisAndThat"),
      ("_one_two_three", "_oneTwoThree"),
      ("one_two_three_", "oneTwoThree_"),
      ("__one_two_three", "__oneTwoThree"),
      ("one_two_three__", "oneTwoThree__"),
      ("_one_two_three_", "_oneTwoThree_"),
      ("__one_two_three", "__oneTwoThree"),
      ("__one_two_three__", "__oneTwoThree__"),
      ("_test", "_test"),
      ("_test_", "_test_"),
      ("__test", "__test"),
      ("test__", "test__"),
      ("_", "_"),
      ("__", "__"),
      ("___", "___"),
      ("m͉̟̹y̦̳G͍͚͎̳r̤͉̤͕ͅea̲͕t͇̥̼͖U͇̝̠R͙̻̥͓̣L̥̖͎͓̪̫ͅR̩͖̩eq͈͓u̞e̱s̙t̤̺ͅ", "m͉̟̹y̦̳G͍͚͎̳r̤͉̤͕ͅea̲͕t͇̥̼͖U͇̝̠R͙̻̥͓̣L̥̖͎͓̪̫ͅR̩͖̩eq͈͓u̞e̱s̙t̤̺ͅ"), // because Itai wanted to test this
      ("🐧_🐟", "🐧🐟"), // fishy emoji example?
    ]

    for test in fromSnakeCaseTests {
      // This structure contains the camel case key that the test object should decode with, then it uses the snake case key (test.0) as the actual key for the boolean value.
      let input = ["camelCaseKey": "\(test.1)", "\(test.0)": true] as [String: Any]

      let decoder = FirebaseDataDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase

      let result = try! decoder.decode(DecodeMe.self, from: input)

      XCTAssertTrue(result.found)
    }
  }

  private struct DecodeMe2: Decodable { var hello: String }

  func testDecodingKeyStrategyCustom() {
    let input = ["----hello": "test"]
    let decoder = FirebaseDataDecoder()
    let customKeyConversion = { (_ path: [CodingKey]) -> CodingKey in
      // This converter removes the first 4 characters from the start of all string keys, if it has more than 4 characters
      let string = path.last!.stringValue
      guard string.count > 4 else { return path.last! }
      let newString = String(string.dropFirst(4))
      return _TestKey(stringValue: newString)!
    }
    decoder.keyDecodingStrategy = .custom(customKeyConversion)
    let result = try! decoder.decode(DecodeMe2.self, from: input)

    XCTAssertEqual("test", result.hello)
  }

  func testDecodingDictionaryStringKeyConversionUntouched() {
    let input = ["leave_me_alone": "test"]
    let decoder = FirebaseDataDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let result = try! decoder.decode([String: String].self, from: input)

    XCTAssertEqual(["leave_me_alone": "test"], result)
  }

  func testDecodingDictionaryFailureKeyPath() {
    let input = ["leave_me_alone": "test"]
    let decoder = FirebaseDataDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    do {
      _ = try decoder.decode([String: Int].self, from: input)
    } catch let DecodingError.typeMismatch(_, context) {
      XCTAssertEqual(1, context.codingPath.count)
      XCTAssertEqual("leave_me_alone", context.codingPath[0].stringValue)
    } catch {
      XCTFail("Unexpected error: \(String(describing: error))")
    }
  }

  private struct DecodeFailure: Decodable {
    var intValue: Int
  }

  private struct DecodeFailureNested: Decodable {
    var nestedValue: DecodeFailure
  }

  func testDecodingDictionaryFailureKeyPathNested() {
    let input = ["top_level": ["sub_level": ["nested_value": ["int_value": "not_an_int"]]]]
    let decoder = FirebaseDataDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    do {
      _ = try decoder.decode([String: [String: DecodeFailureNested]].self, from: input)
    } catch let DecodingError.typeMismatch(_, context) {
      XCTAssertEqual(4, context.codingPath.count)
      XCTAssertEqual("top_level", context.codingPath[0].stringValue)
      XCTAssertEqual("sub_level", context.codingPath[1].stringValue)
      XCTAssertEqual("nestedValue", context.codingPath[2].stringValue)
      XCTAssertEqual("intValue", context.codingPath[3].stringValue)
    } catch {
      XCTFail("Unexpected error: \(String(describing: error))")
    }
  }

  private struct DecodeMe3: Codable {
    var thisIsCamelCase: String
  }

  func testEncodingKeyStrategySnakeGenerated() {
    // Test that this works with a struct that has automatically generated keys
    let input = ["this_is_camel_case": "test"]
    let decoder = FirebaseDataDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let result = try! decoder.decode(DecodeMe3.self, from: input)

    XCTAssertEqual("test", result.thisIsCamelCase)
  }

  func testDecodingKeyStrategyCamelGenerated() {
    let encoded = DecodeMe3(thisIsCamelCase: "test")
    let encoder = FirebaseDataEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let result = try! encoder.encode(encoded)
    XCTAssertEqual(["this_is_camel_case": "test"], result as? [String: String])
  }

  func testKeyStrategySnakeGeneratedAndCustom() {
    // Test that this works with a struct that has automatically generated keys
    struct DecodeMe4: Codable {
      var thisIsCamelCase: String
      var thisIsCamelCaseToo: String
      private enum CodingKeys: String, CodingKey {
        case thisIsCamelCase = "fooBar"
        case thisIsCamelCaseToo
      }
    }

    // Decoding
    let input = ["foo_bar": "test", "this_is_camel_case_too": "test2"]
    let decoder = FirebaseDataDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let decodingResult = try! decoder.decode(DecodeMe4.self, from: input)

    XCTAssertEqual("test", decodingResult.thisIsCamelCase)
    XCTAssertEqual("test2", decodingResult.thisIsCamelCaseToo)

    // Encoding
    let encoded = DecodeMe4(thisIsCamelCase: "test", thisIsCamelCaseToo: "test2")
    let encoder = FirebaseDataEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let encodingResult = try! encoder.encode(encoded)
    XCTAssertEqual(
      ["foo_bar": "test", "this_is_camel_case_too": "test2"],
      encodingResult as? [String: String]
    )
  }

  func testKeyStrategyDuplicateKeys() {
    // This test is mostly to make sure we don't assert on duplicate keys
    struct DecodeMe5: Codable {
      var oneTwo: String
      var numberOfKeys: Int

      enum CodingKeys: String, CodingKey {
        case oneTwo
        case oneTwoThree
      }

      init() {
        oneTwo = "test"
        numberOfKeys = 0
      }

      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        oneTwo = try container.decode(String.self, forKey: .oneTwo)
        numberOfKeys = container.allKeys.count
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(oneTwo, forKey: .oneTwo)
        try container.encode("test2", forKey: .oneTwoThree)
      }
    }

    let customKeyConversion = { (_ path: [CodingKey]) -> CodingKey in
      // All keys are the same!
      _TestKey(stringValue: "oneTwo")!
    }

    // Decoding
    // This input has a dictionary with two keys, but only one will end up in the container
    let input = ["unused key 1": "test1", "unused key 2": "test2"]
    let decoder = FirebaseDataDecoder()
    decoder.keyDecodingStrategy = .custom(customKeyConversion)

    let decodingResult = try! decoder.decode(DecodeMe5.self, from: input)
    // There will be only one result for oneTwo (the second one in the structure)
    XCTAssertEqual(1, decodingResult.numberOfKeys)

    // Encoding
    let encoded = DecodeMe5()
    let encoder = FirebaseDataEncoder()
    encoder.keyEncodingStrategy = .custom(customKeyConversion)
    let decodingResult2 = try! encoder.encode(encoded)

    // There will be only one value in the result (the second one encoded)
    XCTAssertEqual(["oneTwo": "test2"], decodingResult2 as? [String: String])
  }

  // MARK: - Encoder Features

  func testNestedContainerCodingPaths() {
    let encoder = FirebaseDataEncoder()
    do {
      _ = try encoder.encode(NestedContainersTestType())
    } catch let error as NSError {
      XCTFail("Caught error during encoding nested container types: \(error)")
    }
  }

  func testSuperEncoderCodingPaths() {
    let encoder = FirebaseDataEncoder()
    do {
      _ = try encoder.encode(NestedContainersTestType(testSuperEncoder: true))
    } catch let error as NSError {
      XCTFail("Caught error during encoding nested container types: \(error)")
    }
  }

  func testInterceptDecimal() {
    let expected =
      NSDecimalNumber(
        string: "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
      )

    // Want to make sure we write out a number, not the keyed encoding here.
    // 1e127 is too big to fit natively in a Double, too, so want to make sure it's encoded as a Decimal.
    let decimal = Decimal(sign: .plus, exponent: 127, significand: Decimal(1))
    _testRoundTrip(of: decimal, expected: expected)

    // Optional Decimals should encode the same way.
    _testRoundTrip(of: Optional(decimal), expected: expected)
  }

  func testInterceptURL() {
    // Want to make sure FirebaseDataEncoder writes out single-value URLs, not the keyed encoding.
    let expected = "http://swift.org"
    let url = URL(string: "http://swift.org")!
    _testRoundTrip(of: url, expected: expected)

    // Optional URLs should encode the same way.
    _testRoundTrip(of: Optional(url), expected: expected)
  }

  // MARK: - Type coercion

  func testTypeCoercion() {
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int8].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int16].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int32].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [Int64].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt8].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt16].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt32].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [UInt64].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [Float].self)
    _testRoundTripTypeCoercionFailure(of: [false, true], as: [Double].self)
    _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int8], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int16], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int32], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0, 1] as [Int64], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt8], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt16], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt32], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0, 1] as [UInt64], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0.0, 1.0] as [Float], as: [Bool].self)
    _testRoundTripTypeCoercionFailure(of: [0.0, 1.0] as [Double], as: [Bool].self)
  }

  func testDecodingConcreteTypeParameter() {
    let encoder = FirebaseDataEncoder()
    guard let value = try? encoder.encode(Employee.testValue) else {
      XCTFail("Unable to encode Employee.")
      return
    }

    let decoder = FirebaseDataDecoder()
    guard let decoded = try? decoder.decode(Employee.self as Person.Type, from: value) else {
      XCTFail("Failed to decode Employee as Person.")
      return
    }

    XCTAssert(
      type(of: decoded) == Employee.self,
      "Expected decoded value to be of type Employee; got \(type(of: decoded)) instead."
    )
  }

  // MARK: - Encoder State

  // SR-6078
  func testEncoderStateThrowOnEncode() {
    struct ReferencingEncoderWrapper<T: Encodable>: Encodable {
      let value: T
      init(_ value: T) { self.value = value }

      func encode(to encoder: Encoder) throws {
        // This approximates a subclass calling into its superclass, where the superclass encodes a value that might throw.
        // The key here is that getting the superEncoder creates a referencing encoder.
        var container = encoder.unkeyedContainer()
        let superEncoder = container.superEncoder()

        // Pushing a nested container on leaves the referencing encoder with multiple containers.
        var nestedContainer = superEncoder.unkeyedContainer()
        try nestedContainer.encode(value)
      }
    }

    // The structure that would be encoded here looks like
    //
    //   [[[Float.infinity]]]
    //
    // The wrapper asks for an unkeyed container ([^]), gets a super encoder, and creates a nested container into that ([[^]]).
    // We then encode an array into that ([[[^]]]), which happens to be a value that causes us to throw an error.
    //
    // The issue at hand reproduces when you have a referencing encoder (superEncoder() creates one) that has a container on the stack (unkeyedContainer() adds one) that encodes a value going through box_() (Array does that) that encodes something which throws (Float.infinity does that).
    // When reproducing, this will cause a test failure via fatalError().
    _ = try? FirebaseDataEncoder().encode(ReferencingEncoderWrapper([Float.infinity]))
  }

  func testEncoderStateThrowOnEncodeCustomDate() {
    // This test is identical to testEncoderStateThrowOnEncode, except throwing via a custom Date closure.
    struct ReferencingEncoderWrapper<T: Encodable>: Encodable {
      let value: T
      init(_ value: T) { self.value = value }
      func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        let superEncoder = container.superEncoder()
        var nestedContainer = superEncoder.unkeyedContainer()
        try nestedContainer.encode(value)
      }
    }

    // The closure needs to push a container before throwing an error to trigger.
    let encoder = FirebaseDataEncoder()
    encoder.dateEncodingStrategy = .custom { _, encoder in
      _ = encoder.unkeyedContainer()
      enum CustomError: Error { case foo }
      throw CustomError.foo
    }

    _ = try? encoder.encode(ReferencingEncoderWrapper(Date()))
  }

  func testEncoderStateThrowOnEncodeCustomData() {
    // This test is identical to testEncoderStateThrowOnEncode, except throwing via a custom Data closure.
    struct ReferencingEncoderWrapper<T: Encodable>: Encodable {
      let value: T
      init(_ value: T) { self.value = value }
      func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        let superEncoder = container.superEncoder()
        var nestedContainer = superEncoder.unkeyedContainer()
        try nestedContainer.encode(value)
      }
    }

    // The closure needs to push a container before throwing an error to trigger.
    let encoder = FirebaseDataEncoder()
    encoder.dataEncodingStrategy = .custom { _, encoder in
      _ = encoder.unkeyedContainer()
      enum CustomError: Error { case foo }
      throw CustomError.foo
    }

    _ = try? encoder.encode(ReferencingEncoderWrapper(Data()))
  }

  // MARK: - Decoder State

  // SR-6048
  func testDecoderStateThrowOnDecode() {
    // The container stack here starts as [[1,2,3]]. Attempting to decode as [String] matches the outer layer (Array), and begins decoding the array.
    // Once Array decoding begins, 1 is pushed onto the container stack ([[1,2,3], 1]), and 1 is attempted to be decoded as String. This throws a .typeMismatch, but the container is not popped off the stack.
    // When attempting to decode [Int], the container stack is still ([[1,2,3], 1]), and 1 fails to decode as [Int].
    let input = [1, 2, 3]
    _ = try! FirebaseDataDecoder().decode(EitherDecodable<[String], [Int]>.self, from: input)
  }

  func testDecoderStateThrowOnDecodeCustomDate() {
    // This test is identical to testDecoderStateThrowOnDecode, except we're going to fail because our closure throws an error, not because we hit a type mismatch.
    let decoder = FirebaseDataDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      enum CustomError: Error { case foo }
      throw CustomError.foo
    }

    let input = 1
    _ = try! decoder.decode(EitherDecodable<Date, Int>.self, from: input)
  }

  func testDecoderStateThrowOnDecodeCustomData() {
    // This test is identical to testDecoderStateThrowOnDecode, except we're going to fail because our closure throws an error, not because we hit a type mismatch.
    let decoder = FirebaseDataDecoder()
    decoder.dataDecodingStrategy = .custom { decoder in
      enum CustomError: Error { case foo }
      throw CustomError.foo
    }

    let input = 1
    _ = try! decoder.decode(EitherDecodable<Data, Int>.self, from: input)
  }

  // MARK: - Helper Functions

  private var _emptyDictionary: [String: String] {
    return [:]
  }

  private func _testEncodeFailure<T: Encodable>(of value: T) {
    do {
      _ = try FirebaseDataEncoder().encode(value)
      XCTFail("Encode of top-level \(T.self) was expected to fail.")
    } catch {}
  }

  private func _testRoundTrip<T, U>(of value: T,
                                    expected: U,
                                    dateEncodingStrategy: FirebaseDataEncoder
                                      .DateEncodingStrategy = .deferredToDate,
                                    dateDecodingStrategy: FirebaseDataDecoder
                                      .DateDecodingStrategy = .deferredToDate,
                                    dataEncodingStrategy: FirebaseDataEncoder
                                      .DataEncodingStrategy = .base64,
                                    dataDecodingStrategy: FirebaseDataDecoder
                                      .DataDecodingStrategy = .base64,
                                    keyEncodingStrategy: FirebaseDataEncoder
                                      .KeyEncodingStrategy = .useDefaultKeys,
                                    keyDecodingStrategy: FirebaseDataDecoder
                                      .KeyDecodingStrategy = .useDefaultKeys,
                                    nonConformingFloatEncodingStrategy: FirebaseDataEncoder
                                      .NonConformingFloatEncodingStrategy = .throw,
                                    nonConformingFloatDecodingStrategy: FirebaseDataDecoder
                                      .NonConformingFloatDecodingStrategy = .throw)
    where T: Codable,
    T: Equatable, U: Equatable {
    var payload: Any! = nil
    do {
      let encoder = FirebaseDataEncoder()
      encoder.dateEncodingStrategy = dateEncodingStrategy
      encoder.dataEncodingStrategy = dataEncodingStrategy
      encoder.nonConformingFloatEncodingStrategy = nonConformingFloatEncodingStrategy
      encoder.keyEncodingStrategy = keyEncodingStrategy
      payload = try encoder.encode(value)
    } catch {
      XCTFail("Failed to encode \(T.self): \(error)")
    }

    XCTAssertEqual(
      expected,
      payload as? U,
      "Produced structure not identical to expected structure."
    )

    do {
      let decoder = FirebaseDataDecoder()
      decoder.dateDecodingStrategy = dateDecodingStrategy
      decoder.dataDecodingStrategy = dataDecodingStrategy
      decoder.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
      decoder.keyDecodingStrategy = keyDecodingStrategy
      let decoded = try decoder.decode(T.self, from: payload!)
      XCTAssertEqual(decoded, value, "\(T.self) did not round-trip to an equal value.")
    } catch {
      XCTFail("Failed to decode \(T.self): \(error)")
    }
  }

  private func _testRoundTrip<T>(of value: T,
                                 dateEncodingStrategy: FirebaseDataEncoder
                                   .DateEncodingStrategy = .deferredToDate,
                                 dateDecodingStrategy: FirebaseDataDecoder
                                   .DateDecodingStrategy = .deferredToDate,
                                 dataEncodingStrategy: FirebaseDataEncoder
                                   .DataEncodingStrategy = .base64,
                                 dataDecodingStrategy: FirebaseDataDecoder
                                   .DataDecodingStrategy = .base64,
                                 keyEncodingStrategy: FirebaseDataEncoder
                                   .KeyEncodingStrategy = .useDefaultKeys,
                                 keyDecodingStrategy: FirebaseDataDecoder
                                   .KeyDecodingStrategy = .useDefaultKeys,
                                 nonConformingFloatEncodingStrategy: FirebaseDataEncoder
                                   .NonConformingFloatEncodingStrategy = .throw,
                                 nonConformingFloatDecodingStrategy: FirebaseDataDecoder
                                   .NonConformingFloatDecodingStrategy = .throw) where T: Codable,
    T: Equatable {
    var payload: Any! = nil
    do {
      let encoder = FirebaseDataEncoder()
      encoder.dateEncodingStrategy = dateEncodingStrategy
      encoder.dataEncodingStrategy = dataEncodingStrategy
      encoder.nonConformingFloatEncodingStrategy = nonConformingFloatEncodingStrategy
      encoder.keyEncodingStrategy = keyEncodingStrategy
      payload = try encoder.encode(value)
    } catch {
      XCTFail("Failed to encode \(T.self): \(error)")
    }

    do {
      let decoder = FirebaseDataDecoder()
      decoder.dateDecodingStrategy = dateDecodingStrategy
      decoder.dataDecodingStrategy = dataDecodingStrategy
      decoder.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
      decoder.keyDecodingStrategy = keyDecodingStrategy
      let decoded = try decoder.decode(T.self, from: payload!)
      XCTAssertEqual(decoded, value, "\(T.self) did not round-trip to an equal value.")
    } catch {
      XCTFail("Failed to decode \(T.self): \(error)")
    }
  }

  private func _testRoundTripTypeCoercionFailure<T, U>(of value: T, as type: U.Type)
    where T: Codable, U: Codable {
    do {
      let data = try FirebaseDataEncoder().encode(value)
      _ = try FirebaseDataDecoder().decode(U.self, from: data)
      XCTFail("Coercion from \(T.self) to \(U.self) was expected to fail.")
    } catch {}
  }
}

// MARK: - Helper Global Functions

func expectEqualPaths(_ lhs: [CodingKey], _ rhs: [CodingKey], _ prefix: String) {
  if lhs.count != rhs.count {
    XCTFail("\(prefix) [CodingKey].count mismatch: \(lhs.count) != \(rhs.count)")
    return
  }

  for (key1, key2) in zip(lhs, rhs) {
    switch (key1.intValue, key2.intValue) {
    case (.none, .none): break
    case let (.some(i1), .none):
      XCTFail("\(prefix) CodingKey.intValue mismatch: \(type(of: key1))(\(i1)) != nil")
      return
    case let (.none, .some(i2)):
      XCTFail("\(prefix) CodingKey.intValue mismatch: nil != \(type(of: key2))(\(i2))")
      return
    case let (.some(i1), .some(i2)):
      guard i1 == i2 else {
        XCTFail(
          "\(prefix) CodingKey.intValue mismatch: \(type(of: key1))(\(i1)) != \(type(of: key2))(\(i2))"
        )
        return
      }
    }

    XCTAssertEqual(
      key1.stringValue,
      key2.stringValue,
      "\(prefix) CodingKey.stringValue mismatch: \(type(of: key1))('\(key1.stringValue)') != \(type(of: key2))('\(key2.stringValue)')"
    )
  }
}

// MARK: - Test Types

/* FIXME: Import from %S/Inputs/Coding/SharedTypes.swift somehow. */

// MARK: - Empty Types

private struct EmptyStruct: Codable, Equatable {
  static func == (_ lhs: EmptyStruct, _ rhs: EmptyStruct) -> Bool {
    return true
  }
}

private class EmptyClass: Codable, Equatable {
  static func == (_ lhs: EmptyClass, _ rhs: EmptyClass) -> Bool {
    return true
  }
}

// MARK: - Single-Value Types

/// A simple on-off switch type that encodes as a single Bool value.
private enum Switch: Codable {
  case off
  case on

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    switch try container.decode(Bool.self) {
    case false: self = .off
    case true: self = .on
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .off: try container.encode(false)
    case .on: try container.encode(true)
    }
  }
}

/// A simple timestamp type that encodes as a single Double value.
private struct Timestamp: Codable, Equatable {
  let value: Double

  init(_ value: Double) {
    self.value = value
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    value = try container.decode(Double.self)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(value)
  }

  static func == (_ lhs: Timestamp, _ rhs: Timestamp) -> Bool {
    return lhs.value == rhs.value
  }
}

/// A simple referential counter type that encodes as a single Int value.
private final class Counter: Codable, Equatable {
  var count: Int = 0

  init() {}

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    count = try container.decode(Int.self)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(count)
  }

  static func == (_ lhs: Counter, _ rhs: Counter) -> Bool {
    return lhs === rhs || lhs.count == rhs.count
  }
}

// MARK: - Structured Types

/// A simple address type that encodes as a dictionary of values.
private struct Address: Codable, Equatable {
  let street: String
  let city: String
  let state: String
  let zipCode: Int
  let country: String

  init(street: String, city: String, state: String, zipCode: Int, country: String) {
    self.street = street
    self.city = city
    self.state = state
    self.zipCode = zipCode
    self.country = country
  }

  static func == (_ lhs: Address, _ rhs: Address) -> Bool {
    return lhs.street == rhs.street &&
      lhs.city == rhs.city &&
      lhs.state == rhs.state &&
      lhs.zipCode == rhs.zipCode &&
      lhs.country == rhs.country
  }

  static var testValue: Address {
    return Address(street: "1 Infinite Loop",
                   city: "Cupertino",
                   state: "CA",
                   zipCode: 95014,
                   country: "United States")
  }
}

/// A simple person class that encodes as a dictionary of values.
private class Person: Codable, Equatable {
  let name: String
  let email: String
  let website: URL?

  init(name: String, email: String, website: URL? = nil) {
    self.name = name
    self.email = email
    self.website = website
  }

  func isEqual(_ other: Person) -> Bool {
    return name == other.name &&
      email == other.email &&
      website == other.website
  }

  static func == (_ lhs: Person, _ rhs: Person) -> Bool {
    return lhs.isEqual(rhs)
  }

  class var testValue: Person {
    return Person(name: "Johnny Appleseed", email: "appleseed@apple.com")
  }
}

/// A class which shares its encoder and decoder with its superclass.
private class Employee: Person {
  let id: Int

  init(name: String, email: String, website: URL? = nil, id: Int) {
    self.id = id
    super.init(name: name, email: email, website: website)
  }

  enum CodingKeys: String, CodingKey {
    case id
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(Int.self, forKey: .id)
    try super.init(from: decoder)
  }

  override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try super.encode(to: encoder)
  }

  override func isEqual(_ other: Person) -> Bool {
    if let employee = other as? Employee {
      guard id == employee.id else { return false }
    }

    return super.isEqual(other)
  }

  override class var testValue: Employee {
    return Employee(name: "Johnny Appleseed", email: "appleseed@apple.com", id: 42)
  }
}

/// A simple company struct which encodes as a dictionary of nested values.
private struct Company: Codable, Equatable {
  let address: Address
  var employees: [Employee]

  init(address: Address, employees: [Employee]) {
    self.address = address
    self.employees = employees
  }

  static func == (_ lhs: Company, _ rhs: Company) -> Bool {
    return lhs.address == rhs.address && lhs.employees == rhs.employees
  }

  static var testValue: Company {
    return Company(address: Address.testValue, employees: [Employee.testValue])
  }
}

/// An enum type which decodes from Bool?.
private enum EnhancedBool: Codable {
  case `true`
  case `false`
  case fileNotFound

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .fileNotFound
    } else {
      let value = try container.decode(Bool.self)
      self = value ? .true : .false
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .true: try container.encode(true)
    case .false: try container.encode(false)
    case .fileNotFound: try container.encodeNil()
    }
  }
}

/// A type which encodes as an array directly through a single value container.
struct Numbers: Codable, Equatable {
  let values = [4, 8, 15, 16, 23, 42]

  init() {}

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let decodedValues = try container.decode([Int].self)
    guard decodedValues == values else {
      throw DecodingError
        .dataCorrupted(DecodingError
          .Context(codingPath: decoder.codingPath, debugDescription: "The Numbers are wrong!"))
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(values)
  }

  static func == (_ lhs: Numbers, _ rhs: Numbers) -> Bool {
    return lhs.values == rhs.values
  }

  static var testValue: Numbers {
    return Numbers()
  }
}

/// A type which encodes as a dictionary directly through a single value container.
private final class Mapping: Codable, Equatable {
  let values: [String: URL]

  init(values: [String: URL]) {
    self.values = values
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    values = try container.decode([String: URL].self)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(values)
  }

  static func == (_ lhs: Mapping, _ rhs: Mapping) -> Bool {
    return lhs === rhs || lhs.values == rhs.values
  }

  static var testValue: Mapping {
    return Mapping(values: ["Apple": URL(string: "http://apple.com")!,
                            "localhost": URL(string: "http://127.0.0.1")!])
  }
}

struct NestedContainersTestType: Encodable {
  let testSuperEncoder: Bool

  init(testSuperEncoder: Bool = false) {
    self.testSuperEncoder = testSuperEncoder
  }

  enum TopLevelCodingKeys: Int, CodingKey {
    case a
    case b
    case c
  }

  enum IntermediateCodingKeys: Int, CodingKey {
    case one
    case two
  }

  func encode(to encoder: Encoder) throws {
    if testSuperEncoder {
      var topLevelContainer = encoder.container(keyedBy: TopLevelCodingKeys.self)
      expectEqualPaths(encoder.codingPath, [], "Top-level Encoder's codingPath changed.")
      expectEqualPaths(
        topLevelContainer.codingPath,
        [],
        "New first-level keyed container has non-empty codingPath."
      )

      let superEncoder = topLevelContainer.superEncoder(forKey: .a)
      expectEqualPaths(encoder.codingPath, [], "Top-level Encoder's codingPath changed.")
      expectEqualPaths(
        topLevelContainer.codingPath,
        [],
        "First-level keyed container's codingPath changed."
      )
      expectEqualPaths(
        superEncoder.codingPath,
        [TopLevelCodingKeys.a],
        "New superEncoder had unexpected codingPath."
      )
      _testNestedContainers(in: superEncoder, baseCodingPath: [TopLevelCodingKeys.a])
    } else {
      _testNestedContainers(in: encoder, baseCodingPath: [])
    }
  }

  func _testNestedContainers(in encoder: Encoder, baseCodingPath: [CodingKey]) {
    expectEqualPaths(encoder.codingPath, baseCodingPath, "New encoder has non-empty codingPath.")

    // codingPath should not change upon fetching a non-nested container.
    var firstLevelContainer = encoder.container(keyedBy: TopLevelCodingKeys.self)
    expectEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
    expectEqualPaths(
      firstLevelContainer.codingPath,
      baseCodingPath,
      "New first-level keyed container has non-empty codingPath."
    )

    // Nested Keyed Container
    do {
      // Nested container for key should have a new key pushed on.
      var secondLevelContainer = firstLevelContainer.nestedContainer(
        keyedBy: IntermediateCodingKeys.self,
        forKey: .a
      )
      expectEqualPaths(
        encoder.codingPath,
        baseCodingPath,
        "Top-level Encoder's codingPath changed."
      )
      expectEqualPaths(
        firstLevelContainer.codingPath,
        baseCodingPath,
        "First-level keyed container's codingPath changed."
      )
      expectEqualPaths(
        secondLevelContainer.codingPath,
        baseCodingPath + [TopLevelCodingKeys.a],
        "New second-level keyed container had unexpected codingPath."
      )

      // Inserting a keyed container should not change existing coding paths.
      let thirdLevelContainerKeyed = secondLevelContainer.nestedContainer(
        keyedBy: IntermediateCodingKeys.self,
        forKey: .one
      )
      expectEqualPaths(
        encoder.codingPath,
        baseCodingPath,
        "Top-level Encoder's codingPath changed."
      )
      expectEqualPaths(
        firstLevelContainer.codingPath,
        baseCodingPath,
        "First-level keyed container's codingPath changed."
      )
      expectEqualPaths(
        secondLevelContainer.codingPath,
        baseCodingPath + [TopLevelCodingKeys.a],
        "Second-level keyed container's codingPath changed."
      )
      expectEqualPaths(
        thirdLevelContainerKeyed.codingPath,
        baseCodingPath + [TopLevelCodingKeys.a, IntermediateCodingKeys.one],
        "New third-level keyed container had unexpected codingPath."
      )

      // Inserting an unkeyed container should not change existing coding paths.
      let thirdLevelContainerUnkeyed = secondLevelContainer.nestedUnkeyedContainer(forKey: .two)
      expectEqualPaths(
        encoder.codingPath,
        baseCodingPath + [],
        "Top-level Encoder's codingPath changed."
      )
      expectEqualPaths(
        firstLevelContainer.codingPath,
        baseCodingPath + [],
        "First-level keyed container's codingPath changed."
      )
      expectEqualPaths(
        secondLevelContainer.codingPath,
        baseCodingPath + [TopLevelCodingKeys.a],
        "Second-level keyed container's codingPath changed."
      )
      expectEqualPaths(
        thirdLevelContainerUnkeyed.codingPath,
        baseCodingPath + [TopLevelCodingKeys.a, IntermediateCodingKeys.two],
        "New third-level unkeyed container had unexpected codingPath."
      )
    }

    // Nested Unkeyed Container
    do {
      // Nested container for key should have a new key pushed on.
      var secondLevelContainer = firstLevelContainer.nestedUnkeyedContainer(forKey: .b)
      expectEqualPaths(
        encoder.codingPath,
        baseCodingPath,
        "Top-level Encoder's codingPath changed."
      )
      expectEqualPaths(
        firstLevelContainer.codingPath,
        baseCodingPath,
        "First-level keyed container's codingPath changed."
      )
      expectEqualPaths(
        secondLevelContainer.codingPath,
        baseCodingPath + [TopLevelCodingKeys.b],
        "New second-level keyed container had unexpected codingPath."
      )

      // Appending a keyed container should not change existing coding paths.
      let thirdLevelContainerKeyed = secondLevelContainer
        .nestedContainer(keyedBy: IntermediateCodingKeys.self)
      expectEqualPaths(
        encoder.codingPath,
        baseCodingPath,
        "Top-level Encoder's codingPath changed."
      )
      expectEqualPaths(
        firstLevelContainer.codingPath,
        baseCodingPath,
        "First-level keyed container's codingPath changed."
      )
      expectEqualPaths(
        secondLevelContainer.codingPath,
        baseCodingPath + [TopLevelCodingKeys.b],
        "Second-level unkeyed container's codingPath changed."
      )
      expectEqualPaths(
        thirdLevelContainerKeyed.codingPath,
        baseCodingPath + [TopLevelCodingKeys.b, _TestKey(index: 0)],
        "New third-level keyed container had unexpected codingPath."
      )

      // Appending an unkeyed container should not change existing coding paths.
      let thirdLevelContainerUnkeyed = secondLevelContainer.nestedUnkeyedContainer()
      expectEqualPaths(
        encoder.codingPath,
        baseCodingPath,
        "Top-level Encoder's codingPath changed."
      )
      expectEqualPaths(
        firstLevelContainer.codingPath,
        baseCodingPath,
        "First-level keyed container's codingPath changed."
      )
      expectEqualPaths(
        secondLevelContainer.codingPath,
        baseCodingPath + [TopLevelCodingKeys.b],
        "Second-level unkeyed container's codingPath changed."
      )
      expectEqualPaths(
        thirdLevelContainerUnkeyed.codingPath,
        baseCodingPath + [TopLevelCodingKeys.b, _TestKey(index: 1)],
        "New third-level unkeyed container had unexpected codingPath."
      )
    }
  }
}

// MARK: - Helper Types

/// A key type which can take on any string or integer value.
/// This needs to mirror _JSONKey.
private struct _TestKey: CodingKey {
  var stringValue: String
  var intValue: Int?

  init?(stringValue: String) {
    self.stringValue = stringValue
    intValue = nil
  }

  init?(intValue: Int) {
    stringValue = "\(intValue)"
    self.intValue = intValue
  }

  init(index: Int) {
    stringValue = "Index \(index)"
    intValue = index
  }
}

private struct FloatNaNPlaceholder: Codable, Equatable {
  init() {}

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(Float.nan)
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let float = try container.decode(Float.self)
    if !float.isNaN {
      throw DecodingError
        .dataCorrupted(DecodingError
          .Context(codingPath: decoder.codingPath, debugDescription: "Couldn't decode NaN."))
    }
  }

  static func == (_ lhs: FloatNaNPlaceholder, _ rhs: FloatNaNPlaceholder) -> Bool {
    return true
  }
}

private struct DoubleNaNPlaceholder: Codable, Equatable {
  init() {}

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(Double.nan)
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let double = try container.decode(Double.self)
    if !double.isNaN {
      throw DecodingError
        .dataCorrupted(DecodingError
          .Context(codingPath: decoder.codingPath, debugDescription: "Couldn't decode NaN."))
    }
  }

  static func == (_ lhs: DoubleNaNPlaceholder, _ rhs: DoubleNaNPlaceholder) -> Bool {
    return true
  }
}

private enum EitherDecodable<T: Decodable, U: Decodable>: Decodable {
  case t(T)
  case u(U)

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    do {
      self = .t(try container.decode(T.self))
    } catch {
      self = .u(try container.decode(U.self))
    }
  }
}
