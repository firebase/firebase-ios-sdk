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
#if canImport(Combine) && swift(>=5.0) && canImport(FirebaseFirestore)

import Combine
import FirebaseFirestore

#if canImport(FirebaseFirestoreSwift)

import FirebaseFirestoreSwift

#endif

@available(swift 5.0)
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
extension CollectionReference {

    // MARK: - Add Document

    /// Adds a new document to this collection with the specified data, assigning it a document ID
    /// automatically.
    /// - Parameter data: A `Dictionary` containing the data for the new document.
    /// - Returns: A publisher emitting a `Void` value once the document has been successfully
    /// written to the server. This publisher will not emit  while the client is offline, though
    /// local changes will be visible immediately.
    public func addDocument(data: [String: Any])
    -> AnyPublisher<DocumentReference, Error> {
        var reference: DocumentReference!
        return Future { promise in
            reference = self.addDocument(data: data) { error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }
        .map { reference }
        .eraseToAnyPublisher()
    }

    #if canImport(FirebaseFirestoreSwift)

    /// Adds a new document to this collection with the specified data, assigning it a document ID
    /// automatically.
    /// - Parameters:
    ///   - value: An instance of Encodable to be encoded to a document.
    ///   - encoder: An encoder instance to use to run the encoding.
    /// - Returns: A publisher emitting a `Void` value once the document has been successfully
    /// written to the server. This publisher will not emit  while the client is offline, though
    /// local changes will be visible immediately.
    public func addDocument<T: Encodable>(from value: T, encoder: Firestore.Encoder = Firestore.Encoder()) -> AnyPublisher<DocumentReference, Error> {
        var reference: DocumentReference!
        return Future { promise in
            do {
                try reference = self.addDocument(from: value, encoder: encoder) { error in
                    if let error = error {
                        promise(.failure(error))
                    } else {
                        promise(.success(()))
                    }
                }
            } catch {
                promise(.failure(error))
            }
        }
        .map { reference }
        .eraseToAnyPublisher()
    }

    #endif

}

#endif
