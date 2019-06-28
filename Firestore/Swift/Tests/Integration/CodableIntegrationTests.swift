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

class CodableIntegrationTests: FSTIntegrationTestCase {
  private enum WriteFlavor {
    case docRef
    case writeBatch
    case transaction
  }

  private let allFlavors: [WriteFlavor] = [.docRef, .writeBatch, .transaction]

  private func setData<T: Encodable>(from value: T,
                                     forDocument doc: DocumentReference,
                                     withFlavor flavor: WriteFlavor = .docRef,
                                     merge: Bool? = nil,
                                     mergeFields: [Any]? = nil) throws {
    let completion = completionForExpectation(withName: "setData")

    switch flavor {
    case .docRef:
      if let merge = merge {
        try doc.setData(from: value, merge: merge, completion: completion)
      } else if let mergeFields = mergeFields {
        try doc.setData(from: value, mergeFields: mergeFields, completion: completion)
      } else {
        try doc.setData(from: value, completion: completion)
      }
    case .writeBatch:
      if let merge = merge {
        try doc.firestore.batch().setData(from: value, forDocument: doc, merge: merge).commit(completion: completion)
      } else if let mergeFields = mergeFields {
        try doc.firestore.batch().setData(from: value, forDocument: doc, mergeFields: mergeFields).commit(completion: completion)
      } else {
        try doc.firestore.batch().setData(from: value, forDocument: doc).commit(completion: completion)
      }
    case .transaction:
      doc.firestore.runTransaction({ (transaction, errorPointer) -> Any? in
        do {
          if let merge = merge {
            try transaction.setData(from: value, forDocument: doc, merge: merge)
          } else if let mergeFields = mergeFields {
            try transaction.setData(from: value, forDocument: doc, mergeFields: mergeFields)
          } else {
            try transaction.setData(from: value, forDocument: doc)
          }
        } catch {
          XCTFail("setData with transation failed.")
        }
        return nil
      }) { object, error in
        completion?(error)
    } }

    awaitExpectations()
  }

  func testCodableRoundTrip() throws {
    struct Model: Codable, Equatable {
      var name: String
      var age: Int32
      var ts: Timestamp
      var geoPoint: GeoPoint
      var docRef: DocumentReference
    }
    let docToWrite = documentRef()
    let model = Model(name: "test",
                      age: 42,
                      ts: Timestamp(seconds: 987_654_321, nanoseconds: 0),
                      geoPoint: GeoPoint(latitude: 45, longitude: 54),
                      docRef: docToWrite)

    for flavor in allFlavors {
      try setData(from: model, forDocument: docToWrite, withFlavor: flavor)

      let readAfterWrite = try readDocument(forRef: docToWrite).data(as: Model.self)

      XCTAssertEqual(readAfterWrite!, model, "Failed with flavor \(flavor)")
    }
  }

  func testServerTimestamp() throws {
    struct Model: Codable, Equatable {
      var name: String
      var ts: ServerTimestamp
    }
    let model = Model(name: "name", ts: ServerTimestamp.pending)
    let docToWrite = documentRef()

    for flavor in allFlavors {
      try setData(from: model, forDocument: docToWrite, withFlavor: flavor)

      let decoded = try readDocument(forRef: docToWrite).data(as: Model.self)

      XCTAssertNotNil(decoded?.ts, "Failed with flavor \(flavor)")
      switch decoded!.ts {
      case let .resolved(ts):
        XCTAssertGreaterThan(ts.seconds, 1_500_000_000, "Failed with flavor \(flavor)")
      case .pending:
        XCTFail("Expect server timestamp is set, but getting .pending")
      }
    }
  }

  func testFieldValue() throws {
    struct Model: Encodable {
      var name: String
      var array: FieldValue
      var intValue: FieldValue
    }
    let model = Model(
      name: "name",
      array: FieldValue.arrayUnion([1, 2, 3]),
      intValue: FieldValue.increment(3 as Int64)
    )

    let docToWrite = documentRef()

    for flavor in allFlavors {
      try setData(from: model, forDocument: docToWrite, withFlavor: flavor)

      let data = readDocument(forRef: docToWrite)

      XCTAssertEqual(data["array"] as! [Int], [1, 2, 3], "Failed with flavor \(flavor)")
      XCTAssertEqual(data["intValue"] as! Int, 3, "Failed with flavor \(flavor)")
    }
  }

  func testExplicitNull() throws {
    struct Model: Encodable {
      var name: String
      var explicitNull: ExplicitNull<String>
      var optional: Optional<String>
    }
    let model = Model(
      name: "name",
      explicitNull: .none,
      optional: nil
    )

    let docToWrite = documentRef()

    for flavor in allFlavors {
      try setData(from: model, forDocument: docToWrite, withFlavor: flavor)

      let data = readDocument(forRef: docToWrite).data()

      XCTAssertTrue(data!.keys.contains("explicitNull"), "Failed with flavor \(flavor)")
      XCTAssertEqual(data!["explicitNull"] as! NSNull, NSNull(), "Failed with flavor \(flavor)")
      XCTAssertFalse(data!.keys.contains("optional"), "Failed with flavor \(flavor)")
    }
  }

  func testSetThenMerge() throws {
    struct Model: Codable, Equatable {
      var name: String? = nil
      var age: Int32? = nil
      var hobby: String? = nil
    }
    let docToWrite = documentRef()
    let model = Model(name: "test",
                      age: 42, hobby: nil)
    // 'name' will be skipped in merge because it's Optional.
    let update = Model(name: nil, age: 43, hobby: "No")

    for flavor in allFlavors {
      try setData(from: model, forDocument: docToWrite, withFlavor: flavor)
      try setData(from: update, forDocument: docToWrite, withFlavor: flavor, merge: true)

      var readAfterUpdate = try readDocument(forRef: docToWrite).data(as: Model.self)

      XCTAssertEqual(readAfterUpdate!, Model(name: "test",
                                             age: 43, hobby: "No"), "Failed with flavor \(flavor)")

      let newUpdate = Model(name: "xxxx", age: 10, hobby: "Play")
      // Note 'name' is not updated.
      try setData(from: newUpdate, forDocument: docToWrite, withFlavor: flavor, mergeFields: ["age", FieldPath(["hobby"])])

      readAfterUpdate = try readDocument(forRef: docToWrite).data(as: Model.self)
      XCTAssertEqual(readAfterUpdate!, Model(name: "test",
                                             age: 10, hobby: "Play"), "Failed with flavor \(flavor)")
    }
  }
}
