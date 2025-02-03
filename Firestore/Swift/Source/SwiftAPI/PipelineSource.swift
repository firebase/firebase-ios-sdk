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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public struct PipelineSource {
  let cppObj: firebase.firestore.api.PipelineSource

  public init(_ cppSource: firebase.firestore.api.PipelineSource) {
    cppObj = cppSource
  }

  public func collection(_ path: String) -> Pipeline {
    return Pipeline(cppObj.GetCollection(std.string(path)))
  }

  public func collectionGroup(_ collectionId: String) -> Pipeline {
    return Pipeline(cppObj
      .GetCollectionGroup(std.string(collectionId))) // Corrected: Use collectionId
  }

  public func database() -> Pipeline {
    return Pipeline(cppObj.GetDatabase())
  }

//  public func documents(_ docs: [DocumentReference]) -> Pipeline {
//        let cppDocs = docs.map { $0.toCppObj() }
//      return Pipeline(cppObj.GetDocuments(cppDocs))
//    return Pipeline(cppObj.GetDatabase()) // PLACEHOLDER
//  }
}
