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

import FirebaseAppCheckInterop
import FirebaseAuthInterop
import FirebaseCore
import Foundation
import XCTest

@testable import GeneratedFirebaseAI

#if os(Linux)
  import FoundationNetworking
#endif

class CommonTests: XCTestCase {
  func test_getValueByPath_simplePath() async throws {
    let data = ["a": ["b": 1]]
    let result = common.getValueByPath(data, ["a", "b"])
    XCTAssertEqualAndSameType(result, 1)
  }

  func test_getValueByPath_returnsMutableTypes() throws {
    let data = NSMutableDictionary.from(dictionary: [
      "a": [
        "b": 1,
      ],
    ])
    let result = common.getValueByPath(data, ["a"])
    guard let a = result as? NSMutableDictionary else {
      WrongType(for: NSMutableDictionary.self, result)
      return
    }

    a["b"] = 2

    XCTAssertEqual(
      data as NSDictionary,
      [
        "a": [
          "b": 2,
        ],
      ]
    )
  }

  func test_getValueByPath_worksWithArrayTypes() {
    let data = [
      "a": [
        "b": [
          ["c": 1],
          ["c": 2],
        ],
      ],
    ]

    // Test getting a value from a specific index.
    let firstElement = common.getValueByPath(data, ["a", "b[0]", "c"])
    XCTAssertEqualAndSameType(firstElement, 1)

    // Test getting a whole sub-array.
    let subArray = common.getValueByPath(data, ["a", "b"])
    XCTAssertEqualAndSameType(subArray, [["c": 1], ["c": 2]])
  }

  func test_getValueByPath_worksWithMissingKeys() {
    let data = ["a": ["b": 1]]

    // Test with a missing intermediate key.
    let missingIntermediate = common.getValueByPath(data, ["a", "c", "d"])
    XCTAssertNil(missingIntermediate)

    // Test with a missing final key.
    let missingFinal = common.getValueByPath(data, ["a", "c"])
    XCTAssertNil(missingFinal)

    // Test with an out-of-bounds array index.
    let arrayData = ["a": [1, 2]]
    let outOfBounds = common.getValueByPath(arrayData, ["a[2]"])
    XCTAssertNil(outOfBounds)
  }

  func test_getValueByPath_edgeCases() {
    // Test with an empty path, should return the default data.
    let data: [String: Any] = ["a": 1]
    let resultWithEmptyPath = common.getValueByPath(data, [], 5)
    XCTAssertEqualAndSameType(resultWithEmptyPath, 5)

    // Test with empty data.
    let resultWithEmptyData = common.getValueByPath([:], ["a", "b"])
    XCTAssertNil(resultWithEmptyData)

    // Test pathing into a non-dictionary value.
    let nonDictData = ["a": 1]
    let pathIntoNonDict = common.getValueByPath(nonDictData, ["a", "b"])
    XCTAssertNil(pathIntoNonDict)
  }

  func test_setValueByPath_simplePath() {
    // Test setting a value in a new path.
    let data = NSMutableDictionary()
    common.setValueByPath(data, ["a", "b"], 1)
    XCTAssertEqual(data as NSDictionary, ["a": ["b": 1]])

    // Test overwriting an existing value.
    common.setValueByPath(data, ["a", "b"], 2)
    XCTAssertEqual(data as NSDictionary, ["a": ["b": 2]])
  }

  func test_setValueByPath_mergesDictionaries() {
    // Test merging a dictionary at the end of a path.
    let data = NSMutableDictionary.from(dictionary: ["a": ["b": 1]])
    common.setValueByPath(data, ["a"], ["c": 2])
    XCTAssertEqual(data as NSDictionary, ["a": ["b": 1, "c": 2]])

    // Test merging with the `_self` keyword.
    let data2: NSMutableDictionary = ["a": ["b": 1]]
    common.setValueByPath(data2, ["a", "_self"], ["c": 2])
    XCTAssertEqual(data2 as NSDictionary, ["a": ["b": 1, "c": 2]])
  }

  func test_setValueByPath_arrayHandling() {
    // Test initializing an array and setting values from another array.
    let data = NSMutableDictionary()
    common.setValueByPath(data, ["a", "b[]", "c"], [1, 2])
    var expected: NSDictionary = [
      "a": [
        "b": [
          ["c": 1],
          ["c": 2],
        ],
      ],
    ]
    XCTAssertEqual(data as NSDictionary, expected)

    // Test setting a single value for all elements in an array.
    common.setValueByPath(data, ["a", "b[]", "d"], 3)
    expected = [
      "a": [
        "b": [
          ["c": 1, "d": 3],
          ["c": 2, "d": 3],
        ],
      ],
    ]
    XCTAssertEqual(data as NSDictionary, expected)

    // Test setting a value in the first element of an array.
    common.setValueByPath(data, ["a", "b[0]", "e"], 4)
    expected = [
      "a": [
        "b": [
          ["c": 1, "d": 3, "e": 4],
          ["c": 2, "d": 3],
        ],
      ],
    ]
    XCTAssertEqual(data as NSDictionary, expected)
  }

  func test_setValueByPath_edgeCases() {
    // Test with an empty path, should return the root object.
    let data = NSMutableDictionary.from(dictionary: ["a": 1])
    common.setValueByPath(data, [], ["b": 2])
    XCTAssertEqual(data as NSDictionary, ["a": 1])

    // Test with a nil value, should set the value to nil.
    let data2: NSMutableDictionary = ["a": 1]
    common.setValueByPath(data2, ["a"], nil)
    XCTAssertEqual(data2 as NSDictionary, [:])

    // Test pathing into a non-dictionary value, should do nothing.
    let data3: NSMutableDictionary = ["a": 1]
    common.setValueByPath(data3, ["a", "b"], 2)
    XCTAssertEqual(data3 as NSDictionary, ["a": 1])
  }

  func test_moveValueByPath_simpleMove() {
    let data = NSMutableDictionary.from(dictionary: ["a": ["b": 1, "c": 2]])
    common.moveValueByPath(data, ["a.b": "a.d"])
    XCTAssertEqual(data as NSDictionary, ["a": ["c": 2, "d": 1]])
  }

  func test_moveValueByPath_withWildcard() {
    let data = NSMutableDictionary.from(dictionary: ["a": ["b": 1, "c": 2]])
    common.moveValueByPath(data, ["a.*": "a.nest.*"])
    XCTAssertEqual(data as NSDictionary, ["a": ["nest": ["b": 1, "c": 2]]])
  }

  func test_moveValueByPath_withArrayAndWildcard() {
    let data = NSMutableDictionary.from(dictionary: [
      "requests": [
        [
          "request": [
            "content": "some content",
          ],
          "output_dimensionality": 768,
        ],
      ],
    ])
    let paths = ["requests[].*": "requests[].request.*"]
    let expectedOutput: NSDictionary = [
      "requests": [
        [
          "request": [
            "content": "some content",
            "output_dimensionality": 768,
          ],
        ],
      ],
    ]
    common.moveValueByPath(data, paths)
    XCTAssertEqual(data as NSDictionary, expectedOutput)
  }

  func test_moveValueByPath_withWildcardAndExclusions() {
    let data = NSMutableDictionary.from(dictionary: [
      "a": [
        "b": ["some_key": "some_value"],
        "c": 1,
        "d": 2,
      ],
    ])
    // Move everything under 'a' into 'a.b', but 'b' itself should not be moved.
    common.moveValueByPath(data, ["a.*": "a.b.*"])
    let expected = NSMutableDictionary.from(dictionary: [
      "a": [
        "b": [
          "some_key": "some_value",
          "c": 1,
          "d": 2,
        ],
      ],
    ])
    XCTAssertEqual(data as NSDictionary, expected)
  }

  func test_moveValueByPath_edgeCases() {
    // Test with non-existent source path, should do nothing.
    var data: NSMutableDictionary = ["a": 1]
    common.moveValueByPath(data, ["b.c": "d.e"])
    XCTAssertEqual(data as NSDictionary, ["a": 1])

    // Test with empty paths, should do nothing.
    data = ["a": 1]
    common.moveValueByPath(data, [:])
    XCTAssertEqual(data as NSDictionary, ["a": 1])

    // Test moving to a path that doesn't exist, should create it.
    data = ["a": 1]
    common.moveValueByPath(data, ["a": "b.c"])
    XCTAssertEqual(data as NSDictionary, ["b": ["c": 1]])
  }
}
