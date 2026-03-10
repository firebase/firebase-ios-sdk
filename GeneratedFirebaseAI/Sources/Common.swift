// Copyright 2026 Google LLC
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

import Foundation

// TODO: Find a cleaner way to write these functions. Ideally without all the prints.
public enum common {
  /// Gets the value  within a dictionary by path, returning a default value if the value or path is
  /// not found.
  ///
  /// - Parameters:
  ///   - object: The dictionary to search for keys under.
  ///   - keys: A string array of keys to search through the object.
  ///   - defaultValue: A value to return if the object or value is not found.
  /// - Returns: The value or object found at the given path, or the default value if it wasn't
  /// found.
  ///
  /// # Special keys
  /// The following special keys can be included within the path:
  /// - `_self`: If this is the full path, then the object itself will be returned. Otherwise, it'll
  /// be treated as a standard part of the path.
  /// - `[]`: Signifies that the object is an array, and the returned value will be a an array of
  /// all the objects following that path within the array. For example: `requests[].text`
  /// will return an array of all the `text` elements within the `requests` array.
  /// - `[0]`: Maps to the first element in an array. For example: `requests[0].text` will return
  /// the `text` element from the first element in the `requests` array.
  ///
  /// # Examples
  ///
  /// Basic usage
  ///
  /// ```swift
  /// let object = [
  ///   "a": [
  ///     "b": "Hello!"
  ///   ]
  /// ]
  /// // Finding a value that exists
  /// XCTAssertEqualAndSameType(
  ///   common.getValueByPath(object, ["a", "b"], "Not Found"),
  ///   "Hello!"
  /// )
  ///
  /// // Finding a value that doesn't exist
  /// XCTAssertEqualAndSameType(
  ///   common.getValueByPath(object, ["a", "c"], "Not Found"),
  ///   "Not Found"
  /// )
  /// ```
  ///
  /// Usage with special keys.
  /// ```swift
  /// let object = [
  ///   "a": [
  ///     "a": "Do thing"
  ///     "b": [1, 2, 3],
  ///     "c": [
  ///       [
  ///         "a": "Hello",
  ///         "b": 5
  ///       ],
  ///       [
  ///         "a": "World",
  ///         "b": 6
  ///     ]
  ///   ],
  /// ]
  /// // Using the '_self' path
  /// XCTAssertEqualAndSameType(
  ///   common.getValueByPath(object, ["_self"], [:]),
  ///   object
  /// )
  ///
  /// // Using the '[]' path without any further path
  /// XCTAssertEqualAndSameType(
  ///   common.getValueByPath(object, ["a", "b[]"], []),
  ///   [1, 2, 3]
  /// )
  ///
  /// // Using the '[]' path with a nested path
  /// XCTAssertEqualAndSameType(
  ///   common.getValueByPath(object, ["a", "b[]", "a"], []),
  ///   ["Hello", "World"]
  /// )
  ///
  /// // Using the '[0]' path
  /// XCTAssertEqualAndSameType(
  ///   common.getValueByPath(object, ["a", "b[0]", "a"], ""),
  ///   "Hello"
  /// )
  /// ```
  public static func getValueByPath(_ object: Any?, _ keys: [String], _ defaultValue: Any? = nil)
    -> Any? {
    guard let object = object, !keys.isEmpty else {
      return defaultValue
    }

    if keys == ["_self"] {
      return object
    }

    var currentObject: Any? = object

    for i in 0 ..< keys.count {
      let key = keys[i]

      guard let currentDict = currentObject as? NSDictionary else {
        return defaultValue
      }

      if key.hasSuffix("[]") {
        let keyName = String(key.dropLast(2))

        if let array = currentDict[keyName] as? NSArray {
          let remainingKeys = Array(keys.dropFirst(i + 1))

          if remainingKeys.isEmpty {
            return array
          }

          let result = NSMutableArray()
          for item in array {
            if let value = getValueByPath(item, remainingKeys, defaultValue) {
              result.add(value)
            }
          }
          return result
        } else {
          return defaultValue
        }
      } else if key.hasSuffix("[0]") {
        let keyName = String(key.dropLast(3))
        if let array = currentDict[keyName] as? NSArray, array.count > 0 {
          currentObject = array[0]
        } else {
          return defaultValue
        }
      } else {
        if let nextObject = currentDict[key] {
          currentObject = nextObject
        } else {
          return defaultValue
        }
      }
    }
    return currentObject
  }

  /// Moves values from source paths to destination paths within a mutable dictionary.
  ///
  /// This function iterates through a dictionary of source-to-destination path mappings. For each
  /// mapping, it finds values at the source path and moves them to the destination path within the
  /// `data` dictionary. This is primarily used to restructure nested objects, and supports the
  /// `move_to_object_` fields from the generator.
  ///
  /// - Parameters:
  ///   - data: The `NSMutableDictionary` to modify.
  ///   - paths: A dictionary where keys are dot-separated source paths and values are dot-separated
  ///     destination paths.
  ///
  /// # Special Keys
  /// The following special keys can be used in the paths:
  /// - `[]`: Signifies that the object is an array, and the operation will be applied to each
  /// element in the array.
  /// - `*`: A wildcard that matches all keys at the current level. Any fields matched by the
  /// wildcard at the source path will be moved to the destination path.
  ///
  /// # Example
  /// Given the following `data` dictionary:
  /// ```swift
  /// [
  ///   "requests": [
  ///     [
  ///       "request": [
  ///         "content": "some content"
  ///       ],
  ///       "output_dimensionality": 768
  ///     ]
  ///   ]
  /// ]
  /// ```
  /// Calling `moveValueByPath` with the following `paths` mapping:
  /// ```swift
  /// ["requests[].*": "requests[].request.*"]
  /// ```
  /// Will result in the `data` dictionary being modified to:
  /// ```swift
  /// [
  ///   "requests": [
  ///     [
  ///       "request": [
  ///         "content": "some content",
  ///         "output_dimensionality": 768
  ///       ]
  ///     ]
  ///   ]
  /// ]
  /// ```
  /// The `output_dimensionality` key and its value have been moved under the `request` dictionary.
  public static func moveValueByPath(_ data: NSMutableDictionary, _ paths: [String: String]) {
    for (sourcePath, destPath) in paths {
      let sourceKeys = sourcePath.components(separatedBy: ".")
      let destKeys = destPath.components(separatedBy: ".")

      var excludeKeys = Set<String>()
      var wildcard_idx = -1
      for (i, key) in sourceKeys.enumerated() {
        if key == "*" {
          wildcard_idx = i
          break
        }
      }

      if wildcard_idx != -1, destKeys.count > wildcard_idx {
        for i in wildcard_idx ..< destKeys.count {
          let key = destKeys[i]
          if key != "*", !key.hasSuffix("[]"), !key.hasSuffix("[0]") {
            excludeKeys.insert(key)
          }
        }
      }

      moveValueRecursive(data, sourceKeys, destKeys, 0, &excludeKeys)
    }
  }

  private static func moveValueRecursive(_ data: NSMutableDictionary,
                                         _ sourceKeys: [String],
                                         _ destKeys: [String],
                                         _ keyIdx: Int,
                                         _ excludeKeys: inout Set<String>) {
    guard keyIdx < sourceKeys.count else { return }

    let key = sourceKeys[keyIdx]

    if key.hasSuffix("[]") {
      let keyName = String(key.dropLast(2))
      if let array = data[keyName] as? NSMutableArray {
        for i in 0 ..< array.count {
          if let dictItem = array[i] as? NSMutableDictionary {
            moveValueRecursive(
              dictItem,
              sourceKeys,
              destKeys,
              keyIdx + 1,
              &excludeKeys
            )
          }
        }
      }
    } else if key == "*" {
      let keysToMove = data.allKeys.compactMap { $0 as? String }.filter {
        !$0.hasPrefix("_") && !excludeKeys.contains($0)
      }

      var valuesToMove: [String: Any] = [:]
      for k in keysToMove {
        if let val = data[k] {
          valuesToMove[k] = val
        }
      }

      for (k, v) in valuesToMove {
        var newDestKeys: [String] = []
        for dk in destKeys[keyIdx...] {
          if dk == "*" {
            newDestKeys.append(k)
          } else {
            newDestKeys.append(dk)
          }
        }
        setValueByPath(data, newDestKeys, v)
      }

      for k in keysToMove {
        data.removeObject(forKey: k)
      }
    } else {
      if let nestedData = data[key] as? NSMutableDictionary {
        moveValueRecursive(
          nestedData,
          sourceKeys,
          destKeys,
          keyIdx + 1,
          &excludeKeys
        )
      } else if let value = data[key], keyIdx == sourceKeys.count - 1 {
        data.removeObject(forKey: key)
        let remainingDestKeys = destKeys.dropFirst(keyIdx)
        setValueByPath(data, Array(remainingDestKeys), value)
      }
    }
  }

  /// Sets a value at a specified path within a mutable dictionary.
  ///
  /// This function navigates through the `data` dictionary using the provided `keys`. If the path
  /// does not exist, it creates nested dictionaries as needed.
  ///
  /// - Parameters:
  ///   - data: The `NSMutableDictionary` to modify.
  ///   - keys: An array of strings representing the path where the value should be set.
  ///   - value: The value to set at the specified path.
  ///
  /// # Special Keys
  /// The following special keys can be used in the path:
  /// - `[]`: Signifies that the object is an array. The operation will be applied to each element.
  ///   If the `value` is an array, its elements are mapped to the corresponding elements in the
  ///   target array. If `value` is a single item, it's set for all elements in the target array.
  /// - `[0]`: Accesses the first element of an array.
  /// - `_self`: If this is the only key in the path, the `value` (which must be a dictionary)
  ///   is merged into the dictionary at the current path.
  ///
  /// # Example
  /// ```swift
  /// var data: NSMutableDictionary = [
  ///   "a": [
  ///     "b": [
  ///       ["c": "old_value_1"],
  ///       ["c": "old_value_2"]
  ///     ]
  ///   ]
  /// ]
  ///
  /// // Set a simple value
  /// setValueByPath(data, ["a", "d"], "new_value")
  /// // data is now ["a": ["b": ..., "d": "new_value"]]
  ///
  /// // Set a value in each element of an array
  /// setValueByPath(data, ["a", "b[]", "e"], "another_value")
  /// // data is now ["a": ["b": [["c": "old_value_1", "e": "another_value"], ["c": "old_value_2",
  /// "e": "another_value"]]]]
  ///
  /// // Set values from an array into an array
  /// setValueByPath(data, ["a", "b[]", "f"], ["f_val1", "f_val2"])
  /// // data is now ["a": ["b": [["c": ..., "e": ..., "f": "f_val1"], ["c": ..., "e": ..., "f":
  /// "f_val2"]]]]
  /// ```
  public static func setValueByPath(_ data: NSMutableDictionary, _ keys: [String], _ value: Any?) {
    guard !keys.isEmpty else { return }

    setValueRecursive(data, keys: ArraySlice(keys), value: value)
  }

  private static func setValueRecursive(_ data: NSMutableDictionary, keys: ArraySlice<String>,
                                        value: Any?) {
    guard let key = keys.first else {
      if let valueDict = value as? NSDictionary {
        data.addEntries(from: valueDict as! [AnyHashable: Any])
      }
      return
    }

    let remainingKeys = keys.dropFirst()

    if key.hasSuffix("[]") {
      let keyName = key.dropLast(2)

      if data[keyName] == nil {
        if let valueArray = value as? NSArray {
          let newArray = NSMutableArray()
          for _ in 0 ..< valueArray.count {
            newArray.add(NSMutableDictionary())
          }
          data[keyName] = newArray
        } else {
          print("Error: `value` must be an array when initializing for an array path `\(key)`.")
          return
        }
      }

      guard let array = data[keyName] as? NSMutableArray else {
        print("Error: Value at key `\(keyName)` is not an NSMutableArray.")
        return
      }

      if let valueArray = value as? NSArray {
        guard valueArray.count == array.count else {
          print(
            "Error: When value is an array, its count must match the target array's count for `\(key)`."
          )
          return
        }
        for i in 0 ..< array.count {
          if let element = array[i] as? NSMutableDictionary {
            setValueRecursive(element, keys: remainingKeys, value: valueArray[i])
          } else if let immutableElement = array[i] as? NSDictionary {
            let mutableElement = NSMutableDictionary(dictionary: immutableElement)
            setValueRecursive(mutableElement, keys: remainingKeys, value: valueArray[i])
            array[i] = mutableElement
          }
        }
      } else {
        for i in 0 ..< array.count {
          if let element = array[i] as? NSMutableDictionary {
            setValueRecursive(element, keys: remainingKeys, value: value)
          } else if let immutableElement = array[i] as? NSDictionary {
            let mutableElement = NSMutableDictionary(dictionary: immutableElement)
            setValueRecursive(mutableElement, keys: remainingKeys, value: value)
            array[i] = mutableElement
          }
        }
      }
      return
    }

    if key.hasSuffix("[0]") {
      let keyName = String(key.dropLast(3))
      if data[keyName] == nil {
        data[keyName] = NSMutableArray(array: [NSMutableDictionary()])
      }

      guard let array = data[keyName] as? NSMutableArray, array.count > 0 else {
        print("Error: Value at key `\(keyName)` is not an array or is empty.")
        return
      }

      if let element = array[0] as? NSMutableDictionary {
        setValueRecursive(element, keys: remainingKeys, value: value)
      } else if let immutableElement = array[0] as? NSDictionary {
        let mutableElement = NSMutableDictionary(dictionary: immutableElement)
        setValueRecursive(mutableElement, keys: remainingKeys, value: value)
        array[0] = mutableElement
      }
      return
    }

    if remainingKeys.isEmpty {
      if key == "_self" {
        if let valueDict = value as? NSDictionary {
          data.addEntries(from: valueDict as! [AnyHashable: Any])
        } else {
          print("Error: `_self` key requires a dictionary value.")
        }
        return
      }

      if let existing = data[key] as? NSMutableDictionary,
         let valueDict = value as? NSDictionary {
        existing.addEntries(from: valueDict as! [AnyHashable: Any])
      } else {
        data[key] = value
      }
    } else {
      if data[key] == nil {
        data[key] = NSMutableDictionary()
      }

      if let immutableDict = data[key] as? NSDictionary, !(immutableDict is NSMutableDictionary) {
        let mutableDict = NSMutableDictionary(dictionary: immutableDict)
        data[key] = mutableDict
      }

      guard let nestedDict = data[key] as? NSMutableDictionary else {
        print("Error: Cannot create nested structure: `\(key)` is not a dictionary.")
        return
      }
      setValueRecursive(nestedDict, keys: remainingKeys, value: value)
    }
  }

  /// Encodes a value to a JSON object of `NSMutableDictionary`.
  ///
  /// More specifically, this function will take an object that implements `Encodable`, convert it
  /// to a JSON object via `JSONEncoder`, then decode it via `JSONSerialization` into
  /// an `NSMutableDictionary` whose nested containers and leaves are also mutable.
  ///
  /// - Parameters:
  ///   - object: The object to encode. The object must implement `Encodable`.
  /// - Returns: A recursively mutable dictionary represented by `NSMutableDictionary`, whose
  ///   key/values are json encoded.
  public static func encodeToDict<T>(_ value: T) throws -> NSMutableDictionary where T: Encodable {
    let json = try JSONEncoder().encode(value)
    return try JSONSerialization.jsonObject(
      with: json, options: [.mutableContainers, .mutableLeaves]
    ) as! NSMutableDictionary
  }
}
