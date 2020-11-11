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

  extension Query {
    func getDocumentsPublisher(source: FirestoreSource = .default) -> Future<QuerySnapshot, Error> {
      Future { self.getDocuments(source: source, completion: $0) }
    }

    func addSnapshotListenerPublisher(includeMetadataChanges: Bool = false)
      -> AnyPublisher<QuerySnapshot, Error> {
      let subject = PassthroughSubject<QuerySnapshot, Error>()
      let listenerHandle = addSnapshotListener { result in
        switch result {
        case let .success(output):
          subject.send(output)
        case let .failure(error):
          subject.send(completion: .failure(error))
        }
      }
      return subject
        .handleEvents(receiveCancel: listenerHandle.remove)
        .eraseToAnyPublisher()
    }
  }

#endif
