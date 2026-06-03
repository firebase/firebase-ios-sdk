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

import FirebaseAILogic
import XCTest

#if compiler(>=6.2.3)
  @testable import FirebaseAILogic
  import XCTest

  final class GeneratedContentTests: XCTestCase {
    func testJsonString_null() throws {
      let content = FirebaseAI.GeneratedContent(kind: .null, isComplete: true)
      XCTAssertEqual(content.jsonString, "null")
    }

    func testJsonString_bool() throws {
      let contentTrue = FirebaseAI.GeneratedContent(kind: .bool(true), isComplete: true)
      XCTAssertEqual(contentTrue.jsonString, "true")

      let contentFalse = FirebaseAI.GeneratedContent(kind: .bool(false), isComplete: true)
      XCTAssertEqual(contentFalse.jsonString, "false")
    }

    func testJsonString_number() throws {
      let content = FirebaseAI.GeneratedContent(kind: .number(123.45), isComplete: true)
      XCTAssertEqual(content.jsonString, "123.45")
    }

    func testJsonString_string() throws {
      let content = FirebaseAI.GeneratedContent(kind: .string("test-string"), isComplete: true)
      XCTAssertEqual(content.jsonString, "\"test-string\"")
    }

    func testJsonString_array() throws {
      let content = FirebaseAI.GeneratedContent(
        kind: .array([
          FirebaseAI.GeneratedContent(kind: .null, isComplete: true),
          FirebaseAI.GeneratedContent(kind: .bool(true), isComplete: true),
          FirebaseAI.GeneratedContent(kind: .number(12.5), isComplete: true),
          FirebaseAI.GeneratedContent(kind: .string("abc"), isComplete: true),
        ]),
        isComplete: true
      )
      XCTAssertEqual(content.jsonString, "[null, true, 12.5, \"abc\"]")
    }

    func testJsonString_structureWithOrderedKeys() throws {
      let content = FirebaseAI.GeneratedContent(
        kind: .structure(
          properties: [
            "z": FirebaseAI.GeneratedContent(kind: .number(1.5), isComplete: true),
            "a": FirebaseAI.GeneratedContent(kind: .string("first"), isComplete: true),
            "m": FirebaseAI.GeneratedContent(kind: .bool(false), isComplete: true),
          ],
          orderedKeys: ["m", "a", "z"]
        ),
        isComplete: true
      )
      XCTAssertEqual(content.jsonString, "{\"m\": false, \"a\": \"first\", \"z\": 1.5}")
    }

    func testJsonString_structureWithEmptyOrderedKeys() throws {
      let content = FirebaseAI.GeneratedContent(
        kind: .structure(
          properties: [
            "z": FirebaseAI.GeneratedContent(kind: .number(1), isComplete: true),
            "a": FirebaseAI.GeneratedContent(kind: .string("first"), isComplete: true),
          ],
          orderedKeys: []
        ),
        isComplete: true
      )
      XCTAssertEqual(content.jsonString, "{}")
    }

    func testJsonString_structureWithPartialOrderedKeys() throws {
      let content = FirebaseAI.GeneratedContent(
        kind: .structure(
          properties: [
            "z": FirebaseAI.GeneratedContent(kind: .number(1), isComplete: true),
            "a": FirebaseAI.GeneratedContent(kind: .string("first"), isComplete: true),
            "m": FirebaseAI.GeneratedContent(kind: .bool(false), isComplete: true),
          ],
          orderedKeys: ["m"]
        ),
        isComplete: true
      )
      XCTAssertEqual(content.jsonString, "{\"m\": false}")
    }
  }
#endif // compiler(>=6.2.3)
