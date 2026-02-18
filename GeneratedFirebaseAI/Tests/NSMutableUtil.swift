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

extension NSMutableDictionary {
  static func from(dictionary: [String: Any]) -> NSMutableDictionary {
    let mutableDictionary = NSMutableDictionary()
    for (key, value) in dictionary {
      if let nestedDict = value as? [String: Any] {
        mutableDictionary[key] = NSMutableDictionary.from(dictionary: nestedDict)
      } else if let nestedArray = value as? [Any] {
        mutableDictionary[key] = NSMutableArray.from(array: nestedArray)
      } else {
        mutableDictionary[key] = value
      }
    }
    return mutableDictionary
  }
}

extension NSMutableArray {
  static func from(array: [Any]) -> NSMutableArray {
    let mutableArray = NSMutableArray()
    for item in array {
      if let nestedDict = item as? [String: Any] {
        mutableArray.add(NSMutableDictionary.from(dictionary: nestedDict))
      } else if let nestedArray = item as? [Any] {
        mutableArray.add(NSMutableArray.from(array: nestedArray))
      } else {
        mutableArray.add(item)
      }
    }
    return mutableArray
  }
}
