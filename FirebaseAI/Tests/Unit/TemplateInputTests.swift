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

@testable import FirebaseAILogic
import XCTest

final class TemplateInputTests: XCTestCase {
  func testInitWithFloat() throws {
    let floatValue: Float = 3.14
    let templateInput = try TemplateInput(value: floatValue)
    guard case let .double(doubleValue) = templateInput else {
      XCTFail("Expected a .double case, but got \(templateInput)")
      return
    }
    XCTAssertEqual(doubleValue, Double(floatValue), accuracy: 1e-6)
  }

  // MARK: - NSNumber Bridging

  func testInitWithBridgedBoolean() throws {
    let templateInput = try TemplateInput(value: NSNumber(value: true))

    XCTAssertEqual(templateInput, .bool(true))
  }

  func testInitWithBridgedInteger() throws {
    let templateInput = try TemplateInput(value: NSNumber(value: 1))

    XCTAssertEqual(templateInput, .int(1))
  }

  /// `JSONSerialization` yields `NSNumber`s, where `true` and `1` are mutually castable.
  func testInitWithJSONSerializationValues() throws {
    let json = Data(#"{"flag": true, "count": 1, "ratio": 1.5}"#.utf8)
    let values = try XCTUnwrap(
      JSONSerialization.jsonObject(with: json) as? [String: Any]
    )

    let inputs = try TemplateInput.inputs(from: values)

    XCTAssertEqual(inputs["flag"], .bool(true))
    XCTAssertEqual(inputs["count"], .int(1))
    XCTAssertEqual(inputs["ratio"], .double(1.5))
  }

  // MARK: - Conversion Errors

  func testInputsFromValues_unsupportedValue_throwsErrorNamingKey() throws {
    let values: [String: Any] = ["name": "test", "timestamp": Date()]

    XCTAssertThrowsError(try TemplateInput.inputs(from: values)) { error in
      guard case let EncodingError.invalidValue(_, context) = error else {
        XCTFail("Expected EncodingError.invalidValue, got: \(error)")
        return
      }
      XCTAssertEqual(context.codingPath.map(\.stringValue), ["timestamp"])
      XCTAssertTrue(
        context.debugDescription.contains("timestamp"),
        "Expected the variable name in: \(context.debugDescription)"
      )
      XCTAssertTrue(
        context.debugDescription.contains("Date"),
        "Expected the offending type in: \(context.debugDescription)"
      )
      XCTAssertNotNil(context.underlyingError)
    }
  }

  func testInputsFromValues_empty() throws {
    let inputs = try TemplateInput.inputs(from: [:])

    XCTAssertTrue(inputs.isEmpty)
  }
}
