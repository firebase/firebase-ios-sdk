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

import class FirebaseCore.Timestamp
import FirebaseFirestore
import Foundation
import XCTest

class ConditionalConformanceTests: XCTestCase {
  func testBaseline() {
    struct Model: Codable, Equatable, Hashable {
      let x: Int
    }

    var dict = [Model: String]()
    dict[Model(x: 42)] = "foo"
    XCTAssertEqual("foo", dict[Model(x: 42)])
  }

  func testDocumentIDOfString() {
    struct Model: Codable, Equatable, Hashable {
      @DocumentID var x: String?
    }

    XCTAssertTrue(Model(x: "42") == Model(x: "42"))
    XCTAssertFalse(Model(x: "42") == Model(x: "1"))

    let dict: [Model: String] = [Model(x: "42"): "foo"]
    XCTAssertEqual("foo", dict[Model(x: "42")])
  }

  func testDocumentIDOfDocumentReference() {
    // This works because `FIRDocumentReference` implements a `hash` selector
    // and that's automatically bridged to conform to Swift `Hashable`.
    struct Model: Codable, Equatable, Hashable {
      @DocumentID var x: DocumentReference?
    }

    let doc1 = FSTTestDocRef("abc/xyz")
    let doc2 = FSTTestDocRef("abc/xyz")
    let doc3 = FSTTestDocRef("abc/def")

    XCTAssertTrue(Model(x: doc1) == Model(x: doc2))
    XCTAssertTrue(Model(x: doc1) != Model(x: doc3))
    XCTAssertFalse(Model(x: doc1) == Model(x: doc3))

    let dict: [Model: String] = [Model(x: doc1): "foo"]
    XCTAssertEqual("foo", dict[Model(x: doc2)])
  }

  func testExplicitNull() {
    struct Model: Codable, Equatable, Hashable {
      @ExplicitNull var x: Int?
    }

    XCTAssertTrue(Model(x: 42) == Model(x: 42))
    XCTAssertFalse(Model(x: 42) == Model(x: 1))

    let dict: [Model: String] = [Model(x: 42): "foo"]
    XCTAssertEqual("foo", dict[Model(x: 42)])
  }

  func testServerTimestampOfTimestamp() {
    struct Model: Codable, Equatable, Hashable {
      @ServerTimestamp var x: Timestamp?
    }

    let ts1 = Timestamp(seconds: 123, nanoseconds: 456)
    let ts2 = ts1.copy() as! Timestamp
    let ts3 = Timestamp(seconds: 789, nanoseconds: 0)

    XCTAssertTrue(Model(x: ts1) == Model(x: ts2))
    XCTAssertTrue(Model(x: ts1) != Model(x: ts3))
    XCTAssertFalse(Model(x: ts1) == Model(x: ts3))

    let dict: [Model: String] = [Model(x: ts1): "foo"]
    XCTAssertEqual("foo", dict[Model(x: ts2)])
  }

  func testServerTimestampOfDate() {
    struct Model: Codable, Equatable, Hashable {
      @ServerTimestamp var x: Date?
    }

    let ts1 = Date(timeIntervalSince1970: 42.0)
    let ts2 = Date(timeIntervalSince1970: 42.0)
    let ts3 = Date(timeIntervalSince1970: 100.0)

    XCTAssertTrue(Model(x: ts1) == Model(x: ts2))
    XCTAssertTrue(Model(x: ts1) != Model(x: ts3))
    XCTAssertFalse(Model(x: ts1) == Model(x: ts3))

    let dict: [Model: String] = [Model(x: ts1): "foo"]
    XCTAssertEqual("foo", dict[Model(x: ts2)])
  }
}
