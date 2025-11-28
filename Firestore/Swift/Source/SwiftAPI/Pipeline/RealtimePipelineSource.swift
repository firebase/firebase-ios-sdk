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
public struct RealtimePipelineSource: @unchecked Sendable {
  let db: Firestore
  let factory: ([Stage], Firestore) -> RealtimePipeline

  init(db: Firestore, factory: @escaping ([Stage], Firestore) -> RealtimePipeline) {
    self.db = db
    self.factory = factory
  }

  public func collection(_ path: String) -> RealtimePipeline {
    return factory([CollectionSource(collection: db.collection(path), db: db)], db)
  }

  public func collection(_ coll: CollectionReference) -> RealtimePipeline {
    return factory([CollectionSource(collection: coll, db: db)], db)
  }

  public func collectionGroup(_ collectionId: String) -> RealtimePipeline {
    return factory(
      [CollectionGroupSource(collectionId: collectionId)],
      db
    )
  }

  public func documents(_ docs: [DocumentReference]) -> RealtimePipeline {
    return factory([DocumentsSource(docs: docs, db: db)], db)
  }

  public func documents(_ paths: [String]) -> RealtimePipeline {
    let docs = paths.map { db.document($0) }
    return factory([DocumentsSource(docs: docs, db: db)], db)
  }

  /// Creates a `RealtimePipeline` from an existing `Query`.
  ///
  /// This allows you to convert a standard Firestore query into a pipeline, which can then be
  /// further modified with additional pipeline stages.
  ///
  /// - Parameter query: The `Query` to convert into a pipeline.
  /// - Returns: A `RealtimePipeline` that is equivalent to the given query.
  public func create(from query: Query) -> RealtimePipeline {
    let stageBridges = PipelineBridge.createStageBridges(from: query)
    let stages: [Stage] = stageBridges.map { bridge in
      switch bridge.name {
      case "collection":
        return CollectionSource(
          bridge: bridge as! CollectionSourceStageBridge,
          db: query.firestore
        )
      case "collection_group":
        return CollectionGroupSource(bridge: bridge as! CollectionGroupSourceStageBridge)
      case "documents":
        return DocumentsSource(bridge: bridge as! DocumentsSourceStageBridge, db: query.firestore)
      case "where":
        return Where(bridge: bridge as! WhereStageBridge)
      case "limit":
        return Limit(bridge: bridge as! LimitStageBridge)
      case "sort":
        return Sort(bridge: bridge as! SortStageBridge)
      case "offset":
        return Offset(bridge: bridge as! OffsetStageBridge)
      default:
        fatalError("Unknown stage type \(bridge.name)")
      }
    }
    return factory(stages, db)
  }
}
