/*
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#if SWIFT_PACKAGE
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE
import Foundation

#if compiler(>=5.5.2) && canImport(_Concurrency)
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public extension CollectionReference {
    /// Adds a new document to this collection with the specified data, assigning it a document ID
    /// automatically.
    /// - Parameter data: A `Dictionary` containing the data for the new document.
    /// - Throws: `Error` if the backend rejected the write.
    /// - Returns: A `DocumentReference` pointing to the newly created document.
    @discardableResult
    func addDocument(data: [String: Any]) async throws -> DocumentReference {
      return try await withCheckedThrowingContinuation { continuation in
        var document: DocumentReference?
        document = self.addDocument(data: data) { error in
          if let err = error {
            continuation.resume(throwing: err)
          } else {
            // Our callbacks guarantee that we either return an error or a document.
            continuation.resume(returning: document!)
          }
        }
      }
    }
  }
#endif
