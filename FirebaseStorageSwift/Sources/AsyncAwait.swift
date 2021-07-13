// Copyright 2021 Google LLC
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

#if swift(>=5.5)
  @available(iOS 15, *)
  public extension StorageReference {
    func data(maxSize: Int64) async throws -> Data {
      typealias DataContinuation = CheckedContinuation<Data, Error>
      return try await withCheckedThrowingContinuation { (continuation: DataContinuation) in
        // TODO: Use task to handle progress and cancellation.
        _ = self.getData(maxSize: maxSize) { result in
          continuation.resume(with: result)
        }
      }
    }

    func putDataAsync(_ uploadData: Data,
                      metadata: StorageMetadata? = nil) async throws -> StorageMetadata {
      typealias MetadataContinuation = CheckedContinuation<StorageMetadata, Error>
      return try await withCheckedThrowingContinuation { (continuation: MetadataContinuation) in
        // TODO: Use task to handle progress and cancellation.
        _ = self.putData(uploadData, metadata: metadata) { result in
          continuation.resume(with: result)
        }
      }
    }

    func putFileAsync(from url: URL,
                      metadata: StorageMetadata? = nil) async throws -> StorageMetadata {
      typealias MetadataContinuation = CheckedContinuation<StorageMetadata, Error>
      return try await withCheckedThrowingContinuation { (continuation: MetadataContinuation) in
        // TODO: Use task to handle progress and cancellation.
        _ = self.putFile(from: url, metadata: metadata) { result in
          continuation.resume(with: result)
        }
      }
    }

    func writeAsync(toFile fileURL: URL) async throws -> URL {
      typealias URLContinuation = CheckedContinuation<URL, Error>
      return try await withCheckedThrowingContinuation { (continuation: URLContinuation) in
        // TODO: Use task to handle progress and cancellation.
        _ = self.write(toFile: fileURL) { result in
          continuation.resume(with: result)
        }
      }
    }
  }
#endif
