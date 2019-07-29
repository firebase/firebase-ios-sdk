/*
 * Copyright 2019 Google
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

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import XCTest

private func assertRoundTrip<X: Equatable & Codable>(model: X, encoded: [String: Any]) -> Void {
  let enc = assertEncodes(model, encoded: encoded)
  assertDecodes(enc, encoded: model)
}

private func assertEncodes<X: Equatable & Codable>(_ model: X, encoded: [String: Any]) -> [String: Any] {
  do {
    let enc = try Firestore.Encoder().encode(model)
    XCTAssertEqual(enc as NSDictionary, encoded as NSDictionary)
    return enc
  } catch {
    XCTFail("Failed to encode \(X.self): error: \(error)")
  }
  return ["": -1]
}

private func assertDecodes<X: Equatable & Codable>(_ model: [String: Any], encoded: X) -> Void {
  do {
    let decoded = try Firestore.Decoder().decode(X.self, from: model)
    XCTAssertEqual(decoded, encoded)
  } catch {
    XCTFail("Failed to decode \(X.self): \(error)")
  }
}

private func assertEncodingThrows<X: Equatable & Codable>(_ model: X) -> Void {
  do {
    _ = try Firestore.Encoder().encode(model)
  } catch {
    return
  }
  XCTFail("Failed to throw")
}

private func assertDecodingThrows<X: Equatable & Codable>(_ model: [String: Any], encoded: X) -> Void {
  do {
    _ = try Firestore.Decoder().decode(X.self, from: model)
  } catch {
    return
  }
  XCTFail("Failed to throw")
}

class FirestoreEncoderTests: XCTestCase {
  func testInt() {
    struct Model: Codable, Equatable {
      let x: Int
    }
    let model = Model(x: 42)
    let dict = ["x": 42]
    assertRoundTrip(model: model, encoded: dict)
  }

  func testEmpty() {
    struct Model: Codable, Equatable {}
    _ = assertEncodes(Model(), encoded: [String: Any]())
  }

  func testString() {
    struct Model: Codable, Equatable {
      let s: String
    }
    let model = Model(s: "abc")
    let encodedDict = try! Firestore.Encoder().encode(model)
    XCTAssertEqual(encodedDict["s"] as! String, "abc")
  }

  func testOptional() {
    struct Model: Codable, Equatable {
      let x: Int
      let opt: Int?
    }
    assertRoundTrip(model: Model(x: 42, opt: nil), encoded: ["x": 42])
    assertRoundTrip(model: Model(x: 42, opt: 7), encoded: ["x": 42, "opt": 7])
    assertDecodes(["x": 42, "opt": 5], encoded: Model(x: 42, opt: 5))
    assertDecodingThrows(["x": 42, "opt": true], encoded: Model(x: 42, opt: nil))
    assertDecodingThrows(["x": 42, "opt": "abc"], encoded: Model(x: 42, opt: nil))
    assertDecodingThrows(["x": 45.55, "opt": 5], encoded: Model(x: 42, opt: nil))
    assertDecodingThrows(["opt": 5], encoded: Model(x: 42, opt: nil))

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

    let model = Model(x: 42, e: MyEnum.num(number: 4))
    assertRoundTrip(model: model, encoded: ["x": 42, "e": ["num": 4]])
    let model2 = Model(x: 43, e: MyEnum.text("abc"))
    assertRoundTrip(model: model2, encoded: ["x": 43, "e": ["text": "abc"]])
    let timestamp = Timestamp(date: Date())
    let model3 = Model(x: 43, e: MyEnum.timestamp(timestamp))
    assertRoundTrip(model: model3, encoded: ["x": 43, "e": ["timestamp": timestamp]])
  }

  func testGeoPoint() {
    struct Model: Codable, Equatable {
      let p: GeoPoint
    }
    let geopoint = GeoPoint(latitude: 1, longitude: -2)
    let model = Model(p: geopoint)
    assertRoundTrip(model: model, encoded: ["p": geopoint])
  }

  func testDate() {
    struct Model: Codable, Equatable {
      let date: Date
    }
    let date = Date(timeIntervalSinceReferenceDate: 0)
    let model = Model(date: date)
    assertRoundTrip(model: model, encoded: ["date": date])
  }

  func testDocumentReference() {
    struct Model: Codable, Equatable {
      let doc: DocumentReference
    }
    let d = FSTTestDocRef("abc/xyz")
    let model = Model(doc: d)
    assertRoundTrip(model: model, encoded: ["doc": d])
  }

  func testEncodingDocumentReferenceThrowsWithJSONEncoder() {
    let doc = FSTTestDocRef("abc/xyz")
    do {
      _ = try JSONEncoder().encode(doc)
      XCTFail("Failed to throw")
    } catch FirebaseFirestoreSwift.FirestoreEncodingError.encodingIsNotSupported {
      return
    } catch {
      XCTFail("Unrecognized error: \(error)")
    }
  }

  func testEncodingDocumentReferenceNotEmbeddedThrows() {
    let doc = FSTTestDocRef("abc/xyz")
    do {
      _ = try Firestore.Encoder().encode(doc)
      XCTFail("Failed to throw")
    } catch FirebaseFirestoreSwift.FirestoreEncodingError.encodingIsNotSupported {
      return
    } catch {
      XCTFail("Unrecognized error: \(error)")
    }
  }

  func testTimestamp() {
    struct Model: Codable, Equatable {
      let timestamp: Timestamp
    }
    let t = Timestamp(date: Date())
    let model = Model(timestamp: t)
    assertRoundTrip(model: model, encoded: ["timestamp": t])
  }

  func testBadValue() {
    struct Model: Codable, Equatable {
      let x: Int
    }
    let dict = ["x": "abc"] // Wrong type;
    let model = Model(x: 42)
    assertDecodingThrows(dict, encoded: model)
  }

  func testValueTooBig() {
    struct Model: Codable, Equatable {
      let x: CChar
    }
    let dict = ["x": 12345] // Overflow
    let model = Model(x: 42)
    assertDecodingThrows(dict, encoded: model)
    assertRoundTrip(model: model, encoded: ["x": 42])
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
      "l": 1_234_567_890_123,
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

    assertRoundTrip(model: model, encoded: dict)
  }

  func testCodingKeysCanCustomizeEncodingAndDecoding() {
    struct Model: Codable, Equatable {
      var s: String
      var ms: String
      var d: Double
      var md: Double

      // Use CodingKeys to only encode part of the struct.
      enum CodingKeys: String, CodingKey {
        case s
        case d
      }

      public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        s = try values.decode(String.self, forKey: .s)
        d = try values.decode(Double.self, forKey: .d)
        ms = "filler"
        md = 42.42
      }

      public init(ins: String, inms: String, ind: Double, inmd: Double) {
        s = ins
        d = ind
        ms = inms
        md = inmd
      }
    }
    let model = Model(
      ins: "abc",
      inms: "dummy",
      ind: 123.3,
      inmd: 0
    )
    let dict = [
      "s": "abc",
      "d": 123.3,
    ] as [String: Any]

    let model2 = try! Firestore.Decoder().decode(Model.self, from: dict)
    XCTAssertEqual(model.s, model2.s)
    XCTAssertEqual(model.d, model2.d)
    XCTAssertEqual(model2.ms, "filler")
    XCTAssertEqual(model2.md, 42.42)

    let encodedDict = try! Firestore.Encoder().encode(model)
    XCTAssertEqual(encodedDict["s"] as! String, "abc")
    XCTAssertEqual(encodedDict["d"] as! Double, 123.3)
    XCTAssertNil(encodedDict["ms"])
    XCTAssertNil(encodedDict["md"])
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

    let model = Model(id: 123, group: NestedModel(group: "g1", groupList: [SecondLevelNestedModel(age: 20, weight: 80.1), SecondLevelNestedModel(age: 25, weight: 85.1)], groupMap: ["name1": SecondLevelNestedModel(age: 30, weight: 64.2), "name2": SecondLevelNestedModel(age: 35, weight: 79.2)],
                                                  point: GeoPoint(latitude: 12.0, longitude: 9.1)))

    let dict = ["group": [
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
    ], "id": 123] as [String: Any]

    assertRoundTrip(model: model, encoded: dict)
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

        let nestedContainer = try container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .nested)
        try name = nestedContainer.decode(String.self, forKey: .name)
      }

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        var nestedContainer = container.nestedContainer(keyedBy: NestedCodingKeys.self, forKey: .nested)
        try nestedContainer.encode(name, forKey: .name)
      }
    }

    let model = Model(id: 12345, name: "ModelName")
    let dict = ["id": 12345,
                "nested": ["name": "ModelName"]] as [String: Any]

    assertRoundTrip(model: model, encoded: dict)
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
    let model = SubModel(power: 100, name: "name", seconds: 123_456_789, nano: 654_321)
    let dict = ["super": ["superPower": 100, "superName": "name"],
                "timestamp": Timestamp(seconds: 123_456_789, nanoseconds: 654_321)] as [String: Any]

    assertRoundTrip(model: model, encoded: dict)
  }

  func testEncodingEncodableArrayNotSupported() {
    struct Model: Codable, Equatable {
      var name: String
    }
    assertEncodingThrows([Model(name: "1")])
  }

  func testFieldValuePassthrough() {
    struct Model: Encodable, Equatable {
      var fieldValue: FieldValue
    }

    let model = Model(fieldValue: FieldValue.delete())
    let dict = ["fieldValue": FieldValue.delete()]

    let encoded = try! Firestore.Encoder().encode(model)

    XCTAssertEqual(dict, encoded as! [String: FieldValue])
  }

  func testEncodingFieldValueNotEmbeddedThrows() {
    let ts = FieldValue.serverTimestamp()
    do {
      _ = try Firestore.Encoder().encode(ts)
      XCTFail("Failed to throw")
    } catch FirebaseFirestoreSwift.FirestoreEncodingError.encodingIsNotSupported {
      return
    } catch {
      XCTFail("Unrecognized error: \(error)")
    }
  }

  func testServerTimestamp() {
    struct Model: Codable {
      var timestamp: ServerTimestamp
    }

    // Encoding `pending`
    var encoded = try! Firestore.Encoder().encode(Model(timestamp: .pending))
    XCTAssertEqual(encoded["timestamp"] as! FieldValue, FieldValue.serverTimestamp())

    // Encoding `resolved`
    encoded = try! Firestore.Encoder().encode(Model(timestamp: .resolved(Timestamp(seconds: 123_456_789, nanoseconds: 4321))))
    XCTAssertEqual(encoded["timestamp"] as! Timestamp,
                   Timestamp(seconds: 123_456_789, nanoseconds: 4321))

    // Decoding a Timestamp leads to `resolved`
    var dict = ["timestamp": Timestamp(seconds: 123_456_789, nanoseconds: 4321)] as [String: Any]
    var decoded = try! Firestore.Decoder().decode(Model.self, from: dict)
    XCTAssertEqual(decoded.timestamp,
                   ServerTimestamp.resolved(Timestamp(seconds: 123_456_789, nanoseconds: 4321)))

    // Decoding a NSNull() leads to `pending`.
    dict = ["timestamp": NSNull()] as [String: Any]
    decoded = try! Firestore.Decoder().decode(Model.self, from: dict)
    XCTAssertEqual(decoded.timestamp,
                   ServerTimestamp.pending)
  }

  func testExplicitNull() throws {
    struct Model: Codable, Equatable {
      var name: ExplicitNull<String>
    }

    // Encoding 'none'
    let fieldIsNull = Model(name: .none)
    var encoded = try Firestore.Encoder().encode(fieldIsNull)
    XCTAssertTrue(encoded.keys.contains("name"))
    XCTAssertEqual(encoded["name"]! as! NSNull, NSNull())

    // Decoding null
    var decoded = try Firestore.Decoder().decode(Model.self, from: encoded)
    XCTAssertEqual(decoded, fieldIsNull)

    // Encoding 'some'
    let fieldIsNotNull = Model(name: .some("good name"))
    encoded = try Firestore.Encoder().encode(fieldIsNotNull)
    XCTAssertEqual(encoded["name"]! as! String, "good name")

    // Decoding not-null value
    decoded = try Firestore.Decoder().decode(Model.self, from: encoded)
    XCTAssertEqual(decoded, fieldIsNotNull)
  }
}
