
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

@testable import FirebaseAI
import FirebaseCore
import XCTest

final class TemplateChatSessionTests: XCTestCase {
  var model: TemplateGenerativeModel!

  override func setUp() {
    super.setUp()
    let firebaseInfo = GenerativeModelTestUtil.testFirebaseInfo()
    let generativeAIService = GenerativeAIService(
      firebaseInfo: firebaseInfo,
      urlSession: GenAIURLSession.default
    )
    model = TemplateGenerativeModel(generativeAIService: generativeAIService)
  }

  func testSendMessage() async throws {
    let chat = model.startTemplateChat(template: "test-template")
    let response = try await chat.sendMessage("Hello", variables: ["name": "test"])
    XCTAssertEqual(chat.history.count, 2)
    XCTAssertEqual(chat.history[0].role, "user")
    XCTAssertEqual((chat.history[0].parts.first as? TextPart)?.text, "Hello")
    XCTAssertEqual(chat.history[1].role, "model")
    XCTAssertEqual(response.candidates.count, 1)
  }
}
