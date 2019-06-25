//
//  CodableIntegrationTests.swift
//  Firestore_SwiftTests_iOS
//
//  Created by Hui Wu on 2019-06-24.
//  Copyright © 2019 Google. All rights reserved.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

class CodableIntegrationTests: FSTIntegrationTestCase {
  // Writes a `Encodable` to a document, then read it back after the write is completed
  // and run verification block against the data read back.
  func writeReadVerify<T: Encodable>(model: T, docToWrite: DocumentReference, verifyBlock: @escaping (_ data: [String: Any]?) throws -> Void) throws {
    let verifyExp = expectation(description: "Read/verify after write")
    try docToWrite.setData(from: model) { err in
      guard err == nil else {
        XCTFail("Writing to firestore failed.")
        return
      }
      docToWrite.getDocument { snap, err in
        guard err == nil else {
          XCTFail("Failed to read document.")
          return
        }
        let readAfterWrite = snap?.data()
        do {
          try verifyBlock(readAfterWrite)
        } catch {
          XCTFail("Running verification block failed.")
        }
        verifyExp.fulfill()
      }
  } }

  func testCodableRoundTrip() throws {
    struct Model: Codable, Equatable {
      var name: String
      var age: Int32
      var ts: Timestamp
      var geoPoint: GeoPoint
      var docRef: DocumentReference
    }
    let docToWrite = firestore().collection("coll").document()
    let model = Model(name: "test",
                      age: 42,
                      ts: Timestamp(seconds: 987_654_321, nanoseconds: 0),
                      geoPoint: GeoPoint(latitude: 45, longitude: 54),
                      docRef: docToWrite)
    try docToWrite.setData(from: model)

    let readAfterWrite = try readDocument(forRef: docToWrite).data(as: Model.self)

    XCTAssertEqual(readAfterWrite!, model)
  }

  func testServerTimestamp() throws {
    struct Model: Codable, Equatable {
      var name: String
      var ts: ServerTimestamp
    }

    let model = Model(name: "name", ts: ServerTimestamp.pending)
    let store = firestore()
    let docToWrite = store.collection("coll").document()

    try writeReadVerify(model: model, docToWrite: docToWrite) { data in
      let decoded = try Firestore.Decoder().decode(Model.self, from: data!)
      XCTAssertNotNil(decoded.ts)
      switch decoded.ts {
      case let .resolved(ts):
        XCTAssertGreaterThan(ts.seconds, 1_500_000_000)
      case .pending:
        XCTFail("Expect server timestamp is set, but getting .pending")
      }
    }
    awaitExpectations()
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

    let store = firestore()
    let docToWrite = store.collection("coll").document()

    try writeReadVerify(model: model, docToWrite: docToWrite) { data in
      XCTAssertEqual(data!["array"] as! [Int], [1, 2, 3])
      XCTAssertEqual(data!["intValue"] as! Int, 3)
    }
    awaitExpectations()
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

    let store = firestore()
    let docToWrite = store.collection("coll").document()

    try writeReadVerify(model: model, docToWrite: docToWrite) { data in
      XCTAssertTrue(data!.keys.contains("explicitNull"))
      XCTAssertEqual(data!["explicitNull"] as! NSNull, NSNull())

      XCTAssertFalse(data!.keys.contains("optional"))
    }
    awaitExpectations()
  }
}
