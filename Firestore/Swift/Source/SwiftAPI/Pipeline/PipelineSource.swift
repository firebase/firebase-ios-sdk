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
public struct PipelineSource<P>: @unchecked Sendable {
  let db: Firestore
  let factory: ([Stage], Firestore) -> P

  init(db: Firestore, factory: @escaping ([Stage], Firestore) -> P) {
    self.db = db
    self.factory = factory
  }

  public func collection(_ path: String) -> P {
    let normalizedPath = path.hasPrefix("/") ? path : "/" + path
    return factory([CollectionSource(collection: normalizedPath)], db)
  }

  public func collectionGroup(_ collectionId: String) -> P {
    return factory(
      [CollectionGroupSource(collectionId: collectionId)],
      db
    )
  }

  public func database() -> P {
    return factory([DatabaseSource()], db)
  }

  public func documents(_ docs: [DocumentReference]) -> P {
    let paths = docs.map { $0.path.hasPrefix("/") ? $0.path : "/" + $0.path }
    return factory([DocumentsSource(paths: paths)], db)
  }

  public func documents(_ paths: [String]) -> P {
    let normalizedPaths = paths.map { $0.hasPrefix("/") ? $0 : "/" + $0 }
    return factory([DocumentsSource(paths: normalizedPaths)], db)
  }

  public func create(from query: Query) -> P {
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
