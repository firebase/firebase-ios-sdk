// Copyright 2022 Google LLC
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

import Foundation

/// A Task that lists the entries under a StorageReference
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
enum StorageListTask {
  static func listTask(reference: StorageReference,
                       queue: DispatchQueue,
                       pageSize: Int64?,
                       previousPageToken: String?,
                       completion: ((_: StorageListResult?, _: Error?) -> Void)?) {
    var queryParams = [String: String]()

    let prefix = reference.fullPath
    if prefix.count > 0 {
      queryParams["prefix"] = "\(prefix)/"
    }

    // Firebase Storage uses file system semantics and treats slashes as separators. GCS's List
    // API
    // does not prescribe a separator, and hence we need to provide a slash as the delimiter.
    queryParams["delimiter"] = "/"

    // listAll() doesn't set a pageSize as this allows Firebase Storage to determine how many
    // items
    // to return per page. This removes the need to backfill results if Firebase Storage filters
    // objects that are considered invalid (such as items with two consecutive slashes).
    if let pageSize {
      queryParams["maxResults"] = "\(pageSize)"
    }

    if let previousPageToken {
      queryParams["pageToken"] = previousPageToken
    }

    let root = reference.root()
    let request = StorageUtils.defaultRequestForReference(
      reference: root,
      queryParams: queryParams
    )

    StorageInternalTask(reference: reference,
                        queue: queue,
                        request: request,
                        httpMethod: "GET",
                        fetcherComment: "ListTask") { (data: Data?, error: Error?) in
      if let error {
        completion?(nil, error)
      } else {
        if let data,
           let responseDictionary = try? JSONSerialization
           .jsonObject(with: data) as? [String: AnyHashable] {
          let listResult = StorageListResult(with: responseDictionary, reference: reference)
          completion?(listResult, nil)
        } else {
          completion?(nil, StorageErrorCode.error(withInvalidRequest: data))
        }
      }
    }
  }
}
