// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
struct RealtimePipelineSource: @unchecked Sendable {
  let db: Firestore
  let factory: ([Stage], Firestore) -> RealtimePipeline

  init(db: Firestore, factory: @escaping ([Stage], Firestore) -> RealtimePipeline) {
    self.db = db
    self.factory = factory
  }

  func collection(_ path: String) -> RealtimePipeline {
    return factory([CollectionSource(collection: db.collection(path), db: db)], db)
  }

  func collection(_ coll: CollectionReference) -> RealtimePipeline {
    return factory([CollectionSource(collection: coll, db: db)], db)
  }

  func collectionGroup(_ collectionId: String) -> RealtimePipeline {
    return factory(
      [CollectionGroupSource(collectionId: collectionId)],
      db
    )
  }

  func documents(_ docs: [DocumentReference]) -> RealtimePipeline {
    return factory([DocumentsSource(docs: docs, db: db)], db)
  }

  func documents(_ paths: [String]) -> RealtimePipeline {
    let docs = paths.map { db.document($0) }
    return factory([DocumentsSource(docs: docs, db: db)], db)
  }
}
