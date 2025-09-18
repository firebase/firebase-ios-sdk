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

import FirebaseAILogic
import FirebaseCore
import XCTest

// These snippet tests are intentionally skipped in CI jobs; see the README file in this directory
// for instructions on running them manually.

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class CountTokensSnippets: XCTestCase {
  let bundle = BundleTestUtil.bundle()
  lazy var model = FirebaseAI.firebaseAI().generativeModel(modelName: "gemini-2.0-flash")
  lazy var imageURL = {
    guard let url = bundle.url(forResource: "blue", withExtension: "png") else {
      fatalError("Image file blue.png not found in Resources.")
    }
    return url
  }()

  lazy var image = {
    guard let imageData = try? Data(contentsOf: imageURL) else {
      fatalError("Failed to load image from URL: \(imageURL)")
    }
    return InlineDataPart(data: imageData, mimeType: "image/png")
  }()

  override func setUpWithError() throws {
    try FirebaseApp.configureDefaultAppForSnippets()
  }

  override func tearDown() async throws {
    await FirebaseApp.deleteDefaultAppForSnippets()
  }

  func testTextOnlyInput() async throws {
    let response = try await model.countTokens("Write a story about a magic backpack.")

    print("Total Tokens: \(response.totalTokens)")
  }

  func testMultimodalInput() async throws {
    let response = try await model.countTokens(image, "What's in this picture?")

    print("Total Tokens: \(response.totalTokens)")
    // Print tokens by modality, for example "TEXT Tokens: 7" and "IMAGE Tokens: 258"
    for promptTokensDetail in response.promptTokensDetails {
      print("\(promptTokensDetail.modality.rawValue) Tokens: \(promptTokensDetail.tokenCount)")
    }
  }
}
