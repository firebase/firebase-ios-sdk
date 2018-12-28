/*
 * Copyright 2018 Google
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

import FirebaseFirestore
@testable import FirebaseFirestoreSwift
import Foundation
import XCTest

class CodableDocumentTests: XCTestCase {
  func roundTrip <X>(input: X, expected: [String:Any], doTest: Bool = true) -> X where X : Codable {
    var encoded = [String: Any]()
    do {
      encoded = try Firestore.Encoder().encode(input)
      if doTest {
        XCTAssertEqual(encoded as NSDictionary, expected as NSDictionary)
      }
    } catch {
      XCTFail("Failed to encode \(X.self): error: \(error)")
    }
    do {
      let decoded = try Firestore.Decoder().decode(X.self, from: encoded)
      return decoded
    } catch {
      XCTFail("Failed to decode \(X.self): \(error)")
    }
    return input // After failure
  }

  func testInt() {
    struct Model: Codable {
      let x: Int
    }
    let model = Model(x: 42)
    let dict = ["x": 42]
    XCTAssertEqual(model.x, roundTrip(input: model, expected: dict).x)
  }

  func testEmpty() {
    struct Model: Codable {}
    let model = Model()
    let dict = [String: Any]()
    XCTAssertEqual((try Firestore.Encoder().encode(model)) as NSDictionary, dict as NSDictionary)
  }

  func testNil() {
    struct Model: Codable {
      let x: Int?
    }
    let model = Model(x: nil)
    let dict = ["x": nil] as [String: Int?]
    let encodedDict = try! Firestore.Encoder().encode(model)
    XCTAssertNil(encodedDict["x"])
    let model2 = try? Firestore.Decoder().decode(Model.self, from: dict as [String: Any])
    XCTAssertNil(model2)
  }

  func testOptional() {
    struct Model: Codable {
      let x: Int
      let opt: Int?
    }
    let dict = ["x": 42]
    let model = Model(x:42, opt:nil)
    XCTAssertEqual(model.x, roundTrip(input: model, expected: dict).x)

    let model2 = Model(x:42, opt:7)
    let expected = ["x": 42, "opt": 7]
    let encoded = try! Firestore.Encoder().encode(model2)
    XCTAssertEqual(encoded as NSDictionary, expected as NSDictionary)
    let decoded = try! Firestore.Decoder().decode(Model.self, from: expected)
    XCTAssertEqual(decoded.x, model2.x)
    XCTAssertEqual(decoded.opt, model2.opt)
  }

  func testOptionalTimestamp() {
    class FirestoreDummy {
      /// Partial keypath can represent the property name
      func setObject<T: Codable>(_ object: T, fieldValues: [PartialKeyPath<T>: FieldValue] = [:]) {
        // Encode, check if any timestamps are nil or not, and if so use FieldValue.serverTimestamp()
      }
    }
    struct Model: Codable {
      let value: Int
      let timestamp: Timestamp?
    }
    let c = Model(value: 10, timestamp: nil)
    let fs = FirestoreDummy()
    // If no custom field values need to be set:
    fs.setObject(c)

    // Or, overriding custom field values:
    fs.setObject(c, fieldValues: [\Model.timestamp: FieldValue.serverTimestamp(),
                                  \Model.value: FieldValue.delete()])
  }

  func testEnum() {
    enum MyEnum : Codable, Equatable {
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
        case .num(let number):
          try container.encode(number, forKey: .num)
        case .text(let value):
          try container.encode(value, forKey: .text)
        case .timestamp(let stamp):
          try container.encode(stamp, forKey: .timestamp)
        }
      }
    }
    struct Model: Codable {
      let x: Int
      let e: MyEnum
    }
    let model = Model(x: 42, e: MyEnum.num(number: 4))
    let output = roundTrip(input: model, expected: [:], doTest: false)
    XCTAssertEqual(model.x, output.x)
    XCTAssertEqual(model.e, output.e)

    let model2 = Model(x: 43, e: MyEnum.text("abc"))
    let output2 = roundTrip(input: model2, expected: [:], doTest: false)
    XCTAssertEqual(model2.x, output2.x)
    XCTAssertEqual(model2.e, output2.e)

    let model3 = Model(x: 43, e: MyEnum.timestamp(Timestamp(date: Date())))
    let output3 = roundTrip(input: model3, expected: [:], doTest: false)
    XCTAssertEqual(model3.x, output3.x)
    XCTAssertEqual(model3.e, output3.e)
  }

  func testGeoPoint() {
    struct Model: Codable {
      let p: GeoPoint
    }
    let model = Model(p: GeoPoint(latitude: 1, longitude: -2))
    let dict = ["p": GeoPoint(latitude: 1, longitude: -2)]
    XCTAssertEqual(model.p, roundTrip(input: model, expected: dict).p)
  }

  func testDate() {
    struct Model: Codable {
      let date: Date
    }
    let d = Date(timeIntervalSinceReferenceDate: 0)
    let model = Model(date: d)
    let dict = ["date": d]
    XCTAssertEqual(model.date, roundTrip(input: model, expected: dict).date)
  }

  func testDocumentReference() {
    struct Model: Codable {
      let doc: DocumentReference
    }
    let d = FSTTestDocRef("abc/xyz")
    let model = Model(doc: d)
    let dict = ["doc": d]
    XCTAssertEqual(model.doc, roundTrip(input: model, expected: dict).doc)
  }

  func testTimestamp() {
    struct Model: Codable {
      let timestamp: Timestamp
    }
    let t = Timestamp(date: Date())
    let model = Model(timestamp: t)
    let encoded = (try! Firestore.Encoder().encode(model))
    let model2 = try! Firestore.Decoder().decode(Model.self, from: encoded)
    XCTAssertEqual(model.timestamp, model2.timestamp)
  }

  func testBadValue() {
    struct Model: Codable {
      let x: Int
    }
    let dict = ["x": "abc"]
    var didThrow = false
    do {
      _ = try Firestore.Decoder().decode(Model.self, from: dict)
    } catch {
      didThrow = true;
    }
    XCTAssertTrue(didThrow)
  }

  func testValueTooBig() {
    struct Model: Codable {
      let x: CChar
    }
    let dict = ["x": 12345]
    let model = try? Firestore.Decoder().decode(Model.self, from: dict)
    XCTAssertNil(model)

    let dict2 = ["x": 12]
    let model2 = try? Firestore.Decoder().decode(Model.self, from: dict2)
    XCTAssertNotNil(model2)
  }

  // Inspired by https://github.com/firebase/firebase-android-sdk/blob/master/firebase-firestore/src/test/java/com/google/firebase/firestore/util/MapperTest.java
  func testBeans() {
    struct Model: Codable {
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
      f: -4.321,
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
      "f": -4.321,
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

    let model2 = try! Firestore.Decoder().decode(Model.self, from: dict)
    XCTAssertEqual(model.s, model2.s)
    XCTAssertEqual(model.d, model2.d)
    XCTAssertEqual(model.f, model2.f)
    XCTAssertEqual(model.l, model2.l)
    XCTAssertEqual(model.i, model2.i)
    XCTAssertEqual(model.b, model2.b)
    XCTAssertEqual(model.sh, model2.sh)
    XCTAssertEqual(model.byte, model2.byte)
    XCTAssertEqual(model.uchar, model2.uchar)
    XCTAssertEqual(model.ai, model2.ai)
    XCTAssertEqual(model.si, model2.si)
    XCTAssertEqual(model.caseSensitive, model2.caseSensitive)
    XCTAssertEqual(model.casESensitive, model2.casESensitive)
    XCTAssertEqual(model.casESensitivE, model2.casESensitivE)

    let encodedDict = try! Firestore.Encoder().encode(model)
    XCTAssertEqual(encodedDict["s"] as! String, "abc")
    XCTAssertEqual(encodedDict["d"] as! Double, 123)
    XCTAssertEqual(encodedDict["f"] as! Float, -4.321)
    XCTAssertEqual(encodedDict["l"] as! CLongLong, 1_234_567_890_123)
    XCTAssertEqual(encodedDict["i"] as! Int, -4444)
    XCTAssertEqual(encodedDict["b"] as! Bool, false)
    XCTAssertEqual(encodedDict["sh"] as! CShort, 123)
    XCTAssertEqual(encodedDict["byte"] as! CChar, 45)
    XCTAssertEqual(encodedDict["uchar"] as! CUnsignedChar, 44)
    XCTAssertEqual(encodedDict["ai"] as! [Int], [1, 2, 3, 4])
    XCTAssertEqual(encodedDict["si"] as! [String], ["abc", "def"])
    XCTAssertEqual(encodedDict["caseSensitive"] as! String, "aaa")
    XCTAssertEqual(encodedDict["casESensitive"] as! String, "bbb")
    XCTAssertEqual(encodedDict["casESensitivE"] as! String, "ccc")
  }

  func testCodingKeys() {
    struct Model: Codable {
      var s: String
      var ms: String
      var d: Double
      var md: Double
      var i: Int
      var mi: Int
      var b: Bool
      var mb: Bool

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
      public init(ins:String, inms:String, ind:Double, inmd:Double, ini:Int, inmi:Int, inb:Bool, inmb:Bool)  {
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
