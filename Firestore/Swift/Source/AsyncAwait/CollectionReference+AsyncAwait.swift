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

import FirebaseFirestore
import Foundation

#if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    public extension CollectionReference {
        /**
         * Adds a new document to this collection with the specified data, assigning it a document ID automatically.
         * @param data A `Dictionary` containing the data for the new document.
         * @return A `DocumentReference` pointing to the newly created document.
         */
        func addDocument(data: [String: Any]) async throws -> DocumentReference {
            typealias DataContinuation = CheckedContinuation<DocumentReference, Error>
            return try await withCheckedThrowingContinuation { (continuation: DataContinuation) in
                var document: DocumentReference?
                document = self.addDocument(data: data, completion: { error in
                    if let err = error {
                        continuation.resume(throwing: err)
                    } else {
                        continuation.resume(returning: document!)
                    }
                })
            }
        }
    }
#endif
