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
    let normalizedPath = path.hasPrefix("/") ? path : "/" + path
    return Pipeline(stages: [CollectionSource(collection: normalizedPath)], db: db)
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
    let paths = docs.map { $0.path }
    return Pipeline(stages: [DocumentsSource(paths: paths)], db: db)
  }

  public func documents(_ paths: [String]) -> Pipeline {
    return Pipeline(stages: [DocumentsSource(paths: paths)], db: db)
  }

  public func create(from query: Query) -> Pipeline {
    return Pipeline(stages: [QuerySource(query: query)], db: db)
  }

  public func create(from aggregateQuery: AggregateQuery) -> Pipeline {
    return Pipeline(stages: [AggregateQuerySource(aggregateQuery: aggregateQuery)], db: db)
  }
}
