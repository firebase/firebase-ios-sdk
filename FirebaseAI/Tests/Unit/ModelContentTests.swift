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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class ModelContentTests: XCTestCase {
  // MARK: - ModelContent Initialization with Part Types

  func testInitWithExecutableCodePart() {
    let executableCodePart = ExecutableCodePart(language: .python, code: "print('hello')")

    let content = ModelContent(role: "model", parts: [executableCodePart])

    XCTAssertEqual(content.role, "model")
    XCTAssertEqual(content.parts.count, 1)
    guard let resultPart = content.parts.first as? ExecutableCodePart else {
      XCTFail("Expected ExecutableCodePart")
      return
    }
    XCTAssertEqual(resultPart.language, .python)
    XCTAssertEqual(resultPart.code, "print('hello')")
  }

  func testInitWithCodeExecutionResultPart() {
    let codeExecutionResultPart = CodeExecutionResultPart(outcome: .ok, output: "hello")

    let content = ModelContent(role: "model", parts: [codeExecutionResultPart])

    XCTAssertEqual(content.role, "model")
    XCTAssertEqual(content.parts.count, 1)
    guard let resultPart = content.parts.first as? CodeExecutionResultPart else {
      XCTFail("Expected CodeExecutionResultPart")
      return
    }
    XCTAssertEqual(resultPart.outcome, .ok)
    XCTAssertEqual(resultPart.output, "hello")
  }

  func testInitWithMixedPartsIncludingExecutableCode() {
    let textPart = TextPart("Here is some code:")
    let executableCodePart = ExecutableCodePart(language: .python, code: "x = 1 + 2")
    let codeExecutionResultPart = CodeExecutionResultPart(outcome: .ok, output: "3")

    let content = ModelContent(
      role: "model",
      parts: [textPart, executableCodePart, codeExecutionResultPart]
    )

    XCTAssertEqual(content.role, "model")
    XCTAssertEqual(content.parts.count, 3)

    // Verify each part type
    XCTAssertTrue(content.parts[0] is TextPart)
    XCTAssertTrue(content.parts[1] is ExecutableCodePart)
    XCTAssertTrue(content.parts[2] is CodeExecutionResultPart)
  }

  func testInitWithExecutableCodePartPreservesThoughtMetadata() {
    // Test that thought-related metadata is preserved through the conversion
    let pythonLanguage = ExecutableCodePart.Language.python
    let executableCode = ExecutableCode(
      language: pythonLanguage.internalLanguage,
      code: "print('test')"
    )
    let internalExecutableCodePart = ExecutableCodePart(
      executableCode,
      isThought: true,
      thoughtSignature: "some-signature"
    )

    let content = ModelContent(role: "model", parts: [internalExecutableCodePart])

    guard let resultPart = content.parts.first as? ExecutableCodePart else {
      XCTFail("Expected ExecutableCodePart")
      return
    }

    // Verify the part maintains its properties after round-trip
    XCTAssertEqual(resultPart.language, internalExecutableCodePart.language)
    XCTAssertEqual(resultPart.code, internalExecutableCodePart.code)
    XCTAssertTrue(resultPart.isThought)
    XCTAssertEqual(resultPart.thoughtSignature, "some-signature")
  }

  func testInitWithCodeExecutionResultPartWithDeadlockedOutcome() {
    let codeExecutionResultPart = CodeExecutionResultPart(outcome: .deadlineExceeded, output: nil)

    let content = ModelContent(role: "model", parts: [codeExecutionResultPart])

    guard let resultPart = content.parts.first as? CodeExecutionResultPart else {
      XCTFail("Expected CodeExecutionResultPart")
      return
    }
    XCTAssertEqual(resultPart.outcome, .deadlineExceeded)
    XCTAssertNil(resultPart.output)
  }
}
