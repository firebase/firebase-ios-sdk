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
@testable import FirebaseFirestoreSwift
import XCTest

fileprivate func assertRoundTrip<X: Equatable & Codable>(model: X, encoded: [String: Any]) -> Void {
  let enc = assertEncodes(model, encoded: encoded)
  assertDecodes(enc, encoded: model)
}

fileprivate func assertEncodes<X: Equatable & Codable>(_ model: X, encoded: [String: Any]) -> [String: Any] {
  do {
    let enc = try Firestore.Encoder().encode(model)
    XCTAssertEqual(enc as NSDictionary, encoded as NSDictionary)
    return enc
  } catch {
    XCTFail("Failed to encode \(X.self): error: \(error)")
  }
  return ["": -1]
}

fileprivate func assertDecodes<X: Equatable & Codable>(_ model: [String: Any], encoded: X) -> Void {
  do {
    let decoded = try Firestore.Decoder().decode(X.self, from: model)
    XCTAssertEqual(decoded, encoded)
  } catch {
    XCTFail("Failed to decode \(X.self): \(error)")
  }
}

fileprivate func assertDecodingThrows<X: Equatable & Codable>(_ model: [String: Any], encoded: X) -> Void {
  do {
    _ = try Firestore.Decoder().decode(X.self, from: model)
  } catch {
    return
  }
  XCTFail("Failed to throw")
}

class CodableDocumentTests: XCTestCase {
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

  func testNil() {
    struct Model: Codable, Equatable {
      let x: Int?
    }
    let model = Model(x: nil)
    let dict = ["x": nil] as [String: Int?]
    let encodedDict = try! Firestore.Encoder().encode(model)
    XCTAssertNil(encodedDict["x"])
    let model2 = try? Firestore.Decoder().decode(Model.self, from: dict as [String: Any])
    XCTAssertNil(model2)
  }

  func testIntNilString() {
    struct Model: Codable, Equatable {
      let i: Int
      let x: Int?
      let s: String
    }
    let model = Model(i: 7, x: nil, s: "abc")
    let encodedDict = try! Firestore.Encoder().encode(model)
    XCTAssertNil(encodedDict["x"])
    XCTAssertTrue(encodedDict.keys.contains("i"))

    // TODO: - handle encoding keys with nil values
    // See https://stackoverflow.com/questions/47266862/encode-nil-value-as-null-with-jsonencoder
    // and https://bugs.swift.org/browse/SR-9232
    // XCTAssertTrue(encodedDict.keys.contains("x"))
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

  // Uncomment if we decide to reenable embedded DocumentReference's
//
//  func testDocumentReference() {
//    struct Model: Codable, Equatable {
//      let doc: DocumentReference
//    }
//    let d = FSTTestDocRef("abc/xyz")
//    let model = Model(doc: d)
//    assertRoundTrip(model: model, encoded: ["doc": d])
//  }
//
//  // DocumentReference is not Codable unless embedded in a Firestore object.
//  func testDocumentReferenceEncodes() {
//    let doc = FSTTestDocRef("abc/xyz")
//    do {
//      _ = try JSONEncoder().encode(doc)
//      XCTFail("Failed to throw")
//    } catch FirebaseFirestoreSwift.FirestoreEncodingError.encodingIsNotSupported {
//      return
//    } catch {
//      XCTFail("Unrecognized error: \(error)")
//    }
//  }

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

  func testCodingKeys() {
    struct Model: Codable, Equatable {
      var s: String
      var ms: String
      var d: Double
      var md: Double
      var i: Int
      var mi: Int
      var b: Bool
      var mb: Bool

      // Use CodingKeys to only encode part of the struct.
      enum CodingKeys: String, CodingKey {
        case s
        case d
        case i
        case b
      }

      public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        s = try values.decode(String.self, forKey: .s)
        d = try values.decode(Double.self, forKey: .d)
        i = try values.decode(Int.self, forKey: .i)
        b = try values.decode(Bool.self, forKey: .b)
        ms = "filler"
        md = 42.42
        mi = -9
        mb = false
      }

      public init(ins: String, inms: String, ind: Double, inmd: Double, ini: Int, inmi: Int, inb: Bool, inmb: Bool) {
        s = ins
        d = ind
        i = ini
        b = inb
        ms = inms
        md = inmd
        mi = inmi
        mb = inmb
      }
    }
    let model = Model(
      ins: "abc",
      inms: "dummy",
      ind: 123.3,
      inmd: 0,
      ini: -4444,
      inmi: 0,
      inb: true,
      inmb: true
    )
    let dict = [
      "s": "abc",
      "d": 123.3,
      "i": -4444,
      "b": true,
    ] as [String: Any]

    let model2 = try! Firestore.Decoder().decode(Model.self, from: dict)
    XCTAssertEqual(model.s, model2.s)
    XCTAssertEqual(model.d, model2.d)
    XCTAssertEqual(model.i, model2.i)
    XCTAssertEqual(model.b, model2.b)
    XCTAssertEqual(model2.ms, "filler")
    XCTAssertEqual(model2.md, 42.42)
    XCTAssertEqual(model2.mi, -9)
    XCTAssertEqual(model2.mb, false)

    let encodedDict = try! Firestore.Encoder().encode(model)
    XCTAssertEqual(encodedDict["s"] as! String, "abc")
    XCTAssertEqual(encodedDict["d"] as! Double, 123.3)
    XCTAssertEqual(encodedDict["i"] as! Int, -4444)
    XCTAssertEqual(encodedDict["b"] as! Bool, true)
    XCTAssertNil(encodedDict["ms"])
    XCTAssertNil(encodedDict["md"])
    XCTAssertNil(encodedDict["mi"])
    XCTAssertNil(encodedDict["mb"])
  }
}
