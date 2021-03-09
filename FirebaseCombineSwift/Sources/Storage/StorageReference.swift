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

#if canImport(Combine) && swift(>=5.0) && canImport(FirebaseFunctions)

  import Combine
import FirebaseStorage

@available(swift 5.0)
  @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
extension StorageReference {
    // MARK: - Uploads
    
    /// Asynchronously uploads data to the currently specified FIRStorageReference.
    /// This is not recommended for large files, and one should instead upload a file from disk.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameters:
    ///   - uploadData: The Data to upload.
    ///   - UIDelegate: metadata FIRStorageMetadata containing additional information (MIME type, etc.)
    ///
    /// - Returns: A publisher emitting a `StorageMetadata` instance. The publisher will emit on the *main* thread.
    @discardableResult
    public func putDataPublisher(_ data: Data, metadata: StorageMetadata?) -> AnyPublisher<StorageMetadata, Error> {
        let subject = PassthroughSubject<StorageMetadata, Error>()
        let task = putData(data, metadata: metadata) { metadata, error in
            if let metadata = metadata {
                subject.send(metadata)
                subject.send(completion: .finished)
            } else if let error = error {
                subject.send(completion: .failure(error))
            }
        }
        
        return subject.handleEvents(receiveCancel: {
            task.cancel()
        }).eraseToAnyPublisher()
    }
    
    /// Asynchronously uploads a file to the currently specified `StorageReference`.
    ///
    /// The publisher will emit events on the **main** thread.
    ///
    /// - Parameters:
    ///   - fileURL: A `URL` representing the system file path of the object to be uploaded.
    ///   - metadata: `StorageMetadata` containing additional information (MIME type, etc.) about the object being uploaded.
    ///
    /// - Returns: A publisher emitting a `StorageMetadata` instance. The publisher will emit on the *main* thread.
    @discardableResult
    public func putFilePublisher(from fileURL: URL, metadata: StorageMetadata?) -> AnyPublisher<StorageMetadata, Error> {
        let subject = PassthroughSubject<StorageMetadata, Error>()
        let task = putFile(from: fileURL, metadata: metadata) { metadata, error in
            if let metadata = metadata {
                subject.send(metadata)
                subject.send(completion: .finished)
            } else if let error = error {
                subject.send(completion: .failure(error))
            }
        }
        
        return subject.handleEvents(receiveCancel: {
            task.cancel()
        }).eraseToAnyPublisher()
    }
}
#endif
