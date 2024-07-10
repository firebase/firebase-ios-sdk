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

@testable import FirebaseVertexAI

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class ModelContentTests: XCTestCase {
  let encoder = JSONEncoder()

  override func setUp() {
    encoder.outputFormatting = .init(
      arrayLiteral: .prettyPrinted, .sortedKeys, .withoutEscapingSlashes
    )
  }

  // MARK: ModelContent.Part Encoding

  func testEncodeFileDataPart() throws {
    let mimeType = "image/jpeg"
    let fileURI = "gs://test-bucket/image.jpg"
    let fileDataPart = ModelContent.Part.fileData(mimetype: mimeType, uri: fileURI)

    let jsonData = try encoder.encode(fileDataPart)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "fileData" : {
        "file_uri" : "\(fileURI)",
        "mime_type" : "\(mimeType)"
      }
    }
    """)
  }
}
