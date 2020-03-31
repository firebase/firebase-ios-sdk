// Copyright 2020 Google LLC
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

import FirebaseStorage

/// getResultCallback generates a closure that returns a Result type from a closure that returns an
/// optional type and Error.
private func getResultCallback<T>(
  completion: @escaping (Result<T, Error>) -> Void
) -> (_: T?, _: Error?) -> Void {
  return { (metadata: T?, error: Error?) -> Void in
    guard let metadata = metadata else {
      guard let error = error else {
        completion(.failure(NSError(domain: "FirebaseStorageSwift",
                                    code: -1,
                                    userInfo: ["Storage Result Generator":
                                      "InternalError - Return type and Error code both nil"])))
        return
      }
      completion(.failure(error))
      return
    }
    completion(.success(metadata))
  }
}

public extension StorageReference {
  func downloadURL(completion: @escaping (Result<URL, Error>) -> Void) {
    downloadURL(completion: getResultCallback(completion: completion))
  }

  func getData(maxSize: Int64, completion: @escaping (Result<Data, Error>) -> Void)
    -> StorageDownloadTask {
    return getData(maxSize: maxSize, completion: getResultCallback(completion: completion))
  }

  func getMetadata(completion: @escaping (Result<StorageMetadata, Error>) -> Void) {
    getMetadata(completion: getResultCallback(completion: completion))
  }

  func list(withMaxResults maxResults: Int64,
            pageToken: String,
            completion: @escaping (Result<StorageListResult, Error>) -> Void) {
    list(withMaxResults: maxResults,
         pageToken: pageToken,
         completion: getResultCallback(completion: completion))
  }

  func list(withMaxResults maxResults: Int64,
            completion: @escaping (Result<StorageListResult, Error>) -> Void) {
    list(withMaxResults: maxResults,
         completion: getResultCallback(completion: completion))
  }

  func listAll(completion: @escaping (Result<StorageListResult, Error>) -> Void) {
    listAll(completion: getResultCallback(completion: completion))
  }

  func putData(_ uploadData: Data,
               metadata: StorageMetadata?,
               completion: @escaping (Result<StorageMetadata, Error>) -> Void)
    -> StorageUploadTask {
    return putData(uploadData,
                   metadata: metadata,
                   completion: getResultCallback(completion: completion))
  }

  func putData(_ uploadData: Data,
               completion: @escaping (Result<StorageMetadata, Error>) -> Void)
    -> StorageUploadTask {
    return putData(uploadData,
                   metadata: nil,
                   completion: getResultCallback(completion: completion))
  }

  func putFile(from: URL,
               metadata: StorageMetadata?,
               completion: @escaping (Result<StorageMetadata, Error>) -> Void)
    -> StorageUploadTask {
    return putFile(from: from,
                   metadata: metadata,
                   completion: getResultCallback(completion: completion))
  }

  func putFile(from: URL,
               completion: @escaping (Result<StorageMetadata, Error>) -> Void)
    -> StorageUploadTask {
    return putFile(from: from,
                   metadata: nil,
                   completion: getResultCallback(completion: completion))
  }

  func updateMetadata(_ metadata: StorageMetadata,
                      completion: @escaping (Result<StorageMetadata, Error>) -> Void) {
    return updateMetadata(metadata, completion: getResultCallback(completion: completion))
  }

  func write(toFile: URL, completion: @escaping (Result<URL, Error>)
    -> Void) -> StorageDownloadTask {
    return write(toFile: toFile, completion: getResultCallback(completion: completion))
  }
}
