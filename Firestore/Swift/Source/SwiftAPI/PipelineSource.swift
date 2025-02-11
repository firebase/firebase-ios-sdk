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

#if SWIFT_PACKAGE
  import FirebaseFirestoreCpp
#endif
import Foundation

public protocol PipelineType {}

public struct RealtimePipeline: PipelineType {
  let cppObj: firebase.firestore.api.Pipeline

  init(_ cppSource: firebase.firestore.api.Pipeline) {
    cppObj = cppSource
  }
}

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public struct PipelineSource<T: PipelineType> {
  let cppObj: firebase.firestore.api.PipelineSource

  init(_ cppSource: firebase.firestore.api.PipelineSource) {
    cppObj = cppSource
  }

  public func collection(_ path: String) -> T {
    if T.self == Pipeline.self {
      return Pipeline(cppObj.GetCollection(std.string(path))) as! T
    } else {
      return RealtimePipeline(cppObj.GetCollection(std.string(path))) as! T
    }
  }

  public func collectionGroup(_ collectionId: String) -> T {
    if T.self == Pipeline.self {
      return Pipeline(cppObj.GetCollectionGroup(std.string(collectionId))) as! T
    } else {
      return RealtimePipeline(cppObj.GetCollectionGroup(std.string(collectionId))) as! T
    }
  }

  public func database() -> T {
    if T.self == Pipeline.self {
      return Pipeline(cppObj.GetDatabase()) as! T
    } else {
      return RealtimePipeline(cppObj.GetDatabase()) as! T
    }
  }

  public func documents<documentReference: DocumentReference>(_ docs: [documentReference]) -> T {
    if T.self == Pipeline.self {
      return Pipeline(cppObj.GetDatabase()) as! T // PLACEHOLDER
    } else {
      return RealtimePipeline(cppObj.GetDatabase()) as! T // PLACEHOLDER
    }
  }

  public func createFrom(_ query: Query) -> T {
    if T.self == Pipeline.self {
      return Pipeline(cppObj.GetDatabase()) as! T // PLACEHOLDER
    } else {
      return RealtimePipeline(cppObj.GetDatabase()) as! T // PLACEHOLDER
    }
  }

  public func createFrom(_ aggregateQuery: AggregateQuery) -> T {
    if T.self == Pipeline.self {
      return Pipeline(cppObj.GetDatabase()) as! T // PLACEHOLDER
    } else {
      return RealtimePipeline(cppObj.GetDatabase()) as! T // PLACEHOLDER
    }
  }
}
