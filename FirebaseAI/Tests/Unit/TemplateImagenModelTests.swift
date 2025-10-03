
// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law of or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import FirebaseAI
import XCTest

final class TemplateImagenModelTests: XCTestCase {
  var model: TemplateImagenModel!

  override func setUp() {
    super.setUp()
    let firebaseInfo = GenerativeModelTestUtil.testFirebaseInfo()
    let generativeAIService = GenerativeAIService(
      firebaseInfo: firebaseInfo,
      urlSession: GenAIURLSession.default
    )
    model = TemplateImagenModel(generativeAIService: generativeAIService)
  }

  func testTemplateImagenGenerateImages() async throws {
    let response = try await model.templateImagenGenerateImages(
      template: "test-template",
      variables: ["prompt": "a cat picture"]
    )
    XCTAssertEqual(response.images.count, 0)
  }
}
