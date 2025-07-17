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
@testable import FirebaseFirestore
import Foundation

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
      if let merge {
        try doc.setData(from: value, merge: merge, completion: completion)
      } else if let mergeFields {
        try doc.setData(from: value, mergeFields: mergeFields, completion: completion)
      } else {
        try doc.setData(from: value, completion: completion)
      }
    case .writeBatch:
      if let merge {
        try doc.firestore.batch().setData(from: value, forDocument: doc, merge: merge)
          .commit(completion: completion)
      } else if let mergeFields {
        try doc.firestore.batch().setData(from: value, forDocument: doc, mergeFields: mergeFields)
          .commit(completion: completion)
      } else {
        try doc.firestore.batch().setData(from: value, forDocument: doc)
          .commit(completion: completion)
      }
    case .transaction:
      doc.firestore.runTransaction({ transaction, errorPointer -> Any? in
        do {
          if let merge {
            try transaction.setData(from: value, forDocument: doc, merge: merge)
          } else if let mergeFields {
            try transaction.setData(from: value, forDocument: doc, mergeFields: mergeFields)
          } else {
            try transaction.setData(from: value, forDocument: doc)
          }
        } catch {
          XCTFail("setData with transaction failed.")
        }
        return nil
      }) { object, error in
        completion(error)
      }
    }

    awaitExpectations()
  }

  private struct ModelWithTestField<T: Codable & Equatable>: Codable {
    var name: String
    var testField: T
  }

  private func assertCanWriteAndReadCodableValueWithAllFlavors<T: Codable &
    Equatable>(value: T) throws {
    let model = ModelWithTestField(
      name: "name",
      testField: value
    )

    let docToWrite = documentRef()

    for flavor in allFlavors {
      try setData(from: model, forDocument: docToWrite, withFlavor: flavor)

      let data = try readDocument(forRef: docToWrite).data(as: ModelWithTestField<T>.self)

      XCTAssertEqual(
        data.testField,
        value,
        "Failed with flavor \(flavor)"
      )
    }
  }

  func testCodableRoundTrip() throws {
    struct Model: Codable, Equatable {
      var name: String
      var age: Int32
      var ts: Timestamp
      var geoPoint: GeoPoint
      var docRef: DocumentReference
      var vector: VectorValue
      var regex: RegexValue
      var int32: Int32Value
      var decimal128: Decimal128Value
      var minKey: MinKey
      var maxKey: MaxKey
      var bsonOjectId: BSONObjectId
      var bsonTimestamp: BSONTimestamp
      var bsonBinaryData: BSONBinaryData
    }
    let docToWrite = documentRef()
    let model = Model(name: "test",
                      age: 42,
                      ts: Timestamp(seconds: 987_654_321, nanoseconds: 0),
                      geoPoint: GeoPoint(latitude: 45, longitude: 54),
                      docRef: docToWrite,
                      vector: FieldValue.vector([0.7, 0.6]),
                      regex: RegexValue(pattern: "^foo", options: "i"),
                      int32: Int32Value(1),
                      decimal128: Decimal128Value("1.5"),
                      minKey: MinKey.shared,
                      maxKey: MaxKey.shared,
                      bsonOjectId: BSONObjectId("507f191e810c19729de860ec"),
                      bsonTimestamp: BSONTimestamp(seconds: 123, increment: 456),
                      bsonBinaryData: BSONBinaryData(subtype: 128, data: Data([1, 2])))

    for flavor in allFlavors {
      try setData(from: model, forDocument: docToWrite, withFlavor: flavor)

      let readAfterWrite = try readDocument(forRef: docToWrite).data(as: Model.self)

      XCTAssertEqual(readAfterWrite, model, "Failed with flavor \(flavor)")
    }
  }

  func testServerTimestamp() throws {
    struct Model: Codable, Equatable {
      var name: String
      @ServerTimestamp var ts: Timestamp? = nil
    }
    let model = Model(name: "name")
    let docToWrite = documentRef()

    for flavor in allFlavors {
      try setData(from: model, forDocument: docToWrite, withFlavor: flavor)

      let decoded = try readDocument(forRef: docToWrite).data(as: Model.self)

      XCTAssertNotNil(decoded.ts, "Failed with flavor \(flavor)")
      if let ts = decoded.ts {
        XCTAssertGreaterThan(ts.seconds, 1_500_000_000, "Failed with flavor \(flavor)")
      } else {
        XCTFail("Expect server timestamp is set, but getting .pending")
      }
    }
  }

  func testServerTimestampBehavior() throws {
    struct Model: Codable, Equatable {
      var name: String
      @ServerTimestamp var ts: Timestamp? = nil
    }

    disableNetwork()
    let docToWrite = documentRef()
    let now = Int64(Date().timeIntervalSince1970)
    let pastTimestamp = Timestamp(seconds: 807_940_800, nanoseconds: 0)

    // Write a document with a current value to enable testing with .previous.
    let originalModel = Model(name: "name", ts: pastTimestamp)
    let completion1 = completionForExpectation(withName: "setData")
    try docToWrite.setData(from: originalModel, completion: completion1)

    // Overwrite with a nil server timestamp so that ServerTimestampBehavior is testable.
    let newModel = Model(name: "name")
    let completion2 = completionForExpectation(withName: "setData")
    try docToWrite.setData(from: newModel, completion: completion2)

    let snapshot = readDocument(forRef: docToWrite)
    var decoded = try snapshot.data(as: Model.self, with: .none)
    XCTAssertNil(decoded.ts)

    decoded = try snapshot.data(as: Model.self, with: .estimate)
    XCTAssertNotNil(decoded.ts)
    XCTAssertNotNil(decoded.ts?.seconds)
    XCTAssertGreaterThanOrEqual(decoded.ts!.seconds, now)

    decoded = try snapshot.data(as: Model.self, with: .previous)
    XCTAssertNotNil(decoded.ts)
    XCTAssertNotNil(decoded.ts?.seconds)
    XCTAssertEqual(decoded.ts!.seconds, pastTimestamp.seconds)

    enableNetwork()
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

    let docToWrite = documentRef()

    for flavor in allFlavors {
      try setData(from: model, forDocument: docToWrite, withFlavor: flavor)

      let data = readDocument(forRef: docToWrite)

      XCTAssertEqual(data["array"] as! [Int], [1, 2, 3], "Failed with flavor \(flavor)")
      XCTAssertEqual(data["intValue"] as! Int, 3, "Failed with flavor \(flavor)")
    }
  }

  func testVectorValue() throws {
    try assertCanWriteAndReadCodableValueWithAllFlavors(value: VectorValue([0.1, 0.3, 0.4]))
  }

  func testMinKey() throws {
    try assertCanWriteAndReadCodableValueWithAllFlavors(value: MinKey.shared)
  }

  func testMaxKey() throws {
    try assertCanWriteAndReadCodableValueWithAllFlavors(value: MaxKey.shared)
  }

  func testRegexValue() throws {
    try assertCanWriteAndReadCodableValueWithAllFlavors(value: RegexValue(
      pattern: "^foo",
      options: "i"
    ))
  }

  func testInt32Value() throws {
    try assertCanWriteAndReadCodableValueWithAllFlavors(value: Int32Value(123))
  }

  func testDecimal128Value() throws {
    try assertCanWriteAndReadCodableValueWithAllFlavors(value: Decimal128Value("1.2e3"))
  }

  func testBsonObjectId() throws {
    try assertCanWriteAndReadCodableValueWithAllFlavors(
      value: BSONObjectId("507f191e810c19729de860ec")
    )
  }

  func testBsonTimestamp() throws {
    try assertCanWriteAndReadCodableValueWithAllFlavors(
      value: BSONTimestamp(seconds: 123, increment: 456)
    )
  }

  func testBsonBinaryData() throws {
    try assertCanWriteAndReadCodableValueWithAllFlavors(
      value: BSONBinaryData(subtype: 128, data: Data([1, 2, 3]))
    )
  }

  func testDataBlob() throws {
    struct Model: Encodable {
      var name: String
      var data: Data
      var emptyData: Data
    }
    let model = Model(
      name: "name",
      data: Data([1, 2, 3, 4]),
      emptyData: Data()
    )

    let docToWrite = documentRef()

    for flavor in allFlavors {
      try setData(from: model, forDocument: docToWrite, withFlavor: flavor)

      let data = readDocument(forRef: docToWrite)

      XCTAssertEqual(data["data"] as! Data, Data([1, 2, 3, 4]), "Failed with flavor \(flavor)")
      XCTAssertEqual(data["emptyData"] as! Data, Data(), "Failed with flavor \(flavor)")
    }

    disableNetwork()
    defer {
      enableNetwork()
    }

    try docToWrite.setData(from: model)
    let data = readDocument(forRef: docToWrite)
    XCTAssertEqual(data["data"] as! Data, Data([1, 2, 3, 4]), "Failed with flavor offline docRef")
    XCTAssertEqual(data["emptyData"] as! Data, Data(), "Failed with flavor offline docRef")
  }

  func testExplicitNull() throws {
    struct Model: Encodable {
      var name: String
      @ExplicitNull var explicitNull: String?
      var optional: String?
    }
    let model = Model(
      name: "name",
      explicitNull: nil,
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

  func testSelfDocumentID() throws {
    struct Model: Codable, Equatable {
      var name: String
      @DocumentID var docId: DocumentReference?
    }

    let docToWrite = documentRef()
    let model = Model(
      name: "name",
      docId: nil
    )

    try setData(from: model, forDocument: docToWrite, withFlavor: .docRef)
    let data = readDocument(forRef: docToWrite).data()

    // "docId" is ignored during encoding
    XCTAssertEqual(data! as! [String: String], ["name": "name"])

    // Decoded result has "docId" auto-populated.
    let decoded = try readDocument(forRef: docToWrite).data(as: Model.self)
    XCTAssertEqual(decoded, Model(name: "name", docId: docToWrite))
  }

  func testSelfDocumentIDWithCustomCodable() throws {
    struct Model: Codable, Equatable {
      var name: String
      @DocumentID var docId: DocumentReference?

      enum CodingKeys: String, CodingKey {
        case name
        case docId
      }

      public init(name: String, docId: DocumentReference?) {
        self.name = name
        self.docId = docId
      }

      public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        docId = try container.decode(DocumentID<DocumentReference>.self, forKey: .docId)
          .wrappedValue
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        // DocumentId should not be encoded when writing to Firestore; it's auto-populated when
        // reading.
      }
    }

    let docToWrite = documentRef()
    let model = Model(
      name: "name",
      docId: nil
    )

    try setData(from: model, forDocument: docToWrite, withFlavor: .docRef)
    let data = readDocument(forRef: docToWrite).data()

    // "docId" is ignored during encoding
    XCTAssertEqual(data! as! [String: String], ["name": "name"])

    // Decoded result has "docId" auto-populated.
    let decoded = try readDocument(forRef: docToWrite).data(as: Model.self)
    XCTAssertEqual(decoded, Model(name: "name", docId: docToWrite))
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

      XCTAssertEqual(readAfterUpdate, Model(name: "test",
                                            age: 43, hobby: "No"), "Failed with flavor \(flavor)")

      let newUpdate = Model(name: "xxxx", age: 10, hobby: "Play")
      // Note 'name' is not updated.
      try setData(from: newUpdate, forDocument: docToWrite, withFlavor: flavor,
                  mergeFields: ["age", FieldPath(["hobby"])])

      readAfterUpdate = try readDocument(forRef: docToWrite).data(as: Model.self)
      XCTAssertEqual(readAfterUpdate, Model(name: "test",
                                            age: 10,
                                            hobby: "Play"), "Failed with flavor \(flavor)")
    }
  }

  func testAddDocument() throws {
    struct Model: Codable, Equatable {
      var name: String
    }

    let collection = collectionRef()
    let model = Model(name: "test")

    let added = expectation(description: "Add document")
    let docRef = try collection.addDocument(from: model) { error in
      XCTAssertNil(error)
      added.fulfill()
    }
    awaitExpectations()

    let result = try readDocument(forRef: docRef).data(as: Model.self)
    XCTAssertEqual(model, result)
  }
}
