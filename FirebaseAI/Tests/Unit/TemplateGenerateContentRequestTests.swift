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

#if compiler(>=6.2.3) && canImport(FoundationModels)
  import FoundationModels
#endif // compiler(>=6.2.3) && canImport(FoundationModels)

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
    let templateTool = TemplateTool.functionDeclarations([declaration])
    let internalTool = try templateTool.toInternal()

    XCTAssertNil(internalTool.googleMaps)
    let functions = try XCTUnwrap(internalTool.templateFunctions)
    XCTAssertEqual(functions.count, 1)
    XCTAssertEqual(functions[0].name, "fetchWeather")

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
    let templateTool = TemplateTool.functionDeclarations([declaration1, declaration2])
    let internalTool = try templateTool.toInternal()

    XCTAssertNil(internalTool.googleMaps)
    let functions = try XCTUnwrap(internalTool.templateFunctions)
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
    let templateTool = TemplateTool.functionDeclarations([declaration])
    let internalTool = try templateTool.toInternal()

    let jsonData = try encoder.encode(internalTool)

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
    let templateTool = TemplateTool.googleMaps()
    let internalTool = try templateTool.toInternal()

    XCTAssertNil(internalTool.templateFunctions)
    XCTAssertNotNil(internalTool.googleMaps)
  }

  func testEncodingTemplateTool_googleMaps() throws {
    let templateTool = TemplateTool.googleMaps()
    let internalTool = try templateTool.toInternal()

    let jsonData = try encoder.encode(internalTool)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "googleMaps" : {

      }
    }
    """)
  }

  // MARK: - Request URL

  private func templateRequest(template: String = "test-template",
                               inputs: [String: TemplateInput] = [:],
                               history: [ModelContent] = [],
                               stream: Bool = false,
                               apiConfig: APIConfig = FirebaseAI.defaultEnterpriseAPIConfig,
                               tools: [TemplateTool.Internal]? = nil,
                               toolConfig: TemplateToolConfig? = nil)
    -> TemplateGenerateContentRequest {
    return TemplateGenerateContentRequest(
      template: template,
      inputs: inputs,
      history: history,
      projectID: "my-project-id",
      stream: stream,
      apiConfig: apiConfig,
      options: RequestOptions(),
      tools: tools,
      toolConfig: toolConfig
    )
  }

  func testGetURL_googleAI() throws {
    let request = templateRequest(
      apiConfig: APIConfig(service: .googleAI(endpoint: .firebaseProxyProd), version: .v1beta)
    )

    let url = try request.getURL()

    XCTAssertEqual(url.absoluteString, """
    https://firebasevertexai.googleapis.com/v1beta/projects/my-project-id\
    /templates/test-template:templateGenerateContent
    """)
  }

  func testGetURL_agentPlatform_includesLocation() throws {
    let request = templateRequest(
      apiConfig: APIConfig(
        service: .enterprise(endpoint: .firebaseProxyProd, location: "us-central1"),
        version: .v1beta
      )
    )

    let url = try request.getURL()

    XCTAssertEqual(url.absoluteString, """
    https://firebasevertexai.googleapis.com/v1beta/projects/my-project-id/locations/us-central1\
    /templates/test-template:templateGenerateContent
    """)
  }

  func testGetURL_stream_usesStreamMethodAndSSEQuery() throws {
    let request = templateRequest(
      stream: true,
      apiConfig: APIConfig(service: .googleAI(endpoint: .firebaseProxyProd), version: .v1beta)
    )

    let url = try request.getURL()

    XCTAssertEqual(url.absoluteString, """
    https://firebasevertexai.googleapis.com/v1beta/projects/my-project-id\
    /templates/test-template:templateStreamGenerateContent?alt=sse
    """)
  }

  func testGetURL_templateIDIsPercentEncoded() throws {
    let request = templateRequest(
      template: "a/b?c#d:e f",
      apiConfig: APIConfig(service: .googleAI(endpoint: .firebaseProxyProd), version: .v1beta)
    )

    let url = try request.getURL()

    XCTAssertEqual(url.absoluteString, """
    https://firebasevertexai.googleapis.com/v1beta/projects/my-project-id\
    /templates/a%2Fb%3Fc%23d%3Ae%20f:templateGenerateContent
    """)
    XCTAssertNil(url.query)
    XCTAssertNil(url.fragment)
  }

  func testGetURL_ordinaryTemplateIDIsUnescaped() throws {
    let request = templateRequest(
      template: "my-template_v1.0.0",
      apiConfig: APIConfig(service: .googleAI(endpoint: .firebaseProxyProd), version: .v1beta)
    )

    let url = try request.getURL()

    XCTAssertTrue(
      url.absoluteString.hasSuffix("/templates/my-template_v1.0.0:templateGenerateContent"),
      "Unexpected URL: \(url.absoluteString)"
    )
  }

  // MARK: - Request Encoding

  func testEncodeRequest_minimal_omitsToolsAndToolConfig() throws {
    let request = templateRequest(inputs: ["name": .string("test")])

    let jsonData = try encoder.encode(request)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "history" : [

      ],
      "inputs" : {
        "name" : "test"
      }
    }
    """)
  }

  func testEncodeRequest_withToolsAndToolConfig() throws {
    let declaration = FunctionDeclaration(
      name: "getGreeting",
      description: "Returns greeting.",
      parameters: ["name": .string()]
    )
    let request = try templateRequest(
      inputs: ["count": .int(2)],
      history: [ModelContent(role: "user", parts: "Hello")],
      tools: [TemplateTool.functionDeclarations([declaration]).toInternal()],
      toolConfig: TemplateToolConfig(retrievalConfig: RetrievalConfig(languageCode: "en_US"))
    )

    let jsonData = try encoder.encode(request)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "history" : [
        {
          "parts" : [
            {
              "text" : "Hello"
            }
          ],
          "role" : "user"
        }
      ],
      "inputs" : {
        "count" : 2
      },
      "toolConfig" : {
        "retrievalConfig" : {
          "languageCode" : "en_US"
        }
      },
      "tools" : [
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
      ]
    }
    """)
  }
}
