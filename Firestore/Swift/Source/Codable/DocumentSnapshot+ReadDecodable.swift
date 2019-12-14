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

import Foundation
import FirebaseFirestore

extension DocumentSnapshot {
  /// Retrieves all fields in a document and converts them to an instance of
  /// caller-specified type. Returns `nil` if the document does not exist.
  ///
  /// See `Firestore.Decoder` for more details about the decoding process.
  ///
  /// - Parameters
  ///   - type: The type to convert the document fields to.
  ///   - decoder: The decoder to use to convert the document. `nil` to use
  ///              default decoder.
  public func data<T: Decodable>(as type: T.Type,
                                 decoder: Firestore.Decoder? = nil) throws -> T? {
    var d = decoder
    if d == nil {
      d = Firestore.Decoder()
    }
    if let data = data() {
      return try d?.decode(T.self, from: data, in: reference)
    }
    return nil
  }
}
