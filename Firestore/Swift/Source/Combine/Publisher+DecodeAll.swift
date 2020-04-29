/*
 * Copyright 2020 Google LLC
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

#if canImport(Combine)
  import Combine
  import Foundation

  import FirebaseFirestore

  @available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
  extension Publisher {
    // TODO: Likely turn this into a custom publisher and publish a `FirestoreDecodingError` as the
    // error type.
    /// Decodes an array of `DocumentSnapshots` into an array of objects or values of type `T`.
    public func decodeAll<T, D: DocumentSnapshot>(as type: T.Type,
                                                  decoder: Firestore
                                                    .Decoder = .init()) -> AnyPublisher<[T], Error>
      where T: Decodable, Output == [D] {
      // Use the `tryMap` publisher to map the current array of snapshots to the array of type T.
      return tryMap { snapshots in
        // For each snapshot, we want to try mapping the data inside.
        try snapshots.compactMap { snapshot in
          try snapshot.data(as: type, decoder: decoder)
        }
      }
      // Erase to AnyPublisher for now, but evaluate switching to a proper publishing type.
      .eraseToAnyPublisher()
    }
  }

#endif
