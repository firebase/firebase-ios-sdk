/*
 * Copyright 2026 Google LLC
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

// The `@Default` property wrapper: a missing config key decodes to its default, with synthesized
// `Codable` and no hand-written `init(from:)`.

/// Supplies the value a `@Default` property takes when its key is missing.
protocol DefaultValue {
  associatedtype Value: Codable, Equatable, Sendable
  static var defaultValue: Value { get }
}

/// A property that decodes to `Provider.defaultValue` when its key is missing.
@propertyWrapper
struct Default<Provider: DefaultValue>: Codable, Equatable, Sendable {
  var wrappedValue: Provider.Value

  init() {
    wrappedValue = Provider.defaultValue
  }

  init(wrappedValue: Provider.Value) {
    self.wrappedValue = wrappedValue
  }

  init(from decoder: Decoder) throws {
    wrappedValue = try decoder.singleValueContainer().decode(Provider.Value.self)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(wrappedValue)
  }
}

extension KeyedDecodingContainer {
  /// Used by synthesized `Codable` for `@Default` properties, so a missing key takes the default.
  func decode<P>(_ type: Default<P>.Type, forKey key: Key) throws -> Default<P> {
    try decodeIfPresent(type, forKey: key) ?? Default()
  }
}

/// A type whose `init()` is a sensible empty default.
protocol EmptyInitializable { init() }

extension Array: EmptyInitializable {}
extension Dictionary: EmptyInitializable {}
extension BuildSettings: EmptyInitializable {}
extension Config.Products: EmptyInitializable {}
extension Config.Frameworks: EmptyInitializable {}
extension Config.Build: EmptyInitializable {}
extension Config.Layout: EmptyInitializable {}
extension Config.Zip: EmptyInitializable {}
extension Config.Verify: EmptyInitializable {}

/// Defaults to the empty value: `[]`, `[:]`, or an empty config section.
enum Empty<Value: Codable & Equatable & Sendable & EmptyInitializable>: DefaultValue {
  static var defaultValue: Value {
    Value()
  }
}

enum True: DefaultValue {
  static var defaultValue: Bool {
    true
  }
}

enum False: DefaultValue {
  static var defaultValue: Bool {
    false
  }
}

enum DefaultArchiveName: DefaultValue {
  static var defaultValue: String {
    "{name}-{version}.zip"
  }
}

/// Static, like the CocoaPods-era zip; dynamic is opt-in.
enum DefaultLinkage: DefaultValue {
  static var defaultValue: Linkage {
    .static
  }
}

/// The platforms of the CocoaPods-era zip; visionOS is opt-in.
enum DefaultPlatforms: DefaultValue {
  static var defaultValue: [Platform] {
    [.ios, .catalyst, .macos, .tvos, .watchos]
  }
}
