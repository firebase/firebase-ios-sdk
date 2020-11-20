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
  extension DatabaseReference {
    // MARK: - Setting values on a `DatabaseReference`

    /// Encodes an `Encodable` value and, on success, writes the encoded value to the database.
    /// - Parameters:
    ///   - value: An instance of `Encodable` to be encoded to a document.
    ///   - encoder: An encoder instance to use to run the encoding.
    /// - Returns: A Future that emits the result of encoding/writing the value.
    public func setValue<T: Encodable>(from encodable: T, encoder: Database.Encoder = Database.Encoder.defaultEncoder()) -> Future<Void, Error> {
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
  }

#endif
