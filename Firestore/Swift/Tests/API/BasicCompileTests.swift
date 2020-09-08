/*
 * Copyright 2017 Google
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

// These aren't tests in the usual sense--they just verify that the Objective-C to Swift translation
// results in the right names.

import Foundation
import XCTest

import FirebaseFirestore

class BasicCompileTests: XCTestCase {
  func testCompiled() {
    XCTAssertTrue(true)
  }
}

func main() {
  let db = initializeDb()

  let (collectionRef, documentRef) = makeRefs(database: db)

  let query = makeQuery(collection: collectionRef)

  writeDocument(at: documentRef)

  writeDocuments(at: documentRef, database: db)

  addDocument(to: collectionRef)

  readDocument(at: documentRef)
  readDocumentWithSource(at: documentRef)

  readDocuments(matching: query)
  readDocumentsWithSource(matching: query)

  listenToDocument(at: documentRef)

  listenToDocuments(matching: query)

  enableDisableNetwork(database: db)

  clearPersistence(database: db)

  types()

  waitForPendingWrites(database: db)

  addSnapshotsInSyncListener(database: db)

  terminateDb(database: db)
}

func initializeDb() -> Firestore {
  // Initialize with ProjectID.
  let firestore = Firestore.firestore()

  // Apply settings
  let settings = FirestoreSettings()
  settings.host = "localhost"
  settings.isPersistenceEnabled = true
  settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
  firestore.settings = settings

  return firestore
}

func makeRefs(database db: Firestore) -> (CollectionReference, DocumentReference) {
  var collectionRef = db.collection("my-collection")

  var documentRef: DocumentReference
  documentRef = collectionRef.document("my-doc")
  // or
  documentRef = db.document("my-collection/my-doc")

  // deeper collection (my-collection/my-doc/some/deep/collection)
  collectionRef = documentRef.collection("some/deep/collection")

  // parent doc (my-collection/my-doc/some/deep)
  documentRef = collectionRef.parent!

  // print paths.
  print("Collection: \(collectionRef.path), document: \(documentRef.path)")

  return (collectionRef, documentRef)
}

func makeQuery(collection collectionRef: CollectionReference) -> Query {
  var query = collectionRef.whereField(FieldPath(["name"]), isEqualTo: "Fred")
    .whereField("age", isGreaterThanOrEqualTo: 24)
    .whereField("tags", arrayContains: "active")
    .whereField(FieldPath(["tags"]), arrayContains: "active")
    .whereField("tags", arrayContainsAny: ["active", "squat"])
    .whereField(FieldPath(["tags"]), arrayContainsAny: ["active", "squat"])
    .whereField("tags", in: ["active", "squat"])
    .whereField(FieldPath(["tags"]), in: ["active", "squat"])
    .whereField("tags", notIn: ["active", "squat"])
    .whereField(FieldPath(["tags"]), notIn: ["active", "squat"])
    .whereField(FieldPath.documentID(), isEqualTo: "fred")
    .whereField(FieldPath.documentID(), isNotEqualTo: "fred")
    .order(by: FieldPath(["age"]))
    .order(by: "name", descending: true)
    .limit(to: 10)
    .limit(toLast: 10)

  query = collectionRef.firestore.collectionGroup("collection")

  return query
}

func writeDocument(at docRef: DocumentReference) {
  let setData = [
    "foo": 42,
    "bar": [
      "baz": "Hello world!",
    ],
  ] as [String: Any]

  let updateData = [
    "bar.baz": 42,
    FieldPath(["foobar"]): 42,
    "server_timestamp": FieldValue.serverTimestamp(),
    "array_union": FieldValue.arrayUnion(["a", "b"]),
    "array_remove": FieldValue.arrayRemove(["a", "b"]),
    "field_delete": FieldValue.delete(),
  ] as [AnyHashable: Any]

  docRef.setData(setData)

  // Completion callback (via trailing closure syntax).
  docRef.setData(setData) { error in
    if let error = error {
      print("Uh oh! \(error)")
      return
    }

    print("Set complete!")
  }

  // merge
  docRef.setData(setData, merge: true)
  docRef.setData(setData, merge: true) { error in
    if let error = error {
      print("Uh oh! \(error)")
      return
    }

    print("Set complete!")
  }

  docRef.updateData(updateData)
  docRef.delete()

  docRef.delete { error in
    if let error = error {
      print("Uh oh! \(error)")
      return
    }

    print("Set complete!")
  }
}

func enableDisableNetwork(database db: Firestore) {
  // closure syntax
  db.disableNetwork(completion: { error in
    if let e = error {
      print("Uh oh! \(e)")
      return
    }
  })
  // trailing block syntax
  db.enableNetwork { error in
    if let e = error {
      print("Uh oh! \(e)")
      return
    }
  }
}

func clearPersistence(database db: Firestore) {
  db.clearPersistence { error in
    if let e = error {
      print("Uh oh! \(e)")
      return
    }
  }
}

func writeDocuments(at docRef: DocumentReference, database db: Firestore) {
  var batch: WriteBatch

  batch = db.batch()
  batch.setData(["a": "b"], forDocument: docRef)
  batch.setData(["a": "b"], forDocument: docRef, merge: true)
  batch.setData(["c": "d"], forDocument: docRef)
  // commit without completion callback.
  batch.commit()
  print("Batch write without completion complete!")

  batch = db.batch()
  batch.setData(["a": "b"], forDocument: docRef)
  batch.setData(["c": "d"], forDocument: docRef)
  // commit with completion callback via trailing closure syntax.
  batch.commit { error in
    if let error = error {
      print("Uh oh! \(error)")
      return
    }
    print("Batch write callback complete!")
  }
  print("Batch write with completion complete!")
}

func addDocument(to collectionRef: CollectionReference) {
  _ = collectionRef.addDocument(data: ["foo": 42])
  // or
  collectionRef.document().setData(["foo": 42])
}

func readDocument(at docRef: DocumentReference) {
  // Trailing closure syntax.
  docRef.getDocument { document, error in
    if let document = document {
      // Note that both document and document.data() is nullable.
      if let data = document.data() {
        print("Read document: \(data)")
      }
      if let data = document.data(with: .estimate) {
        print("Read document: \(data)")
      }
      if let foo = document.get("foo") {
        print("Field: \(foo)")
      }
      if let foo = document.get("foo", serverTimestampBehavior: .previous) {
        print("Field: \(foo)")
      }
      // Fields can also be read via subscript notation.
      if let foo = document["foo"] {
        print("Field: \(foo)")
      }
    } else {
      // TODO(mikelehen): There may be a better way to do this, but it at least demonstrates
      // the swift error domain / enum codes are renamed appropriately.
      if let errorCode = error.flatMap({
        ($0._domain == FirestoreErrorDomain) ? FirestoreErrorCode(rawValue: $0._code) : nil
      }) {
        switch errorCode {
        case .unavailable:
          print("Can't read document due to being offline!")
        case _:
          print("Failed to read.")
        }
      } else {
        print("Unknown error!")
      }
    }
  }
}

func readDocumentWithSource(at docRef: DocumentReference) {
  docRef.getDocument(source: FirestoreSource.default) { document, error in
  }
  docRef.getDocument(source: .server) { document, error in
  }
  docRef.getDocument(source: FirestoreSource.cache) { document, error in
  }
}

func readDocuments(matching query: Query) {
  query.getDocuments { querySnapshot, error in
    // TODO(mikelehen): Figure out how to make "for..in" syntax work
    // directly on documentSet.
    for document in querySnapshot!.documents {
      print(document.data())
    }
  }
}

func readDocumentsWithSource(matching query: Query) {
  query.getDocuments(source: FirestoreSource.default) { querySnapshot, error in
  }
  query.getDocuments(source: .server) { querySnapshot, error in
  }
  query.getDocuments(source: FirestoreSource.cache) { querySnapshot, error in
  }
}

func listenToDocument(at docRef: DocumentReference) {
  let listener = docRef.addSnapshotListener { document, error in
    if let error = error {
      print("Uh oh! Listen canceled: \(error)")
      return
    }

    if let document = document {
      // Note that document.data() is nullable.
      if let data: [String: Any] = document.data() {
        print("Current document: \(data)")
      }
      if document.metadata.isFromCache {
        print("From Cache")
      } else {
        print("From Server")
      }
    }
  }

  // Unsubscribe.
  listener.remove()
}

func listenToDocumentWithMetadataChanges(at docRef: DocumentReference) {
  let listener = docRef.addSnapshotListener(includeMetadataChanges: true) { document, error in
    if let document = document {
      if document.metadata.hasPendingWrites {
        print("Has pending writes")
      }
    }
  }

  // Unsubscribe.
  listener.remove()
}

func listenToDocuments(matching query: Query) {
  let listener = query.addSnapshotListener { snap, error in
    if let error = error {
      print("Uh oh! Listen canceled: \(error)")
      return
    }

    if let snap = snap {
      print("NEW SNAPSHOT (empty=\(snap.isEmpty) count=\(snap.count)")

      // TODO(mikelehen): Figure out how to make "for..in" syntax work
      // directly on documentSet.
      for document in snap.documents {
        // Note that document.data() is not nullable.
        let data: [String: Any] = document.data()
        print("Doc: ", data)
      }
    }
  }

  // Unsubscribe
  listener.remove()
}

func listenToQueryDiffs(onQuery query: Query) {
  let listener = query.addSnapshotListener { snap, error in
    if let snap = snap {
      for change in snap.documentChanges {
        switch change.type {
        case .added:
          print("New document: \(change.document.data())")
        case .modified:
          print("Modified document: \(change.document.data())")
        case .removed:
          print("Removed document: \(change.document.data())")
        }
      }
    }
  }

  // Unsubscribe
  listener.remove()
}

func listenToQueryDiffsWithMetadata(onQuery query: Query) {
  let listener = query.addSnapshotListener(includeMetadataChanges: true) { snap, error in
    if let snap = snap {
      for change in snap.documentChanges(includeMetadataChanges: true) {
        switch change.type {
        case .added:
          print("New document: \(change.document.data())")
        case .modified:
          print("Modified document: \(change.document.data())")
        case .removed:
          print("Removed document: \(change.document.data())")
        }
      }
    }
  }

  // Unsubscribe
  listener.remove()
}

func transactions() {
  let db = Firestore.firestore()

  let collectionRef = db.collection("cities")
  let accA = collectionRef.document("accountA")
  let accB = collectionRef.document("accountB")
  let amount = 20.0

  db.runTransaction({ (transaction, errorPointer) -> Any? in
    do {
      let balanceA = try transaction.getDocument(accA)["balance"] as! Double
      let balanceB = try transaction.getDocument(accB)["balance"] as! Double

      if balanceA < amount {
        errorPointer?.pointee = NSError(domain: "Foo", code: 123, userInfo: nil)
        return nil
      }
      transaction.updateData(["balance": balanceA - amount], forDocument: accA)
      transaction.updateData(["balance": balanceB + amount], forDocument: accB)
    } catch let error as NSError {
      print("Uh oh! \(error)")
    }
    return 0
  }) { result, error in
    // handle result.
  }
}

func types() {
  let _: CollectionReference
  let _: DocumentChange
  let _: DocumentReference
  let _: DocumentSnapshot
  let _: FieldPath
  let _: FieldValue
  let _: Firestore
  let _: FirestoreSettings
  let _: GeoPoint
  let _: Timestamp
  let _: ListenerRegistration
  let _: Query
  let _: QuerySnapshot
  let _: SnapshotMetadata
  let _: Transaction
  let _: WriteBatch
}

func waitForPendingWrites(database db: Firestore) {
  db.waitForPendingWrites { error in
    if let e = error {
      print("Uh oh! \(e)")
      return
    }
  }
}

func addSnapshotsInSyncListener(database db: Firestore) {
  let listener = db.addSnapshotsInSyncListener {}

  // Unsubscribe
  listener.remove()
}

func terminateDb(database db: Firestore) {
  db.terminate { error in
    if let e = error {
      print("Uh oh! \(e)")
      return
    }
  }
}
