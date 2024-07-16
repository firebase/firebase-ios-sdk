/*
 * Copyright 2019 Google LLC
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

import class FirebaseCore.Timestamp
import FirebaseFirestore
import Foundation
import XCTest

class FirestoreEncoderTests: XCTestCase {
  func testInt() {
    struct Model: Codable, Equatable {
      let x: Int
    }
    let model = Model(x: 42)
    let dict = ["x": 42]
    assertThat(model).roundTrips(to: dict)
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
    // XCTAssertTrue(encodedDict.keys.contains("x"))
  }

  func testEnum() {
    enum MyEnum: Codable, Equatable {
      case num(number: Int)
      case text(String)
      case timestamp(Timestamp)

      private enum CodingKeys: String, CodingKey {
        case num
        case text
        case timestamp
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
        if let value = try? values.decode(Timestamp.self, forKey: .timestamp) {
          self = .timestamp(value)
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
        case let .timestamp(stamp):
          try container.encode(stamp, forKey: .timestamp)
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

    let timestamp = Timestamp(date: Date())
    assertThat(Model(x: 43, e: MyEnum.timestamp(timestamp)))
      .roundTrips(to: ["x": 43, "e": ["timestamp": timestamp]])
  }

  func testGeoPoint() {
    struct Model: Codable, Equatable {
      let p: GeoPoint
    }
    let geopoint = GeoPoint(latitude: 1, longitude: -2)
    assertThat(Model(p: geopoint)).roundTrips(to: ["p": geopoint])
  }

  func testDate() {
    struct Model: Codable, Equatable {
      let date: Date
    }
    let date = Date(timeIntervalSinceReferenceDate: 0)
    assertThat(Model(date: date)).roundTrips(to: ["date": Timestamp(date: date)])
  }

  func testTimestampCanDecodeAsDate() {
    struct EncodingModel: Codable, Equatable {
      let date: Timestamp
    }
    struct DecodingModel: Codable, Equatable {
      let date: Date
    }

    let date = Date(timeIntervalSinceReferenceDate: 0)
    let timestamp = Timestamp(date: date)
    assertThat(EncodingModel(date: timestamp))
      .encodes(to: ["date": timestamp])
      .decodes(to: DecodingModel(date: date))
  }

  func testDocumentReference() {
    struct Model: Codable, Equatable {
      let doc: DocumentReference
    }
    let d = FSTTestDocRef("abc/xyz")
    assertThat(Model(doc: d)).roundTrips(to: ["doc": d])
  }

  func testEncodingDocumentReferenceThrowsWithJSONEncoder() {
    assertThat(FSTTestDocRef("abc/xyz")).failsEncodingWithJSONEncoder()
  }

  func testEncodingDocumentReferenceNotEmbeddedThrows() {
    assertThat(FSTTestDocRef("abc/xyz")).failsEncodingAtTopLevel()
  }

  func testTimestamp() {
    struct Model: Codable, Equatable {
      let timestamp: Timestamp
    }
    let t = Timestamp(date: Date())
    assertThat(Model(timestamp: t)).roundTrips(to: ["timestamp": t])
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
      var point: GeoPoint
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
        ],
        point: GeoPoint(latitude: 12.0, longitude: 9.1)
      )
    )

    let dict = [
      "group": [
        "group": "g1",
        "point": GeoPoint(latitude: 12.0, longitude: 9.1),
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
      ],
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
    var timestamp: Timestamp? = Timestamp(seconds: 848_483_737, nanoseconds: 23423)

    init(power: Double, name: String, seconds: Int64, nano: Int32) {
      super.init(power: power, name: name)
      timestamp = Timestamp(seconds: seconds, nanoseconds: nano)
    }

    static func == (lhs: SubModel, rhs: SubModel) -> Bool {
      return ((lhs as SuperModel) == (rhs as SuperModel)) && (lhs.timestamp == rhs.timestamp)
    }

    private enum CodingKeys: String, CodingKey {
      case timestamp
    }

    required init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      timestamp = try container.decode(Timestamp.self, forKey: .timestamp)
      try super.init(from: container.superDecoder())
    }

    override func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(timestamp, forKey: .timestamp)
      try super.encode(to: container.superEncoder())
    }
  }

  func testClassHierarchy() {
    assertThat(SubModel(power: 100, name: "name", seconds: 123_456_789, nano: 654_321))
      .roundTrips(to: [
        "super": ["superPower": 100, "superName": "name"],
        "timestamp": Timestamp(seconds: 123_456_789, nanoseconds: 654_321),
      ])
  }

  func testEncodingEncodableArrayNotSupported() {
    struct Model: Codable, Equatable {
      var name: String
    }
    assertThat([Model(name: "1")]).failsToEncode()
  }

  func testFieldValuePassthrough() throws {
    struct Model: Encodable, Equatable {
      var fieldValue: FieldValue
    }
    assertThat(Model(fieldValue: FieldValue.delete()))
      .encodes(to: ["fieldValue": FieldValue.delete()])
  }

  func testEncodingFieldValueNotEmbeddedThrows() {
    let ts = FieldValue.serverTimestamp()
    assertThat(ts).failsEncodingAtTopLevel()
  }

  func testServerTimestamp() throws {
    struct Model: Codable, Equatable {
      @ServerTimestamp var timestamp: Timestamp? = nil
    }

    // Encoding a pending server timestamp
    assertThat(Model())
      .encodes(to: ["timestamp": FieldValue.serverTimestamp()])

    // Encoding a resolved server timestamp yields a timestamp; decoding
    // yields it back.
    let timestamp = Timestamp(seconds: 123_456_789, nanoseconds: 4321)
    assertThat(Model(timestamp: timestamp))
      .roundTrips(to: ["timestamp": timestamp])

    // Decoding a NSNull() leads to nil.
    assertThat(["timestamp": NSNull()])
      .decodes(to: Model(timestamp: nil))
  }

  func testServerTimestampOfDate() throws {
    struct Model: Codable, Equatable {
      @ServerTimestamp var date: Date? = nil
    }

    // Encoding a pending server timestamp
    assertThat(Model())
      .encodes(to: ["date": FieldValue.serverTimestamp()])

    // Encoding a resolved server timestamp yields a timestamp; decoding
    // yields it back.
    let timestamp = Timestamp(seconds: 123_456_789, nanoseconds: 0)
    let date: Date = timestamp.dateValue()
    assertThat(Model(date: date))
      .roundTrips(to: ["date": timestamp])

    // Decoding a NSNull() leads to nil.
    assertThat(["date": NSNull()])
      .decodes(to: Model(date: nil))
  }

  func testServerTimestampUserType() throws {
    struct Model: Codable, Equatable {
      @ServerTimestamp var timestamp: String? = nil
    }

    // Encoding a pending server timestamp
    assertThat(Model())
      .encodes(to: ["timestamp": FieldValue.serverTimestamp()])

    // Encoding a resolved server timestamp yields a timestamp; decoding
    // yields it back.
    let timestamp = Timestamp(seconds: 1_570_484_031, nanoseconds: 122_999_906)
    assertThat(Model(timestamp: "2019-10-07T21:33:51.123Z"))
      .roundTrips(to: ["timestamp": timestamp])

    assertThat(Model(timestamp: "Invalid date"))
      .failsToEncode()
  }

  func testExplicitNull() throws {
    struct Model: Codable, Equatable {
      @ExplicitNull var name: String?
    }

    assertThat(Model(name: nil))
      .roundTrips(to: ["name": NSNull()])

    assertThat(Model(name: "good name"))
      .roundTrips(to: ["name": "good name"])
  }

  func testAutomaticallyPopulatesDocumentIDOnDocumentReference() throws {
    struct Model: Codable, Equatable {
      var name: String
      @DocumentID var docId: DocumentReference?
    }
    assertThat(["name": "abc"], in: "abc/123")
      .decodes(to: Model(name: "abc", docId: FSTTestDocRef("abc/123")))
  }

  func testAutomaticallyPopulatesDocumentIDOnString() throws {
    struct Model: Codable, Equatable {
      var name: String
      @DocumentID var docId: String?
    }
    assertThat(["name": "abc"], in: "abc/123")
      .decodes(to: Model(name: "abc", docId: "123"))
  }

  func testDocumentIDIgnoredInEncoding() throws {
    struct Model: Codable, Equatable {
      var name: String
      @DocumentID var docId: DocumentReference?
    }
    assertThat(Model(name: "abc", docId: FSTTestDocRef("abc/123")))
      .encodes(to: ["name": "abc"])
  }

  func testDocumentIDWithJsonEncoderThrows() {
    assertThat(DocumentID(wrappedValue: FSTTestDocRef("abc/xyz")))
      .failsEncodingWithJSONEncoder()
  }

  func testDecodingDocumentIDWithConfictingFieldsDoesNotThrow() throws {
    struct Model: Codable, Equatable {
      var name: String
      @DocumentID var docId: DocumentReference?
    }

    _ = try Firestore.Decoder().decode(
      Model.self,
      from: ["name": "abc", "docId": "Does not cause conflict"],
      in: FSTTestDocRef("abc/123")
    )
  }
}

private func assertThat(_ dictionary: [String: Any],
                        in document: String? = nil,
                        file: StaticString = #file,
                        line: UInt = #line) -> DictionarySubject {
  return DictionarySubject(dictionary, in: document, file: file, line: line)
}

private func assertThat<X: Equatable & Codable>(_ model: X, file: StaticString = #file,
                                                line: UInt = #line) -> CodableSubject<X> {
  return CodableSubject(model, file: file, line: line)
}

private func assertThat<X: Equatable & Encodable>(_ model: X, file: StaticString = #file,
                                                  line: UInt = #line) -> EncodableSubject<X> {
  return EncodableSubject(model, file: file, line: line)
}

private class EncodableSubject<X: Equatable & Encodable> {
  var subject: X
  var file: StaticString
  var line: UInt

  init(_ subject: X, file: StaticString, line: UInt) {
    self.subject = subject
    self.file = file
    self.line = line
  }

  @discardableResult
  func encodes(to expected: [String: Any]) -> DictionarySubject {
    let encoded = assertEncodes(to: expected)
    return DictionarySubject(encoded, file: file, line: line)
  }

  func failsToEncode() {
    do {
      _ = try Firestore.Encoder().encode(subject)
    } catch {
      return
    }
    XCTFail("Failed to throw")
  }

  func failsEncodingWithJSONEncoder() {
    do {
      _ = try JSONEncoder().encode(subject)
      XCTFail("Failed to throw", file: file, line: line)
    } catch FirestoreEncodingError.encodingIsNotSupported {
      return
    } catch {
      XCTFail("Unrecognized error: \(error)", file: file, line: line)
    }
  }

  func failsEncodingAtTopLevel() {
    do {
      _ = try Firestore.Encoder().encode(subject)
      XCTFail("Failed to throw", file: file, line: line)
    } catch EncodingError.invalidValue(_, _) {
      return
    } catch {
      XCTFail("Unrecognized error: \(error)", file: file, line: line)
    }
  }

  private func assertEncodes(to expected: [String: Any]) -> [String: Any] {
    do {
      let enc = try Firestore.Encoder().encode(subject)
      XCTAssertEqual(enc as NSDictionary, expected as NSDictionary, file: file, line: line)
      return enc
    } catch {
      XCTFail("Failed to encode \(X.self): error: \(error)")
      return ["": -1]
    }
  }
}

private class CodableSubject<X: Equatable & Codable>: EncodableSubject<X> {
  func roundTrips(to expected: [String: Any]) {
    let reverseSubject = encodes(to: expected)
    reverseSubject.decodes(to: subject)
  }
}

private class DictionarySubject {
  var subject: [String: Any]
  var document: DocumentReference?
  var file: StaticString
  var line: UInt

  init(_ subject: [String: Any], in documentName: String? = nil, file: StaticString, line: UInt) {
    self.subject = subject
    if let documentName {
      document = FSTTestDocRef(documentName)
    }
    self.file = file
    self.line = line
  }

  func decodes<X: Equatable & Codable>(to expected: X) -> Void {
    do {
      let decoded = try Firestore.Decoder().decode(X.self, from: subject, in: document)
      XCTAssertEqual(decoded, expected)
    } catch {
      XCTFail("Failed to decode \(X.self): \(error)", file: file, line: line)
    }
  }

  func failsDecoding<X: Equatable & Codable>(to _: X.Type) -> Void {
    XCTAssertThrowsError(try Firestore.Decoder().decode(X.self, from: subject), file: file,
                         line: line)
  }
}

enum DateError: Error {
  case invalidDate(String)
}

// Extends Strings to allow them to be wrapped with @ServerTimestamp. Resolved
// server timestamps will be stored in an ISO 8601 date format.
//
// This example exists outside the main implementation to show that users can
// extend @ServerTimestamp with arbitrary types.
extension String: ServerTimestampWrappable {
  static let formatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
    return formatter
  }()

  public static func wrap(_ timestamp: Timestamp) throws -> Self {
    return formatter.string(from: timestamp.dateValue())
  }

  public static func unwrap(_ value: Self) throws -> Timestamp {
    let date = formatter.date(from: value)
    if let date {
      return Timestamp(date: date)
    } else {
      throw DateError.invalidDate(value)
    }
  }
}
