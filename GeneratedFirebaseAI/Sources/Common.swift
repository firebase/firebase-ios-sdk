// Copyright 2025 Google LLC
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

public enum common {
  /**
   Gets the value of an object by a path.

   - getValueByPath(["a": ["b": v]], ["a", "b"]) -> v
   - getValueByPath(["a": ["b": [["c": v1], ["c": v2]]]], ["a", "b[]", "c"]) -> [v1, v2]
   */
  public static func getValueByPath(_ object: Any?, _ keys: [String],
                                    _ defaultValue: Any? = nil) -> Any? {
    guard let object = object, !keys.isEmpty else {
      return defaultValue
    }

    if keys.count == 1, keys[0] == "_self" {
      return object
    }

    var currentObject: Any? = object

    for i in 0 ..< keys.count {
      let key = keys[i]

      guard let currentDict = currentObject as? [String: Any] else {
        return defaultValue
      }

      if key.hasSuffix("[]") {
        let keyName = String(key.dropLast(2))
        if let array = currentDict[keyName] as? [Any] {
          let remainingKeys = Array(keys.dropFirst(i + 1))
          if remainingKeys.isEmpty {
            return array
          }
          var result: [Any] = []
          for item in array {
            if let value = getValueByPath(item, remainingKeys, defaultValue) {
              result.append(value)
            }
          }
          return result
        } else {
          return defaultValue
        }
      } else if key.hasSuffix("[0]") {
        let keyName = String(key.dropLast(3))
        if let array = currentDict[keyName] as? [Any], !array.isEmpty {
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

  /**
   Sets the value of an object by a path.

   - setValueByPath({}, ["a", "b"], v) -> ["a": ["b": v]]
   - setValueByPath({}, ["a", "b[]", "c"], [v1, v2]) -> ["a": ["b": [["c": v1], ["c": v2]]]]
   - setValueByPath(["a": ["b": [["c": v1], ["c": v2]]]], ["a", "b[]", "d"], v3) -> ["a": ["b": [["c": v1, "d": v3], ["c": v2, "d": v3]]]]
   */
  public static func setValueByPath(_ jsonObject: inout [String: Any], _ path: [String],
                                    _ value: Any) {
    guard !path.isEmpty else {
      print("Path cannot be empty.")
      return
    }

    var currentObject: [String: Any] = jsonObject

    for i in 0 ..< (path.count - 1) {
      let key = path[i]

      if key.hasSuffix("[]") {
        let keyName = String(key.dropLast(2))
        if currentObject[keyName] == nil {
          currentObject[keyName] = [[String: Any]]()
        }

        if var array = currentObject[keyName] as? [[String: Any]] {
          let remainingPath = Array(path[(i + 1)...])
          if let valueList = value as? [Any] {
            if array.count != valueList.count {
              array = valueList.map { _ in [String: Any]() }
            }
            for (j, var item) in array.enumerated() {
              setValueByPath(&item, remainingPath, valueList[j])
              array[j] = item
            }
          } else {
            if array.isEmpty {
              array.append([String: Any]())
            }
            for (j, var item) in array.enumerated() {
              setValueByPath(&item, remainingPath, value)
              array[j] = item
            }
          }
          currentObject[keyName] = array
        }
        return
      } else if key.hasSuffix("[0]") {
        let keyName = String(key.dropLast(3))
        if currentObject[keyName] == nil {
          currentObject[keyName] = [[String: Any]()]
        }
        if var array = currentObject[keyName] as? [[String: Any]], !array.isEmpty {
          var firstElement = array[0]
          let remainingPath = Array(path[(i + 1)...])
          setValueByPath(&firstElement, remainingPath, value)
          array[0] = firstElement
          currentObject[keyName] = array
        }
        return
      } else {
        if currentObject[key] == nil {
          currentObject[key] = [String: Any]()
        }
        if let nextObject = currentObject[key] as? [String: Any] {
          var temp = nextObject
          let remainingPath = Array(path.dropFirst(i + 1))
          let lastKey = remainingPath.last!
          var deepPath = Array(remainingPath.dropLast())

          var a = temp
          for k in deepPath {
            if a[k] == nil { a[k] = [String: Any]() }
            a = a[k] as! [String: Any]
          }
          a[lastKey] = value

          currentObject[key] = temp
        }
      }
    }

    let keyToSet = path.last!
    if keyToSet == "_self", let valueDict = value as? [String: Any] {
      jsonObject.merge(valueDict) { _, new in new }
    } else {
      jsonObject[keyToSet] = value
    }
  }
}
