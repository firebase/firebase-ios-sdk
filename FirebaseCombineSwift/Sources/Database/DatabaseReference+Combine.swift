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
    // MARK: - Setting values on a DatabaseReference

    /**

         Encode an `Encodable` instance and write it to this Firebase Database location.

         See `Database.Encoder` for more details about the encoding process.

         This will overwrite any data at this location and all child locations.

         The effect of the write will be visible immediately and the corresponding
         events will be triggered. Synchronization of the data to the Firebase Database
         servers will also be started.

         - Parameters:
           - encodable: An instance of `Encodable` to be encoded to a document.
           - encoder: An encoder instance to use to run the encoding.
         - Returns: A `Future` that emits the result of encoding/writing the value. Note: The `Future` will not complete while the client is offline, though local changes will be visible immediately.
     */
    func setValue<T: Encodable>(from encodable: T,
                                encoder: Database.Encoder = Database.Encoder()) -> Future<
      Void,
      Error
    > {
      Future<Void, Error> { promise in
        do {
          try self.setValue(from: encodable, encoder: encoder, completion: { error in
            if let error = error {
              promise(.failure(error))
            } else {
              promise(.success(()))
            }
          })
        } catch {
          // NOTE: This is only correct since we know that if `try setValue` fails
          // then the completion is not called.
          promise(.failure(error))
        }
      }
    }

    /**
     This is equivalent to `observeSingleEvent(of eventType:, with block:)`, except
     it returns a `Future` of the caller-specified type instead of taking a completion block as it's parameter.

     The snapshot value is converted to an instance of
     the caller-specified type.

     The `Future` fails with `DecodingError.valueNotFound`
     if the document does not exist and `T` is not an `Optional`.

     See `Database.Decoder` for more details about the decoding process.

     - Parameters:
       - eventType: The type of event to listen for.
       - type: The type to decode the data to.
       - decoder: The decoder to use to convert the document. Defaults to use `Database.Decoder()`.
     - Returns: A `Future` that emits the result of decoding the data to the specified type.
     */
    func observeSingleEvent<T: Decodable>(of eventType: DataEventType,
                                          as type: T.Type,
                                          decoder: Database.Decoder = Database
                                            .Decoder()) -> Future<T, Error> {
      Future<T, Error> { promise in
        self.observeSingleEvent(of: eventType) { snapshot in
          do {
            let t = try snapshot.data(as: T.self, decoder: decoder)
            promise(.success(t))
          } catch {
            promise(.failure(error))
          }
        }
      }
    }

    /**
     This is equivalent to `observe(eventType:, with block:)`, except
     it returns an `AnyPublisher` of the caller-specified type instead of taking a completion block as it's parameter.

     The snapshot value is converted to an instance of
     the caller-specified type.

     The `AnyPublisher` fails with `DecodingError.valueNotFound`
     if the document does not exist and `T` is not an `Optional`.

     See `Database.Decoder` for more details about the decoding process.

     - Parameters:
       - eventType: The type of event to listen for.
       - type: The type to decode the data to.
       - decoder: The decoder to use to convert the document. Defaults to use `Database.Decoder()`.
     - Returns: An `AnyPublisher` that emits the result of decoding the data to the specified type.
     */
    func observe<T: Decodable>(_ eventType: DataEventType,
                               as type: T.Type,
                               decoder: Database.Decoder = Database
                                 .Decoder()) -> AnyPublisher<T, Error> {
      let subject = PassthroughSubject<T, Error>()
      let handle = observe(eventType) { snapshot in
        do {
          let t = try snapshot.data(as: T.self, decoder: decoder)
          subject.send(t)
        } catch {
          subject.send(completion: .failure(error))
        }
      }
      return subject
        .handleEvents(receiveCancel: {
          self.removeObserver(withHandle: handle)
        })
        .eraseToAnyPublisher()
    }

    /**
     Note: This is a convenience overload of the `observe` method taking the same parameters.

     This is equivalent to `observe(eventType:, with block:)`, except
     it returns an `AnyPublisher` of the caller-specified type instead of taking a completion block as it's parameter.

     The snapshot value is converted to an instance of
     the caller-specified type.

     The `AnyPublisher` fails with `DecodingError.valueNotFound`
     if the document does not exist and `T` is not an `Optional`.

     See `Database.Decoder` for more details about the decoding process.

     - Parameters:
       - eventType: The type of event to listen for.
       - type: The type to decode the data to.
       - decoder: The decoder to use to convert the document. Defaults to use `Database.Decoder()`.
     - Returns: An `AnyPublisher` that emits the result of decoding the data to the specified type.
     */
    func valuePublisher<T: Decodable>(_ eventType: DataEventType,
                                      as type: T.Type,
                                      decoder: Database.Decoder = Database
                                        .Decoder()) -> AnyPublisher<T, Error> {
      return observe(eventType, as: type, decoder: decoder)
    }

    /**
     This is equivalent to `observe(eventType:, with block:)`, except
     it returns an `AnyPublisher<DataSnapshot, Never>` instead of taking a completion block as it's parameter.

     - Parameters:
       - eventType: The type of event to listen for.
     - Returns: An `AnyPublisher` that emits `DataSnapshot` values.
     */
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
