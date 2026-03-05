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
@testable import GeneratedFirebaseAI
@testable import TestServer
import XCTest

final class GenerateContentFirebaseTest: FirebaseE2ETestBase {
  func testGenerateContent() async throws {
    let models = Models(apiClient: client)

    let content = [Content(parts: [Part(text: "Hello from Firebase!")], role: "user")]
    let params = GenerateContentParameters(model: "gemini-2.5-flash", contents: content)

    let response = try await models.generateContentInternal(params: params)
    XCTAssertNotNil(response.candidates)
  }
}
