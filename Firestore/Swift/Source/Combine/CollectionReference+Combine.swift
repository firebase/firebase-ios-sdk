/*
 * Copyright 2019 Google
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

#if canImport(Combine) && swift(>=5.0)

  import Combine
  import FirebaseFirestore

  @available(swift 5.0)
  @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
  extension CollectionReference {
    public func addDocumentPublisher(data: [String: Any])
      -> AnyPublisher<DocumentReference, Error> {
      var reference: DocumentReference!
      return Future { reference = self.addDocument(data: data, completion: $0) }
        .map { reference }
        .eraseToAnyPublisher()
    }

    public func addDocumentPublisher<T: Encodable>(from value: T,
                                                   encoder: Firestore.Encoder = Firestore
                                                     .Encoder()) -> AnyPublisher<
      DocumentReference,
      Error
    > {
      var reference: DocumentReference!
      return Future { promise in
        do {
          try reference = self.addDocument(from: value, encoder: encoder, completion: promise)
        } catch {
          promise(.failure(error))
        }
      }
      .map { reference }
      .eraseToAnyPublisher()
    }
  }

#endif
