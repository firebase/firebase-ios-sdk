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

import XCTest

@testable import FirebaseAILogic

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class ImageGenerationInstanceTests: XCTestCase {
  let encoder = JSONEncoder()

  override func setUp() {
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
  }

  // MARK: - Encoding Tests

  func testEncodeInstance() throws {
    let prompt = "An astronaut riding a horse."
    let instance = ImageGenerationInstance(prompt: prompt)

    let jsonData = try encoder.encode(instance)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "prompt" : "\(prompt)"
    }
    """)
  }
}
