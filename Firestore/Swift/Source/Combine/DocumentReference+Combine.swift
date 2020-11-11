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
  extension DocumentReference {
    func setDataPublisher(_ documentData: [String: Any]) -> Future<Void, Error> {
      Future { self.setData(documentData, completion: $0) }
    }

    func setDataPublisher(_ documentData: [String: Any], merge: Bool) -> Future<Void, Error> {
      Future { self.setData(documentData, merge: merge, completion: $0) }
    }

    func setDataPublisher(_ documentData: [String: Any],
                          mergeFields: [Any]) -> Future<Void, Error> {
      Future { self.setData(documentData, mergeFields: mergeFields, completion: $0) }
    }

    func setDataPublisher<T: Encodable>(from value: T,
                                        encoder: Firestore.Encoder = Firestore.Encoder()) -> Future<
      Void,
      Error
    > {
      Future { promise in
        do {
          try self.setData(from: value, completion: promise)
        } catch {
          promise(.failure(error))
        }
      }
    }

    func setDataPublisher<T: Encodable>(from value: T, merge: Bool,
                                        encoder: Firestore.Encoder = Firestore.Encoder()) -> Future<
      Void,
      Error
    > {
      Future { promise in
        do {
          try self.setData(from: value, merge: merge, completion: promise)
        } catch {
          promise(.failure(error))
        }
      }
    }

    func setDataPublisher<T: Encodable>(from value: T, mergeFields: [Any],
                                        encoder: Firestore.Encoder = Firestore.Encoder()) -> Future<
      Void,
      Error
    > {
      Future { promise in
        do {
          try self.setData(from: value, mergeFields: mergeFields, completion: promise)
        } catch {
          promise(.failure(error))
        }
      }
    }

    func updateDataPublisher(_ documentData: [String: Any]) -> Future<Void, Error> {
      Future { self.updateData(documentData, completion: $0) }
    }

    func deletePublisher() -> Future<Void, Error> {
      Future(delete)
    }

    func getDocumentPublisher(source: FirestoreSource = .default)
      -> Future<DocumentSnapshot, Error> {
      Future { self.getDocument(source: source, completion: $0) }
    }

    func addSnapshotListenerPublisher(includeMetadataChanges: Bool = false)
      -> AnyPublisher<DocumentSnapshot, Error> {
      let subject = PassthroughSubject<DocumentSnapshot, Error>()
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
