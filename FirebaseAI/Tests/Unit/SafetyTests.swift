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

import XCTest

@testable import FirebaseAILogic

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class SafetyTests: XCTestCase {
  let decoder = JSONDecoder()
  let encoder = JSONEncoder()

  override func setUp() {
    encoder.outputFormatting = .init(
      arrayLiteral: .prettyPrinted, .sortedKeys, .withoutEscapingSlashes
    )
  }

  // MARK: - SafetyRating Decoding

  func testDecodeSafetyRating_allFieldsPresent() throws {
    let json = """
    {
      "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
      "probability": "NEGLIGIBLE",
      "probabilityScore": 0.1,
      "severity": "HARM_SEVERITY_LOW",
      "severityScore": 0.2,
      "blocked": true
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))
    let rating = try decoder.decode(SafetyRating.self, from: jsonData)

    XCTAssertEqual(rating.category, .dangerousContent)
    XCTAssertEqual(rating.probability, .negligible)
    XCTAssertEqual(rating.probabilityScore, 0.1)
    XCTAssertEqual(rating.severity, .low)
    XCTAssertEqual(rating.severityScore, 0.2)
    XCTAssertTrue(rating.blocked)
  }

  func testDecodeSafetyRating_missingOptionalFields() throws {
    let json = """
    {
      "category": "HARM_CATEGORY_HARASSMENT",
      "probability": "LOW"
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))
    let rating = try decoder.decode(SafetyRating.self, from: jsonData)

    XCTAssertEqual(rating.category, .harassment)
    XCTAssertEqual(rating.probability, .low)
    XCTAssertEqual(rating.probabilityScore, 0.0)
    XCTAssertEqual(rating.severity, .unspecified)
    XCTAssertEqual(rating.severityScore, 0.0)
    XCTAssertFalse(rating.blocked)
  }

  func testDecodeSafetyRating_unknownEnums() throws {
    let json = """
    {
      "category": "HARM_CATEGORY_UNKNOWN",
      "probability": "UNKNOWN_PROBABILITY",
      "severity": "UNKNOWN_SEVERITY"
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))
    let rating = try decoder.decode(SafetyRating.self, from: jsonData)

    XCTAssertEqual(rating.category.rawValue, "HARM_CATEGORY_UNKNOWN")
    XCTAssertEqual(rating.probability.rawValue, "UNKNOWN_PROBABILITY")
    XCTAssertEqual(rating.severity.rawValue, "UNKNOWN_SEVERITY")
  }

  // MARK: - SafetySetting Encoding

  func testEncodeSafetySetting_allFields() throws {
    let setting = SafetySetting(
      harmCategory: .hateSpeech,
      threshold: .blockMediumAndAbove,
      method: .severity
    )
    let jsonData = try encoder.encode(setting)
    let jsonString = try XCTUnwrap(String(data: jsonData, encoding: .utf8))

    XCTAssertEqual(jsonString, """
    {
      "category" : "HARM_CATEGORY_HATE_SPEECH",
      "method" : "SEVERITY",
      "threshold" : "BLOCK_MEDIUM_AND_ABOVE"
    }
    """)
  }

  func testEncodeSafetySetting_nilMethod() throws {
    let setting = SafetySetting(
      harmCategory: .sexuallyExplicit,
      threshold: .blockOnlyHigh
    )
    let jsonData = try encoder.encode(setting)
    let jsonString = try XCTUnwrap(String(data: jsonData, encoding: .utf8))

    XCTAssertEqual(jsonString, """
    {
      "category" : "HARM_CATEGORY_SEXUALLY_EXPLICIT",
      "threshold" : "BLOCK_ONLY_HIGH"
    }
    """)
  }
}
