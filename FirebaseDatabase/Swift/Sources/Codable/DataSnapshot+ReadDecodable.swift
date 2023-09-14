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

import Foundation
#if SWIFT_PACKAGE
  @_exported import FirebaseDatabaseInternal
#endif // SWIFT_PACKAGE
import FirebaseSharedSwift

public extension DataSnapshot {
  /// Retrieves the value of a snapshot and converts it to an instance of
  /// caller-specified type.
  /// Throws `DecodingError.valueNotFound`
  /// if the document does not exist and `T` is not an `Optional`.
  ///
  /// See `Database.Decoder` for more details about the decoding process.
  ///
  /// - Parameters
  ///   - type: The type to convert the document fields to.
  ///   - decoder: The decoder to use to convert the document. Defaults to use
  ///              default decoder.
  func data<T: Decodable>(as type: T.Type,
                          decoder: Database.Decoder =
                            Database.Decoder()) throws -> T {
    try decoder.decode(T.self, from: value ?? NSNull())
  }
}
