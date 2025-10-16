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
final class ToolTests: XCTestCase {
  let encoder = JSONEncoder()

  override func setUp() {
    super.setUp()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
  }

  func testEncodeTool_googleSearch() throws {
    let tool = Tool.googleSearch()

    let jsonData = try encoder.encode(tool)

    let jsonString = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(jsonString, """
    {
      "googleSearch" : {

      }
    }
    """)
  }

  func testEncodeTool_codeExecution() throws {
    let tool = Tool.codeExecution()

    let jsonData = try encoder.encode(tool)

    let jsonString = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(jsonString, """
    {
      "codeExecution" : {

      }
    }
    """)
  }

  func testEncodeTool_functionDeclarations() throws {
    let functionDecl = FunctionDeclaration(
      name: "test_function",
      description: "A test function.",
      parameters: ["param1": .string()]
    )
    let tool = Tool.functionDeclarations([functionDecl])
    let jsonData = try encoder.encode(tool)

    let jsonString = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(jsonString, """
    {
      "functionDeclarations" : [
        {
          "description" : "A test function.",
          "name" : "test_function",
          "parameters" : {
            "nullable" : false,
            "properties" : {
              "param1" : {
                "nullable" : false,
                "type" : "STRING"
              }
            },
            "required" : [
              "param1"
            ],
            "type" : "OBJECT"
          }
        }
      ]
    }
    """)
  }
}
