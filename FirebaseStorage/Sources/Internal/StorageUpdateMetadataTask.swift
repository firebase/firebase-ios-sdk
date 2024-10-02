/// Copyright 2022 Google LLC
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
enum StorageUpdateMetadataTask {
  static func updateMetadataTask(reference: StorageReference,
                                 queue: DispatchQueue,
                                 metadata: StorageMetadata,
                                 completion: ((_: StorageMetadata?, _: Error?) -> Void)?) {
    var request = StorageUtils.defaultRequestForReference(reference: reference)
    let updateData = try? JSONSerialization.data(withJSONObject: metadata.updatedMetadata())
    request.httpBody = updateData
    request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
    if let count = updateData?.count {
      request.setValue("\(count)", forHTTPHeaderField: "Content-Length")
    }

    StorageInternalTask(reference: reference,
                        queue: queue,
                        request: request,
                        httpMethod: "PATCH",
                        fetcherComment: "GetMetadataTask") { (data: Data?, error: Error?) in
      if let error {
        completion?(nil, error)
      } else {
        if let data,
           let responseDictionary = try? JSONSerialization
           .jsonObject(with: data) as? [String: AnyHashable] {
          let metadata = StorageMetadata(dictionary: responseDictionary)
          metadata.fileType = .file
          completion?(metadata, nil)
        } else {
          completion?(nil, StorageErrorCode.error(withInvalidRequest: data))
        }
      }
    }
  }
}
