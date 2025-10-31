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

import XCTest

@testable import FirebaseAILogic

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
@available(watchOS, unavailable)
final class VoiceConfigTests: XCTestCase {
  let encoder = JSONEncoder()

  override func setUp() {
    super.setUp()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
  }

  func testEncodeVoiceConfig_prebuiltVoice() throws {
    let voice = VoiceConfig.prebuiltVoiceConfig(
      PrebuiltVoiceConfig(voiceName: "Zephyr")
    )

    let jsonData = try encoder.encode(voice)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "prebuiltVoiceConfig" : {
        "voiceName" : "Zephyr"
      }
    }
    """)
  }

  func testEncodeVoiceConfig_customVoice() throws {
    let voice = VoiceConfig.customVoiceConfig(
      CustomVoiceConfig(customVoiceSample: Data(repeating: 5, count: 5))
    )

    let jsonData = try encoder.encode(voice)

    let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
    XCTAssertEqual(json, """
    {
      "customVoiceConfig" : {
        "customVoiceSample" : "BQUFBQU="
      }
    }
    """)
  }
}
