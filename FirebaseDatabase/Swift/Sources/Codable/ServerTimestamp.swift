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

#if SWIFT_PACKAGE
  @_exported import FirebaseDatabaseInternal
#endif // SWIFT_PACKAGE

/// A property wrapper that marks an `Optional<Date>` field to be
/// populated with a server timestamp. If a `Codable` object being written
/// contains a `nil` for an `@ServerTimestamp`-annotated field, it will be
/// replaced with `ServerValue.timestamp()` as it is sent.
///
/// Example:
/// ```
/// struct CustomModel {
///   @ServerTimestamp var ts: Date?
/// }
/// ```
///
/// Then writing `CustomModel(ts: nil)` will tell server to fill `ts` with
/// current timestamp.
@propertyWrapper
public struct ServerTimestamp: Codable, Equatable, Hashable {
  var value: Date?

  public init(wrappedValue value: Date?) {
    self.value = value
  }

  public var wrappedValue: Date? {
    get { value }
    set { value = newValue }
  }

  // MARK: Codable

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      value = nil
    } else {
      let msecs = try container.decode(Int.self)
      value = Date(timeIntervalSince1970: TimeInterval(msecs) / 1000)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    if let value = value {
      let interval = value.timeIntervalSince1970
      try container.encode(Int(interval * 1000))
    } else {
      let dictionary = ServerValue.timestamp() as! [String: String]
      try container.encode(dictionary)
    }
  }
}
