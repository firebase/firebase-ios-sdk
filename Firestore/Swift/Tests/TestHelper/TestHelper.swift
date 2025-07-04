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

import FirebaseCore
import FirebaseFirestore
import Foundation
import XCTest

public enum TestHelper {
  public static func compare(pipelineSnapshot snapshot: PipelineSnapshot,
                             expectedCount: Int,
                             file: StaticString = #file,
                             line: UInt = #line) {
    XCTAssertEqual(
      snapshot.results.count,
      expectedCount,
      "Snapshot results count mismatch",
      file: file,
      line: line
    )
  }

  static func compare(pipelineSnapshot snapshot: PipelineSnapshot,
                      expectedIDs: [String],
                      enforceOrder: Bool,
                      file: StaticString = #file,
                      line: UInt = #line) {
    let results = snapshot.results
    XCTAssertEqual(
      results.count,
      expectedIDs.count,
      "Snapshot document IDs count mismatch. Expected \(expectedIDs.count), got \(results.count). Actual IDs: \(results.map { $0.id })",
      file: file,
      line: line
    )

    if enforceOrder {
      let actualIDs = results.map { $0.id! }
      XCTAssertEqual(
        actualIDs,
        expectedIDs,
        "Snapshot document IDs mismatch. Expected: \(expectedIDs.sorted()), got: \(actualIDs)",
        file: file,
        line: line
      )
    } else {
      let actualIDs = results.map { $0.id! }.sorted()
      XCTAssertEqual(
        actualIDs,
        expectedIDs.sorted(),
        "Snapshot document IDs mismatch. Expected (sorted): \(expectedIDs.sorted()), got (sorted): \(actualIDs)",
        file: file,
        line: line
      )
    }
  }

  static func compare(pipelineSnapshot snapshot: PipelineSnapshot,
                      expected: [[String: Sendable?]],
                      enforceOrder: Bool,
                      file: StaticString = #file,
                      line: UInt = #line) {
    guard snapshot.results.count == expected.count else {
      XCTFail("Mismatch in expected results count and actual results count.")
      return
    }

    if enforceOrder {
      for i in 0 ..< expected.count {
        compare(pipelineResult: snapshot.results[i], expected: expected[i])
      }
    } else {
      let result = snapshot.results.map { $0.data }
      XCTAssertTrue(areArraysOfDictionariesEqualRegardlessOfOrder(result, expected),
                    "PipelineSnapshot mismatch. Expected \(expected), got \(result)")
    }
  }

  static func compare(pipelineResult result: PipelineResult,
                      expected: [String: Sendable?],
                      file: StaticString = #file,
                      line: UInt = #line) {
    XCTAssertTrue(areDictionariesEqual(result.data, expected),
                  "Document data mismatch. Expected \(expected), got \(result.data)")
  }

  // MARK: - Internal helper

  private static func isNilOrNSNull(_ value: Sendable?) -> Bool {
    // First, use a `guard` to safely unwrap the optional.
    // If it's nil, we can immediately return true.
    guard let unwrappedValue = value else {
      return true
    }

    // If it wasn't nil, we now check if the unwrapped value is the NSNull object.
    return unwrappedValue is NSNull
  }

  // A custom function to compare two values of type 'Sendable'
  private static func areEqual(_ value1: Sendable?, _ value2: Sendable?) -> Bool {
    if isNilOrNSNull(value1) || isNilOrNSNull(value2) {
      return isNilOrNSNull(value1) && isNilOrNSNull(value2)
    }

    switch (value1!, value2!) {
    case let (v1 as [String: Sendable?], v2 as [String: Sendable?]):
      return areDictionariesEqual(v1, v2)
    case let (v1 as [Sendable?], v2 as [Sendable?]):
      return areArraysEqual(v1, v2)
    case let (v1 as Timestamp, v2 as Timestamp):
      return v1 == v2
    case let (v1 as Date, v2 as Timestamp):
      // Firestore converts Dates to Timestamps
      return Timestamp(date: v1) == v2
    case let (v1 as GeoPoint, v2 as GeoPoint):
      return v1.latitude == v2.latitude && v1.longitude == v2.longitude
    case let (v1 as DocumentReference, v2 as DocumentReference):
      return v1.path == v2.path
    case let (v1 as VectorValue, v2 as VectorValue):
      return v1.array == v2.array
    case let (v1 as Data, v2 as Data):
      return v1 == v2
    case let (v1 as Int, v2 as Int):
      return v1 == v2
    case let (v1 as Double, v2 as Double):
      let doubleEpsilon = 0.000001
      return abs(v1 - v2) <= doubleEpsilon
    case let (v1 as Float, v2 as Float):
      let floatEpsilon: Float = 0.00001
      return abs(v1 - v2) <= floatEpsilon
    case let (v1 as String, v2 as String):
      return v1 == v2
    case let (v1 as Bool, v2 as Bool):
      return v1 == v2
    case let (v1 as UInt8, v2 as UInt8):
      return v1 == v2
    default:
      // Fallback for any other types, might need more specific checks
      return false
    }
  }

  // A function to compare two dictionaries
  private static func areDictionariesEqual(_ dict1: [String: Sendable?],
                                           _ dict2: [String: Sendable?]) -> Bool {
    guard dict1.count == dict2.count else { return false }

    for (key, value1) in dict1 {
      guard let value2 = dict2[key], areEqual(value1, value2) else {
        XCTFail("""
        Dictionary value mismatch for key: '\(key)'
        Actual value: '\(String(describing: value1))' (from dict1)
        Expected value:   '\(String(describing: dict2[key]))' (from dict2)
        Full actual value: \(String(describing: dict1))
        Full expected value: \(String(describing: dict2))
        """)
        return false
      }
    }
    return true
  }

  private static func areArraysEqual(_ array1: [Sendable?], _ array2: [Sendable?]) -> Bool {
    guard array1.count == array2.count else { return false }

    for (index, value1) in array1.enumerated() {
      let value2 = array2[index]
      if !areEqual(value1, value2) {
        XCTFail("""
        Array value mismatch.
        Actual array value: '\(String(describing: value1))'
        Expected array value:   '\(String(describing: value2))'
        """)
        return false
      }
    }
    return true
  }

  private static func areArraysOfDictionariesEqualRegardlessOfOrder(_ array1: [[String: Sendable?]],
                                                                    _ array2: [[String: Sendable?]])
    -> Bool {
    // 1. Check if the arrays have the same number of dictionaries.
    guard array1.count == array2.count else {
      return false
    }

    // Create a mutable copy of array2 to remove matched dictionaries
    var mutableArray2 = array2

    // Iterate through each dictionary in array1
    for dict1 in array1 {
      var foundMatch = false
      // Try to find an equivalent dictionary in mutableArray2
      if let index = mutableArray2.firstIndex(where: { dict2 in
        areDictionariesEqual(dict1, dict2) // Use our deep comparison function
      }) {
        // If a match is found, remove it from mutableArray2 to handle duplicates
        mutableArray2.remove(at: index)
        foundMatch = true
      }

      // If no match was found for the current dictionary from array1, arrays are not equal
      if !foundMatch {
        return false
      }
    }

    // If we've iterated through all of array1 and mutableArray2 is empty,
    // it means all dictionaries found a unique match.
    return mutableArray2.isEmpty
  }
}
