// Copyright 2024 Google LLC
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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class PartTests: XCTestCase {
  let decoder = JSONDecoder()
  let encoder = JSONEncoder()

  override func setUp() {
    encoder.outputFormatting = .init(
      arrayLiteral: .prettyPrinted, .sortedKeys, .withoutEscapingSlashes
    )
  }

  // MARK: - Part Decoding

  func testDecodeTextPart() throws {
    let expectedText = "Hello, world!"
    let json = """
    {
      "text" : "\(expectedText)"
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(TextPart.self, from: jsonData)

    XCTAssertEqual(part.text, expectedText)
  }

  func testDecodeInlineDataPart() throws {
    let imageBase64 = try PartTests.blueSquareImage()
    let mimeType = "image/png"
    let json = """
    {
      "inlineData" : {
        "data" : "\(imageBase64)",
        "mimeType" : "\(mimeType)"
      }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(InlineDataPart.self, from: jsonData)

    XCTAssertEqual(part.data, Data(base64Encoded: imageBase64))
    XCTAssertEqual(part.mimeType, mimeType)
  }

  func testDecodeFunctionResponsePart() throws {
    let functionName = "test-function-name"
    let resultParameter = "test-result-parameter"
    let resultValue = "test-result-value"
    let json = """
    {
      "functionResponse" : {
        "name" : "\(functionName)",
        "response" : {
          "\(resultParameter)" : "\(resultValue)"
        }
      }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(FunctionResponsePart.self, from: jsonData)

    let functionResponse = part.functionResponse
    XCTAssertEqual(functionResponse.name, functionName)
    XCTAssertEqual(functionResponse.response, [resultParameter: .string(resultValue)])
  }

  func testDecodeExecutableCodePart() throws {
    let json = """
    {
      "executableCode": {
        "language": "PYTHON",
        "code": "print('hello')"
      }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(ExecutableCodePart.self, from: jsonData)

    XCTAssertEqual(part.language, .python)
    XCTAssertEqual(part.code, "print('hello')")
  }

  func testDecodeExecutableCodePart_missingLanguage() throws {
    let json = """
    {
      "executableCode": {
        "code": "print('hello')"
      }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(ExecutableCodePart.self, from: jsonData)

    XCTAssertEqual(part.language.description, "LANGUAGE_UNSPECIFIED")
    XCTAssertEqual(part.code, "print('hello')")
  }

  func testDecodeExecutableCodePart_missingCode() throws {
    let json = """
    {
      "executableCode": {
        "language": "PYTHON"
      }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(ExecutableCodePart.self, from: jsonData)

    XCTAssertEqual(part.language, .python)
    XCTAssertEqual(part.code, "")
  }

  func testDecodeExecutableCodePart_missingLanguageAndCode() throws {
    let json = """
    {
      "executableCode": {}
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(ExecutableCodePart.self, from: jsonData)

    XCTAssertEqual(part.language.description, "LANGUAGE_UNSPECIFIED")
    XCTAssertEqual(part.code, "")
  }

  func testDecodeCodeExecutionResultPart() throws {
    let json = """
    {
      "codeExecutionResult": {
        "outcome": "OUTCOME_OK",
        "output": "hello"
      }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(CodeExecutionResultPart.self, from: jsonData)

    XCTAssertEqual(part.outcome, .ok)
    XCTAssertEqual(part.output, "hello")
  }

  func testDecodeCodeExecutionResultPart_missingOutcome() throws {
    let json = """
    {
      "codeExecutionResult": {
        "output": "hello"
      }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(CodeExecutionResultPart.self, from: jsonData)

    XCTAssertEqual(part.outcome.description, "OUTCOME_UNSPECIFIED")
    XCTAssertEqual(part.output, "hello")
  }

  func testDecodeCodeExecutionResultPart_missingOutput() throws {
    let json = """
    {
      "codeExecutionResult": {
        "outcome": "OUTCOME_OK"
      }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(CodeExecutionResultPart.self, from: jsonData)

    XCTAssertEqual(part.outcome, .ok)
    XCTAssertNil(part.output)
  }

  func testDecodeCodeExecutionResultPart_missingOutcomeAndOutput() throws {
    let json = """
    {
      "codeExecutionResult": {}
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(CodeExecutionResultPart.self, from: jsonData)

    XCTAssertEqual(part.outcome.description, "OUTCOME_UNSPECIFIED")
    XCTAssertNil(part.output)
  }

  // MARK: - Part Encoding

  func testEncodeTextPart() throws {
    let expectedText = "Hello, world!"
    let textPart = TextPart(expectedText)

    let jsonData = try encoder.encode(textPart)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "text" : "\(expectedText)"
    }
    """)
  }

  func testEncodeInlineDataPart() throws {
    let mimeType = "image/png"
    let imageBase64 = try PartTests.blueSquareImage()
    let imageBase64Data = Data(base64Encoded: imageBase64)
    let inlineDataPart = InlineDataPart(data: imageBase64Data!, mimeType: mimeType)

    let jsonData = try encoder.encode(inlineDataPart)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "inlineData" : {
        "data" : "\(imageBase64)",
        "mimeType" : "\(mimeType)"
      }
    }
    """)
  }

  func testEncodeFileDataPart() throws {
    let mimeType = "image/jpeg"
    let fileURI = "gs://test-bucket/image.jpg"
    let fileDataPart = FileDataPart(uri: fileURI, mimeType: mimeType)

    let jsonData = try encoder.encode(fileDataPart)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "fileData" : {
        "fileUri" : "\(fileURI)",
        "mimeType" : "\(mimeType)"
      }
    }
    """)
  }

  func testEncodeExecutableCodePart() throws {
    let executableCodePart = ExecutableCodePart(language: .python, code: "print('hello')")

    let jsonData = try encoder.encode(executableCodePart)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "executableCode" : {
        "code" : "print('hello')",
        "language" : "PYTHON"
      }
    }
    """)
  }

  func testEncodeCodeExecutionResultPart() throws {
    let codeExecutionResultPart = CodeExecutionResultPart(outcome: .ok, output: "hello")

    let jsonData = try encoder.encode(codeExecutionResultPart)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "codeExecutionResult" : {
        "outcome" : "OUTCOME_OK",
        "output" : "hello"
      }
    }
    """)
  }

  // MARK: - Helpers

  private static func bundle() -> Bundle {
    #if SWIFT_PACKAGE
      return Bundle.module
    #else // SWIFT_PACKAGE
      return Bundle(for: Self.self)
    #endif // SWIFT_PACKAGE
  }

  private static func blueSquareImage() throws -> String {
    let imageURL = bundle().url(forResource: "blue", withExtension: "png")!
    let imageData = try Data(contentsOf: imageURL)
    return imageData.base64EncodedString()
  }
}
