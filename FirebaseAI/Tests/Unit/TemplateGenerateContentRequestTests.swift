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
import XCTest

@testable import FirebaseAILogic

final class TemplateGenerateContentRequestTests: XCTestCase {
  let encoder = JSONEncoder()

  override func setUp() {
    super.setUp()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
  }

  // MARK: - Function Declarations

  func testInitWithFunctionDeclarations_singleFunction() throws {
    let declaration = FunctionDeclaration(
      name: "fetchWeather",
      description: "Fetches current weather for a city.",
      parameters: ["city": .string()],
      optionalParameters: []
    )
    let tool = Tool.functionDeclarations([declaration])

    let templateTool = try TemplateTool(tool)

    XCTAssertNil(templateTool.googleMaps)
    let functions = try XCTUnwrap(templateTool.templateFunctions)
    XCTAssertEqual(functions.count, 1)
    XCTAssertEqual(functions[0].name, "fetchWeather")
    XCTAssertNil(functions[0].outputSchema)

    let inputSchema = try XCTUnwrap(functions[0].inputSchema)
    XCTAssertEqual(inputSchema["type"], .string("object"))
    XCTAssertEqual(inputSchema["additionalProperties"], .bool(false))
    guard case let .object(properties)? = inputSchema["properties"] else {
      XCTFail("Expected properties object.")
      return
    }
    XCTAssertEqual(properties["city"], .object(["type": .string("string")]))
  }

  func testInitWithFunctionDeclarations_multipleFunctions() throws {
    let declaration1 = FunctionDeclaration(
      name: "funcA",
      description: "First function.",
      parameters: ["paramA": .string()]
    )
    let declaration2 = FunctionDeclaration(
      name: "funcB",
      description: "Second function.",
      parameters: ["paramB": .integer()]
    )
    let tool = Tool.functionDeclarations([declaration1, declaration2])

    let templateTool = try TemplateTool(tool)

    XCTAssertNil(templateTool.googleMaps)
    let functions = try XCTUnwrap(templateTool.templateFunctions)
    XCTAssertEqual(functions.count, 2)
    XCTAssertEqual(functions[0].name, "funcA")
    XCTAssertEqual(functions[1].name, "funcB")
  }

  func testEncodingTemplateTool_functionDeclarations() throws {
    let declaration = FunctionDeclaration(
      name: "getGreeting",
      description: "Returns greeting.",
      parameters: ["name": .string()]
    )
    let tool = Tool.functionDeclarations([declaration])
    let templateTool = try TemplateTool(tool)

    let jsonData = try encoder.encode(templateTool)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "templateFunctions" : [
        {
          "inputSchema" : {
            "additionalProperties" : false,
            "properties" : {
              "name" : {
                "type" : "string"
              }
            },
            "required" : [
              "name"
            ],
            "type" : "object"
          },
          "name" : "getGreeting"
        }
      ]
    }
    """)
  }

  // MARK: - Google Maps

  func testInitWithGoogleMaps() throws {
    let tool = Tool.googleMaps()

    let templateTool = try TemplateTool(tool)

    XCTAssertNil(templateTool.templateFunctions)
    let maps = try XCTUnwrap(templateTool.googleMaps)
    XCTAssertNil(maps.enableWidget)
  }

  func testEncodingTemplateTool_googleMaps() throws {
    let tool = Tool.googleMaps()
    let templateTool = try TemplateTool(tool)

    let jsonData = try encoder.encode(templateTool)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "googleMaps" : {

      }
    }
    """)
  }

  // MARK: - Unsupported Tools

  func testInitWithUnsupportedTool_googleSearch() {
    let tool = Tool.googleSearch()

    XCTAssertThrowsError(try TemplateTool(tool)) { error in
      guard case EncodingError.invalidValue = error else {
        XCTFail("Expected EncodingError.invalidValue, got: \(error)")
        return
      }
    }
  }

  func testInitWithUnsupportedTool_codeExecution() {
    let tool = Tool.codeExecution()

    XCTAssertThrowsError(try TemplateTool(tool)) { error in
      guard case EncodingError.invalidValue = error else {
        XCTFail("Expected EncodingError.invalidValue, got: \(error)")
        return
      }
    }
  }

  func testInitWithUnsupportedTool_urlContext() {
    let tool = Tool.urlContext()

    XCTAssertThrowsError(try TemplateTool(tool)) { error in
      guard case EncodingError.invalidValue = error else {
        XCTFail("Expected EncodingError.invalidValue, got: \(error)")
        return
      }
    }
  }

  // MARK: - Single Tool Constraint

  func testInitWithEmptyTool() {
    let tool = Tool()

    XCTAssertThrowsError(try TemplateTool(tool)) { error in
      guard case EncodingError.invalidValue = error else {
        XCTFail("Expected EncodingError.invalidValue, got: \(error)")
        return
      }
    }
  }

  func testInitWithMultipleToolTypes() {
    let declaration = FunctionDeclaration(
      name: "dummy",
      description: "dummy",
      parameters: [:]
    )
    let tool = Tool(
      functionDeclarations: [declaration],
      googleMaps: GoogleMaps()
    )

    XCTAssertThrowsError(try TemplateTool(tool)) { error in
      guard case EncodingError.invalidValue = error else {
        XCTFail("Expected EncodingError.invalidValue, got: \(error)")
        return
      }
    }
  }
}
