/*
 * Copyright 2019 Google LLC
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
  @_exported public import FirebaseFirestoreInternalWrapper
#else
  @_exported public import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE

public extension DocumentSnapshot {
  /// Retrieves all fields in a document and converts them to an instance of
  /// caller-specified type.
  ///
  /// By default, server-provided timestamps that have not yet been set to their
  /// final value will be returned as `NSNull`. Pass `serverTimestampBehavior`
  /// to configure this behavior.
  ///
  /// See `Firestore.Decoder` for more details about the decoding process.
  ///
  /// - Parameters
  ///   - type: The type to convert the document fields to.
  ///   - serverTimestampBehavior: Configures how server timestamps that have
  ///     not yet been set to their final value are returned from the snapshot.
  ///   - decoder: The decoder to use to convert the document. Defaults to use
  ///     the default decoder.
  func data<T: Decodable>(as type: T.Type,
                          with serverTimestampBehavior: ServerTimestampBehavior = .none,
                          decoder: Firestore.Decoder = .init()) throws -> T {
    let d: Any = data(with: serverTimestampBehavior) ?? NSNull()
    return try decoder.decode(T.self, from: d, in: reference)
  }
}
