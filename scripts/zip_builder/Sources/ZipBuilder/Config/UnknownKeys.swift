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

/// Warns about every key in the config's JSON that isn't a property of the config struct it's
/// in, e.g. `frameworks: privateHeader isn't a config key; ignored.`
///
/// The synthesized decoder ignores unknown keys, and a typo shouldn't silently do nothing. The
/// property names come from the decoded config itself (via `Mirror`), so a new key needs no
/// change here. Maps such as `products.rename` and `build.settings` are skipped: their keys are
/// names, not properties.
///
/// - Parameters:
///   - json: the config file parsed by `JSONSerialization`.
///   - value: the same file decoded, or any part of it at `path`.
///   - path: the dotted key path of `value`, e.g. `products.add[0]`; empty at the top level.
func warnAboutUnknownKeys(in json: Any, of value: Any, path: String = "") {
  guard let value = unwrappingOptional(value), !(value is BuildSettings) else { return }
  let mirror = Mirror(reflecting: value)
  switch mirror.displayStyle {
  case .struct:
    guard let object = json as? [String: Any] else { return }
    let properties = configProperties(of: mirror)
    for (key, keyJSON) in object.sorted(by: { $0.key < $1.key }) {
      if let property = properties[key] {
        warnAboutUnknownKeys(in: keyJSON, of: property, path: path.isEmpty ? key : "\(path).\(key)")
      } else {
        warn(path.isEmpty
          ? "\(key) isn't a config key; ignored."
          : "\(path): \(key) isn't a config key; ignored.")
      }
    }
  case .collection:
    guard let array = json as? [Any] else { return }
    for (index, (elementJSON, element)) in zip(array, mirror.children.map(\.value)).enumerated() {
      warnAboutUnknownKeys(in: elementJSON, of: element, path: "\(path)[\(index)]")
    }
  default:
    // Dictionaries are maps keyed by names; strings, numbers and enums have no keys.
    return
  }
}

/// A config struct's properties by key, with `@Default` wrappers removed: `Mirror` shows a
/// `@Default var platforms` as `_platforms`, holding the wrapper.
private func configProperties(of mirror: Mirror) -> [String: Any] {
  var properties: [String: Any] = [:]
  for child in mirror.children {
    guard let label = child.label else { continue }
    if let wrapper = child.value as? AnyDefault, label.hasPrefix("_") {
      properties[String(label.dropFirst())] = wrapper.wrappedValueAsAny
    } else {
      properties[label] = child.value
    }
  }
  return properties
}

/// `value` itself, or what it holds when it's an optional; nil for an empty optional.
private func unwrappingOptional(_ value: Any) -> Any? {
  let mirror = Mirror(reflecting: value)
  guard mirror.displayStyle == .optional else { return value }
  return mirror.children.first?.value
}

/// A `@Default` wrapper whatever its provider, so `Mirror` children can be unwrapped.
private protocol AnyDefault {
  var wrappedValueAsAny: Any { get }
}

extension Default: AnyDefault {
  var wrappedValueAsAny: Any {
    wrappedValue
  }
}
