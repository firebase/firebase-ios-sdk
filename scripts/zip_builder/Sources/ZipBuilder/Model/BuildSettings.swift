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

/// Xcode build settings. Keys may carry a condition, e.g. `KEY[sdk=iphoneos*]`.
///
/// Stored unordered; use `keys` for a stable order.
struct BuildSettings: Codable, Equatable, Sendable, ExpressibleByDictionaryLiteral {
  /// A setting's value: one string or a list of strings.
  enum Value: Codable, Equatable, Sendable, ExpressibleByStringLiteral, ExpressibleByArrayLiteral {
    case string(String)
    case list([String])

    init(stringLiteral value: String) {
      self = .string(value)
    }

    init(arrayLiteral elements: String...) {
      self = .list(elements)
    }

    /// The value as a list; a single string becomes a one-element list.
    var list: [String] {
      switch self {
      case let .string(value): [value]
      case let .list(values): values
      }
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      if let value = try? container.decode(String.self) {
        self = .string(value)
      } else {
        self = try .list(container.decode([String].self))
      }
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      switch self {
      case let .string(value): try container.encode(value)
      case let .list(values): try container.encode(values)
      }
    }
  }

  private var values: [String: Value]

  init() {
    values = [:]
  }

  init(dictionaryLiteral elements: (String, Value)...) {
    values = Dictionary(elements) { _, last in last }
  }

  subscript(key: String) -> Value? {
    get { values[key] }
    set { values[key] = newValue }
  }

  /// The setting keys, sorted.
  var keys: [String] {
    values.keys.sorted()
  }

  /// Appends `items` to the list value of `key`, turning a single string into a list first.
  mutating func append(_ items: [String], to key: String) {
    values[key] = .list((values[key]?.list ?? []) + items)
  }

  /// Adds `other`'s settings; its values replace existing ones with the same key.
  mutating func merge(_ other: BuildSettings) {
    values.merge(other.values) { _, new in new }
  }

  /// These settings with `other`'s added; its values win.
  func merging(_ other: BuildSettings) -> BuildSettings {
    var result = self
    result.merge(other)
    return result
  }

  init(from decoder: Decoder) throws {
    values = try decoder.singleValueContainer().decode([String: Value].self)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(values)
  }
}

/// Operations `customize` uses to change a plan's settings.
extension BuildSettings {
  /// These settings plus `other`'s, for merging frameworks: a single value keeps ours (so the
  /// parent's identity and language standards win), and lists, or a list and a single value, are
  /// unioned without adding duplicates. A flag and its argument (`-framework Security`) count as
  /// one item, so `-framework X -framework Y` isn't collapsed.
  func combined(with other: BuildSettings) -> BuildSettings {
    var result = self
    for key in other.keys {
      guard let theirs = other[key] else { continue }
      switch (self[key], theirs) {
      case (nil, _):
        result[key] = theirs
      case (.string?, .string):
        break // a single value keeps ours
      case let (mine?, _):
        // Not `union()`: that would also drop duplicates already in ours, which are kept.
        var groups = flagGroups(mine.list)
        for group in flagGroups(theirs.list) where !groups.contains(group) {
          groups.append(group)
        }
        result[key] = .list(groups.flatMap { $0 })
      }
    }
    return result
  }

  /// Removes `key` and its conditional and helper variants (`KEY[sdk=…]`, `KEY_MACOS`, …).
  mutating func removeAllVariants(of key: String) {
    for name in keys where Self.isVariant(name, of: key) {
      self[name] = nil
    }
  }

  /// Removes the items matching `isRemoved` from `key` and its variants.
  mutating func removeItems(from key: String, where isRemoved: (String) -> Bool) {
    for name in keys where Self.isVariant(name, of: key) {
      guard let items = self[name]?.list else { continue }
      let kept = items.filter { !isRemoved($0) }
      if kept.count != items.count {
        self[name] = kept.isEmpty ? nil : .list(kept)
      }
    }
  }

  /// The suffixes of the helper keys `add(_:to:onlyFor:)` (Planning/SwiftPMSettings.swift) writes
  /// for macOS and Mac Catalyst, so `customize` removes them along with the key.
  static let macHelperSuffixes = ["_MACOS", "_CATALYST", "_NO", "_YES"]

  private static func isVariant(_ name: String, of key: String) -> Bool {
    name == key || name.hasPrefix("\(key)[")
      || macHelperSuffixes.contains { name == key + $0 }
  }

  /// Applies `build.deploymentTargets`. Raising iOS raises Mac Catalyst too, unless Catalyst is
  /// configured, because Catalyst compiles the iOS sources.
  mutating func overrideDeploymentTargets(_ targets: [Platform: String]) {
    guard !targets.isEmpty else { return }
    let catalystKey = "IPHONEOS_DEPLOYMENT_TARGET[sdk=macosx*]"
    let iOSKey = Platform.ios.deploymentTargetKey
    // Read before iOS is overridden: Catalyst's own key, else it follows iOS.
    let oldCatalyst = self[catalystKey]?.list.first ?? self[iOSKey]?.list.first
    for (platform, version) in targets where platform != .catalyst {
      self[platform.deploymentTargetKey] = .string(version)
    }
    let iOS = self[iOSKey]?.list.first
    // A configured Catalyst target wins; otherwise raising iOS raises Catalyst too.
    let catalyst = targets[.catalyst] ?? newer(oldCatalyst, iOS)
    // Catalyst only needs its own key when it differs from iOS.
    self[catalystKey] = catalyst == iOS ? nil : catalyst.map { .string($0) }
  }
}

/// The newer of two versions, compared numerically (`10.0` is newer than `9.0`); `nil` only
/// when both are. Numerically equal versions keep `old`.
private func newer(_ old: String?, _ new: String?) -> String? {
  guard let old, let new else { return old ?? new }
  return old.compare(new, options: .numeric) == .orderedAscending ? new : old
}

/// `items` in groups: a flag keeps the argument that follows it, e.g. `-framework Security`.
private func flagGroups(_ items: [String]) -> [[String]] {
  var groups: [[String]] = []
  for item in items {
    let previousIsLoneFlag = groups.last.map { $0.count == 1 && $0[0].hasPrefix("-") } ?? false
    if previousIsLoneFlag, !item.hasPrefix("-") {
      groups[groups.count - 1].append(item) // the flag's argument, e.g. `Security`
    } else {
      groups.append([item])
    }
  }
  return groups
}

/// Whether `key`, possibly conditional (`KEY[sdk=…]`), holds header search paths.
func isHeaderSearchPathSetting(_ key: String) -> Bool {
  ["HEADER_SEARCH_PATHS", "USER_HEADER_SEARCH_PATHS", "SYSTEM_HEADER_SEARCH_PATHS"]
    .contains { key.hasPrefix($0) }
}
