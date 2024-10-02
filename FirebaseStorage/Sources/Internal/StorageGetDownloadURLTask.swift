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

/// Task which provides the ability to get a download URL for an object in Firebase Storage.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
enum StorageGetDownloadURLTask {
  static func getDownloadURLTask(reference: StorageReference,
                                 queue: DispatchQueue,
                                 completion: ((_: URL?, _: Error?) -> Void)?) {
    StorageInternalTask(reference: reference,
                        queue: queue,
                        httpMethod: "GET",
                        fetcherComment: "GetDownloadURLTask") { (data: Data?, error: Error?) in
      if let error {
        completion?(nil, error)
      } else {
        if let data,
           let responseDictionary = try? JSONSerialization
           .jsonObject(with: data) as? [String: Any] {
          guard let downloadURL = downloadURLFromMetadataDictionary(responseDictionary,
                                                                    reference) else {
            let error = StorageError.unknown(
              message: "Failed to retrieve a download URL.",
              serverError: [:]
            ) as NSError
            completion?(nil, error)
            return
          }
          completion?(downloadURL, nil)
        } else {
          completion?(nil, StorageErrorCode.error(withInvalidRequest: data))
        }
      }
    }
  }

  static func downloadURLFromMetadataDictionary(_ dictionary: [String: Any],
                                                _ reference: StorageReference) -> URL? {
    let downloadTokens = dictionary["downloadTokens"]
    guard let downloadTokens = downloadTokens as? String,
          downloadTokens.count > 0 else {
      return nil
    }
    let downloadTokenArray = downloadTokens.components(separatedBy: ",")
    let bucket = dictionary["bucket"] ?? "<error: missing bucket>"
    let path = dictionary["name"] as? String ?? "<error: missing path name>"
    let fullPath = "/v0/b/\(bucket)/o/\(StorageUtils.GCSEscapedString(path))"
    var components = URLComponents()
    components.scheme = reference.storage.scheme
    components.host = reference.storage.host
    components.port = reference.storage.port
    components.percentEncodedPath = fullPath

    // The backend can return an arbitrary number of download tokens, but we only expose the first
    // token via the download URL.
    let altItem = URLQueryItem(name: "alt", value: "media")
    let tokenItem = URLQueryItem(name: "token", value: downloadTokenArray[0])
    components.queryItems = [altItem, tokenItem]
    return components.url
  }
}
