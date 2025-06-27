/*
 * Copyright 2025 Google LLC
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

#if SWIFT_PACKAGE
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE

/**
 * A protocol describing the encodable properties of a MaxKey.
 *
 * Note: this protocol exists as a workaround for the Swift compiler: if the MaxKey class
 * was extended directly to conform to Codable, the methods implementing the protocol would be need
 * to be marked required but that can't be done in an extension. Declaring the extension on the
 * protocol sidesteps this issue.
 */
private protocol CodableMaxKey: Codable {
  init()
}

/** The keys in a MaxKey. */
private enum MaxKeyKeys: String, CodingKey {
  // We'll use a simple CodingKeys enum with a single case
  // to represent the presence of the singleton.
  case isFirestoreMaxKey
}

/**
 * An extension of MaxKey that implements the behavior of the Codable protocol.
 *
 * Note: this is implemented manually here because the Swift compiler can't synthesize these methods
 * when declaring an extension to conform to Codable.
 */
extension CodableMaxKey {
  public init(from decoder: Decoder) throws {
    // The presence of the `isFirestoreMaxKey` is enough to know that we
    // should return the singleton.
    let container = try decoder.container(keyedBy: MaxKeyKeys.self)
    _ = try container.decodeIfPresent(Bool.self, forKey: .isFirestoreMaxKey)
    self.init()
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: MaxKeyKeys.self)
    // Encode a value of `true` to indicate the presence of MaxKey
    try container.encode(true, forKey: .isFirestoreMaxKey)
  }
}

/** Extends RegexValue to conform to Codable. */
extension FirebaseFirestore.MaxKey: FirebaseFirestore.CodableMaxKey {}
