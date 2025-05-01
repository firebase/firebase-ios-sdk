/*
 * Copyright 2025 Google
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
 * A protocol describing the encodable properties of a RegexValue.
 *
 * Note: this protocol exists as a workaround for the Swift compiler: if the RegexValue class
 * was extended directly to conform to Codable, the methods implementing the protocol would be need
 * to be marked required but that can't be done in an extension. Declaring the extension on the
 * protocol sidesteps this issue.
 */
private protocol CodableRegexValue: Codable {
  var pattern: String { get }
  var options: String { get }

  init(pattern: String, options: String)
}

/** The keys in a RegexValue. Must match the properties of CodableRegexValue. */
private enum RegexValueKeys: String, CodingKey {
  case pattern
  case options
}

/**
 * An extension of RegexValue that implements the behavior of the Codable protocol.
 *
 * Note: this is implemented manually here because the Swift compiler can't synthesize these methods
 * when declaring an extension to conform to Codable.
 */
extension CodableRegexValue {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: RegexValueKeys.self)
    let pattern = try container.decode(String.self, forKey: .pattern)
    let options = try container.decode(String.self, forKey: .options)
    self.init(pattern: pattern, options: options)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: RegexValueKeys.self)
    try container.encode(pattern, forKey: .pattern)
    try container.encode(options, forKey: .options)
  }
}

/** Extends RegexValue to conform to Codable. */
extension FirebaseFirestore.RegexValue: FirebaseFirestore.CodableRegexValue {}
