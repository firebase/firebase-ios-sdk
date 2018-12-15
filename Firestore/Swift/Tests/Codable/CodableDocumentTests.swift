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
  func testInt() {
    struct Model: Codable {
      let x: Int
    }
    let model = Model(x: 42)
    let dict = ["x": 42]
    XCTAssertEqual((try Firestore.Encoder().encode(model)) as NSDictionary, dict as NSDictionary)
    let model2 = try? Firestore.Decoder().decode(Model.self, from: dict)
    XCTAssertEqual(model.x, model2!.x)
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
    XCTAssertNil(model2?.x)
  }

  func testGeoPoint() {
    struct Model: Codable {
      let p: GeoPoint
    }
    let model = Model(p: GeoPoint(latitude: 1, longitude: -2))
    let dict = ["p": GeoPoint(latitude: 1, longitude: -2)]

    XCTAssertEqual((try Firestore.Encoder().encode(model)) as NSDictionary, dict as NSDictionary)
    let model2 = try? Firestore.Decoder().decode(Model.self, from: dict)
    XCTAssertEqual(model.p, model2!.p)
  }

  func testDate() {
    struct Model: Codable {
      let date: Date
    }
    let d = Date(timeIntervalSinceReferenceDate: 0)
    let model = Model(date: d)
    let dict = ["date": d]

    XCTAssertEqual((try Firestore.Encoder().encode(model)) as NSDictionary, dict as NSDictionary)
    let model2 = try? Firestore.Decoder().decode(Model.self, from: dict)
    XCTAssertEqual(model.date, model2!.date)
  }

  func testDocumentReference() {
    struct Model: Codable {
      let doc: DocumentReference
    }
    let d = FSTTestDocRef("abc/xyz")
    let model = Model(doc: d)
    let dict = ["doc": d]

    XCTAssertEqual((try Firestore.Encoder().encode(model)) as NSDictionary, dict as NSDictionary)
    let model2 = try? Firestore.Decoder().decode(Model.self, from: dict)
    XCTAssertEqual(model.doc, model2!.doc)
  }

  func testTimestamp() {
    struct Model: Codable {
      let timestamp: Timestamp
    }
    let t = Timestamp(date: Date())
    let model = Model(timestamp: t)
    let encoded = (try! Firestore.Encoder().encode(model))
    let model2 = try? Firestore.Decoder().decode(Model.self, from: encoded)
    XCTAssertEqual(model.timestamp, model2!.timestamp)
  }

  func testBadValue() {
    struct Model: Codable {
      let x: Int
    }
    let dict = ["x": "abc"]
    let model2 = try? Firestore.Decoder().decode(Model.self, from: dict)
    XCTAssertNil(model2)
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

    let model2 = try? Firestore.Decoder().decode(Model.self, from: dict)
    XCTAssertEqual(model.s, model2!.s)
    XCTAssertEqual(model.d, model2!.d)
    XCTAssertEqual(model.f, model2!.f)
    XCTAssertEqual(model.l, model2!.l)
    XCTAssertEqual(model.i, model2!.i)
    XCTAssertEqual(model.b, model2!.b)
    XCTAssertEqual(model.sh, model2!.sh)
    XCTAssertEqual(model.byte, model2!.byte)
    XCTAssertEqual(model.uchar, model2!.uchar)
    XCTAssertEqual(model.ai, model2!.ai)
    XCTAssertEqual(model.si, model2!.si)
    XCTAssertEqual(model.caseSensitive, model2!.caseSensitive)
    XCTAssertEqual(model.casESensitive, model2!.casESensitive)
    XCTAssertEqual(model.casESensitivE, model2!.casESensitivE)

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

//  func testDocumentEncodesBackwardsWithEncodeCall() {
  ////    let doc = FSTTestDocSnapshot("abc/xyz",
  ////                                 456,
  ////                                 ["stringKey": "myValue1", "intKey2":123, "floatKey": -1.23],
  ////                                 false,
  ////                                 false)
  ////
  ////    let jsonData = try! JSONEncoder().encode(doc)
  ////    let json = String(data: jsonData, encoding: .utf8)!
//
//    // The ordering of attributes in the JSON output is not guaranteed, nor is the rounding of
//    // the values so just verify that each required property is present and that the value
//    // starts as expected.
//    print (json)
//    XCTAssert(json.contains("\"latitude\":37."))
//    XCTAssert(json.contains("\"longitude\":-122."))
//  }
}
