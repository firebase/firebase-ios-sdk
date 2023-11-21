/*
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import FirebaseSharedSwift
import Foundation
import XCTest

class FirebaseFirebaseDataEncoderTests: XCTestCase {
  func testInt() {
    struct Model: Codable, Equatable {
      let x: Int
    }
    let model = Model(x: 42)
    let dict = ["x": 42]
    assertThat(model).roundTrips(to: dict)
  }

  func testNullDecodesAsNil() throws {
    let decoder = FirebaseDataDecoder()
    let opt = try decoder.decode(Int?.self, from: NSNull())
    XCTAssertNil(opt)
  }

  func testEmpty() {
    struct Model: Codable, Equatable {}
    assertThat(Model()).roundTrips(to: [String: Any]())
  }

  func testString() throws {
    struct Model: Codable, Equatable {
      let s: String
    }
    assertThat(Model(s: "abc")).roundTrips(to: ["s": "abc"])
  }

  func testCaseConversion() throws {
    struct Model: Codable, Equatable {
      let snakeCase: Int
    }
    let model = Model(snakeCase: 42)
    let dict = ["snake_case": 42]
    let encoder = FirebaseDataEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let decoder = FirebaseDataDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    assertThat(model).roundTrips(to: dict, using: encoder, decoder: decoder)
  }

  func testOptional() {
    struct Model: Codable, Equatable {
      let x: Int
      let opt: Int?
    }
    assertThat(Model(x: 42, opt: nil)).roundTrips(to: ["x": 42])
    assertThat(Model(x: 42, opt: 7)).roundTrips(to: ["x": 42, "opt": 7])
    assertThat(["x": 42, "opt": 5]).decodes(to: Model(x: 42, opt: 5))
    assertThat(["x": 42, "opt": true]).failsDecoding(to: Model.self)
    assertThat(["x": 42, "opt": "abc"]).failsDecoding(to: Model.self)
    assertThat(["x": 45.55, "opt": 5]).failsDecoding(to: Model.self)
    assertThat(["opt": 5]).failsDecoding(to: Model.self)

    // TODO: - handle encoding keys with nil values
    // See https://stackoverflow.com/questions/47266862/encode-nil-value-as-null-with-jsonencoder
    // and https://bugs.swift.org/browse/SR-9232
    //     XCTAssertTrue(encodedDict.keys.contains("x"))
  }

  func testEnum() {
    enum MyEnum: Codable, Equatable {
      case num(number: Int)
      case text(String)

      private enum CodingKeys: String, CodingKey {
        case num
        case text
      }

      private enum DecodingError: Error {
        case decoding(String)
      }

      init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? values.decode(Int.self, forKey: .num) {
          self = .num(number: value)
          return
        }
        if let value = try? values.decode(String.self, forKey: .text) {
          self = .text(value)
          return
        }
        throw DecodingError.decoding("Decoding error: \(dump(values))")
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .num(number):
          try container.encode(number, forKey: .num)
        case let .text(value):
          try container.encode(value, forKey: .text)
        }
      }
    }
    struct Model: Codable, Equatable {
      let x: Int
      let e: MyEnum
    }

    assertThat(Model(x: 42, e: MyEnum.num(number: 4)))
      .roundTrips(to: ["x": 42, "e": ["num": 4]])

    assertThat(Model(x: 43, e: MyEnum.text("abc")))
      .roundTrips(to: ["x": 43, "e": ["text": "abc"]])
  }

  func testBadValue() {
    struct Model: Codable, Equatable {
      let x: Int
    }
    assertThat(["x": "abc"]).failsDecoding(to: Model.self) // Wrong type
  }

  func testValueTooBig() {
    struct Model: Codable, Equatable {
      let x: CChar
    }
    assertThat(Model(x: 42)).roundTrips(to: ["x": 42])
    assertThat(["x": 12345]).failsDecoding(to: Model.self) // Overflow
  }

  // Inspired by https://github.com/firebase/firebase-android-sdk/blob/master/firebase-firestore/src/test/java/com/google/firebase/firestore/util/MapperTest.java
  func testBeans() {
    struct Model: Codable, Equatable {
      let s: String
      let d: Double
      let f: Float
      let l: CLongLong
      let i: Int
      let b: Bool
      let sh: CShort
      let byte: CChar
      let uchar: CUnsignedChar
      let ai: [Int]
      let si: [String]
      let caseSensitive: String
      let casESensitive: String
      let casESensitivE: String
    }
    let model = Model(
      s: "abc",
      d: 123,
      f: -4,
      l: 1_234_567_890_123,
      i: -4444,
      b: false,
      sh: 123,
      byte: 45,
      uchar: 44,
      ai: [1, 2, 3, 4],
      si: ["abc", "def"],
      caseSensitive: "aaa",
      casESensitive: "bbb",
      casESensitivE: "ccc"
    )
    let dict = [
      "s": "abc",
      "d": 123,
      "f": -4,
      "l": Int64(1_234_567_890_123),
      "i": -4444,
      "b": false,
      "sh": 123,
      "byte": 45,
      "uchar": 44,
      "ai": [1, 2, 3, 4],
      "si": ["abc", "def"],
      "caseSensitive": "aaa",
      "casESensitive": "bbb",
      "casESensitivE": "ccc",
    ] as [String: Any]

    assertThat(model).roundTrips(to: dict)
  }

  func testCodingKeysCanCustomizeEncodingAndDecoding() throws {
    struct Model: Codable, Equatable {
      var s: String
      var ms: String = "filler"
      var d: Double
      var md: Double = 42.42

      // Use CodingKeys to only encode part of the struct.
      enum CodingKeys: String, CodingKey {
        case s
        case d
      }
    }

    assertThat(Model(s: "abc", ms: "dummy", d: 123.3, md: 0))
      .encodes(to: ["s": "abc", "d": 123.3])
      .decodes(to: Model(s: "abc", ms: "filler", d: 123.3, md: 42.42))
  }

  func testNestedObjects() {
    struct SecondLevelNestedModel: Codable, Equatable {
      var age: Int8
      var weight: Double
    }
    struct NestedModel: Codable, Equatable {
      var group: String
      var groupList: [SecondLevelNestedModel]
      var groupMap: [String: SecondLevelNestedModel]
    }
    struct Model: Codable, Equatable {
      var id: Int64
      var group: NestedModel
    }

    let model = Model(
      id: 123,
      group: NestedModel(
        group: "g1",
        groupList: [
          SecondLevelNestedModel(age: 20, weight: 80.1),
          SecondLevelNestedModel(age: 25, weight: 85.1),
        ],
        groupMap: [
          "name1": SecondLevelNestedModel(age: 30, weight: 64.2),
          "name2": SecondLevelNestedModel(age: 35, weight: 79.2),
        ]
      )
    )

    let dict = [
      "group": [
        "group": "g1",
        "groupList": [
          [
            "age": 20,
            "weight": 80.1,
          ],
          [
            "age": 25,
            "weight": 85.1,
          ],
        ],
        "groupMap": [
          "name1": [
            "age": 30,
            "weight": 64.2,
          ],
          "name2": [
            "age": 35,
            "weight": 79.2,
          ],
        ],
      ] as [String: Any],
      "id": 123,
    ] as [String: Any]

    assertThat(model).roundTrips(to: dict)
  }

  func testCollapsingNestedObjects() {
    // The model is flat but the document has a nested Map.
    struct Model: Codable, Equatable {
      var id: Int64
      var name: String

      init(id: Int64, name: String) {
        self.id = id
        self.name = name
      }

      private enum CodingKeys: String, CodingKey {
        case id
        case nested
      }

      private enum NestedCodingKeys: String, CodingKey {
        case name
      }

      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try id = container.decode(Int64.self, forKey: .id)

        let nestedContainer = try container
          .nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .nested)
        try name = nestedContainer.decode(String.self, forKey: .name)
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        var nestedContainer = container
          .nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .nested)
        try nestedContainer.encode(name, forKey: .name)
      }
    }

    assertThat(Model(id: 12345, name: "ModelName"))
      .roundTrips(to: [
        "id": 12345,
        "nested": ["name": "ModelName"],
      ])
  }

  class SuperModel: Codable, Equatable {
    var superPower: Double? = 100.0
    var superName: String? = "superName"

    init(power: Double, name: String) {
      superPower = power
      superName = name
    }

    static func == (lhs: SuperModel, rhs: SuperModel) -> Bool {
      return (lhs.superName == rhs.superName) && (lhs.superPower == rhs.superPower)
    }

    private enum CodingKeys: String, CodingKey {
      case superPower
      case superName
    }

    required init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      superPower = try container.decode(Double.self, forKey: .superPower)
      superName = try container.decode(String.self, forKey: .superName)
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(superPower, forKey: .superPower)
      try container.encode(superName, forKey: .superName)
    }
  }

  class SubModel: SuperModel {
    var timestamp: Double? = 123_456_789.123

    init(power: Double, name: String, seconds: Double) {
      super.init(power: power, name: name)
      timestamp = seconds
    }

    static func == (lhs: SubModel, rhs: SubModel) -> Bool {
      return ((lhs as SuperModel) == (rhs as SuperModel)) && (lhs.timestamp == rhs.timestamp)
    }

    private enum CodingKeys: String, CodingKey {
      case timestamp
    }

    required init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      timestamp = try container.decode(Double.self, forKey: .timestamp)
      try super.init(from: container.superDecoder())
    }

    override func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(timestamp, forKey: .timestamp)
      try super.encode(to: container.superEncoder())
    }
  }

  func testClassHierarchy() {
    assertThat(SubModel(power: 100, name: "name", seconds: 123_456_789.123))
      .roundTrips(to: [
        "super": ["superPower": 100, "superName": "name"] as [String: Any],
        "timestamp": 123_456_789.123,
      ])
  }
}

private func assertThat(_ dictionary: [String: Any],
                        file: StaticString = #file,
                        line: UInt = #line) -> DictionarySubject {
  return DictionarySubject(dictionary, file: file, line: line)
}

func assertThat<X: Equatable & Codable>(_ model: X, file: StaticString = #file,
                                        line: UInt = #line) -> CodableSubject<X> {
  return CodableSubject(model, file: file, line: line)
}

func assertThat<X: Equatable & Encodable>(_ model: X, file: StaticString = #file,
                                          line: UInt = #line) -> EncodableSubject<X> {
  return EncodableSubject(model, file: file, line: line)
}

class EncodableSubject<X: Equatable & Encodable> {
  var subject: X
  var file: StaticString
  var line: UInt

  init(_ subject: X, file: StaticString, line: UInt) {
    self.subject = subject
    self.file = file
    self.line = line
  }

  @discardableResult
  func encodes(to expected: [String: Any],
               using encoder: FirebaseDataEncoder = .init()) -> DictionarySubject {
    let encoded = assertEncodes(to: expected, using: encoder)
    return DictionarySubject(encoded, file: file, line: line)
  }

  func failsToEncode() {
    do {
      let encoder = FirebaseDataEncoder()
      encoder.keyEncodingStrategy = .convertToSnakeCase
      _ = try encoder.encode(subject)
    } catch {
      return
    }
    XCTFail("Failed to throw")
  }

  func failsEncodingAtTopLevel() {
    do {
      let encoder = FirebaseDataEncoder()
      encoder.keyEncodingStrategy = .convertToSnakeCase
      _ = try encoder.encode(subject)
      XCTFail("Failed to throw", file: file, line: line)
    } catch EncodingError.invalidValue(_, _) {
      return
    } catch {
      XCTFail("Unrecognized error: \(error)", file: file, line: line)
    }
  }

  private func assertEncodes(to expected: [String: Any],
                             using encoder: FirebaseDataEncoder = .init()) -> [String: Any] {
    do {
      let enc = try encoder.encode(subject)
      XCTAssertEqual(enc as? NSDictionary, expected as NSDictionary, file: file, line: line)
      return (enc as! NSDictionary) as! [String: Any]
    } catch {
      XCTFail("Failed to encode \(X.self): error: \(error)")
      return ["": -1]
    }
  }
}

class CodableSubject<X: Equatable & Codable>: EncodableSubject<X> {
  func roundTrips(to expected: [String: Any],
                  using encoder: FirebaseDataEncoder = .init(),
                  decoder: FirebaseDataDecoder = .init()) {
    let reverseSubject = encodes(to: expected, using: encoder)
    reverseSubject.decodes(to: subject, using: decoder)
  }
}

class DictionarySubject {
  var subject: [String: Any]
  var file: StaticString
  var line: UInt

  init(_ subject: [String: Any], file: StaticString, line: UInt) {
    self.subject = subject
    self.file = file
    self.line = line
  }

  func decodes<X: Equatable & Codable>(to expected: X,
                                       using decoder: FirebaseDataDecoder = .init()) -> Void {
    do {
      let decoded = try decoder.decode(X.self, from: subject)
      XCTAssertEqual(decoded, expected)
    } catch {
      XCTFail("Failed to decode \(X.self): \(error)", file: file, line: line)
    }
  }

  func failsDecoding<X: Equatable & Codable>(to _: X.Type,
                                             using decoder: FirebaseDataDecoder = .init()) -> Void {
    XCTAssertThrowsError(
      try decoder.decode(X.self, from: subject),
      file: file,
      line: line
    )
  }
}
