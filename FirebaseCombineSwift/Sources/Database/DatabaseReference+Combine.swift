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

#if canImport(Combine) && swift(>=5.0) && canImport(FirebaseDatabase)

  import Combine
  import FirebaseDatabase
  import FirebaseDatabaseSwift

  @available(swift 5.0)
  @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
  public extension DatabaseReference {
    // MARK: - Setting values on a `DatabaseReference`

    /// Encodes an `Encodable` value and, on success, writes the encoded value to the database.
    /// - Parameters:
    ///   - value: An instance of `Encodable` to be encoded to a document.
    ///   - encoder: An encoder instance to use to run the encoding.
    /// - Returns: A Future that emits the result of encoding/writing the value.
    func setValue<T: Encodable>(from encodable: T, encoder: Database.Encoder = Database.Encoder()) -> Future<Void, Error> {
      Future<Void, Error> { promise in
        do {
          try self.setValue(from: encodable, encoder: encoder, completion: promise)
        } catch {
          // NOTE: This is only correct since we know that if `try setValue` fails
          // then the completion is not called.
          // Would it be better/clearer to 'spell out' the setValue and basically
          // copy what is in DatabaseReference+Decodable in order to make it clear
          // that the `try` is connected to the encoding and not the setting of the
          // value?
          promise(.failure(error))
        }
      }
    }

    func observeSingleEvent<T: Decodable>(of eventType: DataEventType,
                                                 as type: T.Type,
                                                 decoder: Database.Decoder = Database.Decoder()) -> Future<T, Error> {
      Future<T, Error> { promise in
        self.observeSingleEvent(of: eventType) { snapshot in
          do {
            let t = try snapshot.data(as: T.self, decoder: decoder)
            promise(.success(t))
          }
          catch {
            promise(.failure(error))
          }
        }
      }
    }

    // NOTE: Should this perhaps be named XXXPublisher(...)?
    // If so, what should it be? 'modelPublisher', 'decodedPublisher'?
    // Should this be built upon the snapshotPublisher, or is it an ok
    // performance improvement to create this 'directly'?
    func observe<T: Decodable>(_ eventType: DataEventType,
                                      as type: T.Type,
                                      decoder: Database.Decoder = Database.Decoder()) -> AnyPublisher<T, Error> {
      let subject = PassthroughSubject<T, Error>()
      let handle = observe(eventType) { snapshot in
        do {
          let t = try snapshot.data(as: T.self, decoder: decoder)
          subject.send(t)
        }
        catch {
          subject.send(completion: .failure(error))
        }
      }
      return subject
        .handleEvents(receiveCancel: {
          self.removeObserver(withHandle: handle)
        })
        .eraseToAnyPublisher()
    }

    func snapshotPublisher(_ eventType: DataEventType) -> AnyPublisher<DataSnapshot, Never> {
      let subject = PassthroughSubject<DataSnapshot, Never>()
      let handle = observe(eventType) { snapshot in
          subject.send(snapshot)
      }
      return subject
        .handleEvents(receiveCancel: {
          self.removeObserver(withHandle: handle)
        })
        .eraseToAnyPublisher()
    }
  }

#endif
