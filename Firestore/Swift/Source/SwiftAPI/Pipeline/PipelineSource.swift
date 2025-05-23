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
public struct PipelineSource: @unchecked Sendable {
  let db: Firestore

  init(_ db: Firestore) {
    self.db = db
  }

  public func collection(_ path: String) -> Pipeline {
    return Pipeline(stages: [CollectionSource(collection: db.collection(path), db: db)], db: db)
  }

  public func collection(_ ref: CollectionReference) -> Pipeline {
    let collectionStage = CollectionSource(collection: ref, db: db)
    return Pipeline(stages: [collectionStage], db: db)
  }

  public func collectionGroup(_ collectionId: String) -> Pipeline {
    return Pipeline(
      stages: [CollectionGroupSource(collectionId: collectionId)],
      db: db
    )
  }

  public func database() -> Pipeline {
    return Pipeline(stages: [DatabaseSource()], db: db)
  }

  public func documents(_ docs: [DocumentReference]) -> Pipeline {
    return Pipeline(stages: [DocumentsSource(docs: docs, db: db)], db: db)
  }

  public func documents(_ paths: [String]) -> Pipeline {
    let docs = paths.map { db.document($0) }
    let documentsStage = DocumentsSource(docs: docs, db: db)
    return Pipeline(stages: [documentsStage], db: db)
  }

  public func create(from query: Query) -> Pipeline {
    return Pipeline(stages: [QuerySource(query: query)], db: db)
  }

  public func create(from aggregateQuery: AggregateQuery) -> Pipeline {
    return Pipeline(stages: [AggregateQuerySource(aggregateQuery: aggregateQuery)], db: db)
  }
}
