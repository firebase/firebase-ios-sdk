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

@testable import FirebaseAILogic
import XCTest

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class InternalPartTests: XCTestCase {
  let decoder = JSONDecoder()

  func testDecodeTextPartWithThought() throws {
    let json = """
    {
      "text": "This is a thought.",
      "thought": true
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertEqual(part.isThought, true)
    guard case let .text(text) = part.data else {
      XCTFail("Decoded part is not a text part.")
      return
    }
    XCTAssertEqual(text, "This is a thought.")
  }

  func testDecodeTextPartWithoutThought() throws {
    let json = """
    {
      "text": "This is not a thought."
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertNil(part.isThought)
    guard case let .text(text) = part.data else {
      XCTFail("Decoded part is not a text part.")
      return
    }
    XCTAssertEqual(text, "This is not a thought.")
  }

  func testDecodeInlineDataPartWithThought() throws {
    let imageBase64 =
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+P+/HgAFhAJ/wlseKgAAAABJRU5ErkJggg=="
    let mimeType = "image/png"
    let json = """
    {
      "inlineData": {
        "mimeType": "\(mimeType)",
        "data": "\(imageBase64)"
      },
      "thought": true
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertEqual(part.isThought, true)
    guard case let .inlineData(inlineData) = part.data else {
      XCTFail("Decoded part is not an inlineData part.")
      return
    }
    XCTAssertEqual(inlineData.mimeType, mimeType)
    XCTAssertEqual(inlineData.data, Data(base64Encoded: imageBase64))
  }

  func testDecodeInlineDataPartWithoutThought() throws {
    let imageBase64 = "aGVsbG8="
    let mimeType = "image/png"
    let json = """
    {
      "inlineData": {
        "mimeType": "\(mimeType)",
        "data": "\(imageBase64)"
      }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertNil(part.isThought)
    guard case let .inlineData(inlineData) = part.data else {
      XCTFail("Decoded part is not an inlineData part.")
      return
    }
    XCTAssertEqual(inlineData.mimeType, mimeType)
    XCTAssertEqual(inlineData.data, Data(base64Encoded: imageBase64))
  }

  func testDecodeFileDataPartWithThought() throws {
    let uri = "file:///path/to/file.mp3"
    let mimeType = "audio/mpeg"
    let json = """
    {
      "fileData": {
        "fileUri": "\(uri)",
        "mimeType": "\(mimeType)"
      },
      "thought": true
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertEqual(part.isThought, true)
    guard case let .fileData(fileData) = part.data else {
      XCTFail("Decoded part is not a fileData part.")
      return
    }
    XCTAssertEqual(fileData.fileURI, uri)
    XCTAssertEqual(fileData.mimeType, mimeType)
  }

  func testDecodeFileDataPartWithoutThought() throws {
    let uri = "file:///path/to/file.mp3"
    let mimeType = "audio/mpeg"
    let json = """
    {
      "fileData": {
        "fileUri": "\(uri)",
        "mimeType": "\(mimeType)"
      }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertNil(part.isThought)
    guard case let .fileData(fileData) = part.data else {
      XCTFail("Decoded part is not a fileData part.")
      return
    }
    XCTAssertEqual(fileData.fileURI, uri)
    XCTAssertEqual(fileData.mimeType, mimeType)
  }

  func testDecodeFunctionCallPartWithThoughtSignature() throws {
    let functionName = "someFunction"
    let expectedThoughtSignature = "some_signature"
    let json = """
    {
      "functionCall": {
        "name": "\(functionName)",
        "args": {
          "arg1": "value1"
        },
      },
      "thoughtSignature": "\(expectedThoughtSignature)"
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(InternalPart.self, from: jsonData)

    let thoughtSignature = try XCTUnwrap(part.thoughtSignature)
    XCTAssertEqual(thoughtSignature, expectedThoughtSignature)
    XCTAssertNil(part.isThought)
    guard case let .functionCall(functionCall) = part.data else {
      XCTFail("Decoded part is not a functionCall part.")
      return
    }
    XCTAssertEqual(functionCall.name, functionName)
    XCTAssertEqual(functionCall.args, ["arg1": .string("value1")])
  }

  func testDecodeFunctionCallPartWithoutThoughtSignature() throws {
    let functionName = "someFunction"
    let json = """
    {
      "functionCall": {
        "name": "\(functionName)",
        "args": {
          "arg1": "value1"
        }
      }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertNil(part.isThought)
    XCTAssertNil(part.thoughtSignature)
    guard case let .functionCall(functionCall) = part.data else {
      XCTFail("Decoded part is not a functionCall part.")
      return
    }
    XCTAssertEqual(functionCall.name, functionName)
    XCTAssertEqual(functionCall.args, ["arg1": .string("value1")])
  }

  func testDecodeFunctionCallPartWithoutArgs() throws {
    let functionName = "someFunction"
    let json = """
    {
      "functionCall": {
        "name": "\(functionName)"
      }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertNil(part.isThought)
    XCTAssertNil(part.thoughtSignature)
    guard case let .functionCall(functionCall) = part.data else {
      XCTFail("Decoded part is not a functionCall part.")
      return
    }
    XCTAssertEqual(functionCall.name, functionName)
    XCTAssertEqual(functionCall.args, JSONObject())
  }

  func testDecodeFunctionResponsePartWithThought() throws {
    let functionName = "someFunction"
    let json = """
    {
      "functionResponse": {
        "name": "\(functionName)",
        "response": {
          "output": "someValue"
        }
      },
      "thought": true
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertEqual(part.isThought, true)
    guard case let .functionResponse(functionResponse) = part.data else {
      XCTFail("Decoded part is not a functionResponse part.")
      return
    }
    XCTAssertEqual(functionResponse.name, functionName)
    XCTAssertEqual(functionResponse.response, ["output": .string("someValue")])
  }

  func testDecodeFunctionResponsePartWithoutThought() throws {
    let functionName = "someFunction"
    let json = """
    {
      "functionResponse": {
        "name": "\(functionName)",
        "response": {
          "output": "someValue"
        }
      }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertNil(part.isThought)
    guard case let .functionResponse(functionResponse) = part.data else {
      XCTFail("Decoded part is not a functionResponse part.")
      return
    }
    XCTAssertEqual(functionResponse.name, functionName)
    XCTAssertEqual(functionResponse.response, ["output": .string("someValue")])
  }

  func testDecodeExecutableCodePartWithThought() throws {
    let json = """
    {
      "executableCode": {
        "language": "PYTHON",
        "code": "print('hello')"
      },
      "thought": true
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertEqual(part.isThought, true)
    guard case let .executableCode(executableCode) = part.data else {
      XCTFail("Decoded part is not an executableCode part.")
      return
    }
    XCTAssertEqual(executableCode.language, .init(kind: .python))
    XCTAssertEqual(executableCode.code, "print('hello')")
  }

  func testDecodeExecutableCodePartWithoutThought() throws {
    let json = """
    {
      "executableCode": {
        "language": "PYTHON",
        "code": "print('hello')"
      }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertNil(part.isThought)
    guard case let .executableCode(executableCode) = part.data else {
      XCTFail("Decoded part is not an executableCode part.")
      return
    }
    XCTAssertEqual(executableCode.language, .init(kind: .python))
    XCTAssertEqual(executableCode.code, "print('hello')")
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

    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertNil(part.isThought)
    guard case let .executableCode(executableCode) = part.data else {
      XCTFail("Decoded part is not an executableCode part.")
      return
    }
    XCTAssertNil(executableCode.language)
    XCTAssertEqual(executableCode.code, "print('hello')")
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

    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertNil(part.isThought)
    guard case let .executableCode(executableCode) = part.data else {
      XCTFail("Decoded part is not an executableCode part.")
      return
    }
    XCTAssertEqual(executableCode.language, .init(kind: .python))
    XCTAssertNil(executableCode.code)
  }

  func testDecodeExecutableCodePart_missingLanguageAndCode() throws {
    let json = """
    {
      "executableCode": {}
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertNil(part.isThought)
    guard case let .executableCode(executableCode) = part.data else {
      XCTFail("Decoded part is not an executableCode part.")
      return
    }
    XCTAssertNil(executableCode.language)
    XCTAssertNil(executableCode.code)
  }

  func testDecodeCodeExecutionResultPartWithThought() throws {
    let json = """
    {
      "codeExecutionResult": {
        "outcome": "OUTCOME_OK",
        "output": "hello"
      },
      "thought": true
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertEqual(part.isThought, true)
    guard case let .codeExecutionResult(codeExecutionResult) = part.data else {
      XCTFail("Decoded part is not a codeExecutionResult part.")
      return
    }
    XCTAssertEqual(codeExecutionResult.outcome, .init(kind: .ok))
    XCTAssertEqual(codeExecutionResult.output, "hello")
  }

  func testDecodeCodeExecutionResultPartWithoutThought() throws {
    let json = """
    {
      "codeExecutionResult": {
        "outcome": "OUTCOME_OK",
        "output": "hello"
      }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertNil(part.isThought)
    guard case let .codeExecutionResult(codeExecutionResult) = part.data else {
      XCTFail("Decoded part is not a codeExecutionResult part.")
      return
    }
    XCTAssertEqual(codeExecutionResult.outcome, .init(kind: .ok))
    XCTAssertEqual(codeExecutionResult.output, "hello")
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

    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertNil(part.isThought)
    guard case let .codeExecutionResult(codeExecutionResult) = part.data else {
      XCTFail("Decoded part is not a codeExecutionResult part.")
      return
    }
    XCTAssertNil(codeExecutionResult.outcome)
    XCTAssertEqual(codeExecutionResult.output, "hello")
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

    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertNil(part.isThought)
    guard case let .codeExecutionResult(codeExecutionResult) = part.data else {
      XCTFail("Decoded part is not a codeExecutionResult part.")
      return
    }
    XCTAssertEqual(codeExecutionResult.outcome, .init(kind: .ok))
    XCTAssertNil(codeExecutionResult.output)
  }

  func testDecodeCodeExecutionResultPart_missingOutcomeAndOutput() throws {
    let json = """
    {
      "codeExecutionResult": {}
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let part = try decoder.decode(InternalPart.self, from: jsonData)

    XCTAssertNil(part.isThought)
    guard case let .codeExecutionResult(codeExecutionResult) = part.data else {
      XCTFail("Decoded part is not a codeExecutionResult part.")
      return
    }
    XCTAssertNil(codeExecutionResult.outcome)
    XCTAssertNil(codeExecutionResult.output)
  }
}
