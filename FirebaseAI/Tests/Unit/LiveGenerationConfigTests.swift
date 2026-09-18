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

@testable import FirebaseAILogic
import Foundation
import XCTest

@available(watchOS, unavailable)
final class LiveGenerationConfigTests: XCTestCase {
  let encoder = JSONEncoder()

  override func setUp() {
    encoder.outputFormatting = .init(
      arrayLiteral: .prettyPrinted, .sortedKeys, .withoutEscapingSlashes
    )
  }

  func testEncodeLiveGenerationConfig_speechConfig() throws {
    let testCases: [(LiveGenerationConfig, String)] = [
      (
        LiveGenerationConfig(speech: SpeechConfig(voiceName: "Charon")),
        """
        "speechConfig" : {
            "voiceConfig" : {
              "prebuiltVoiceConfig" : {
                "voiceName" : "Charon"
              }
            }
          }
        """
      ),
      (
        LiveGenerationConfig(speech: SpeechConfig(voiceName: "Charon", languageCode: "en-US")),
        """
        "speechConfig" : {
            "languageCode" : "en-US",
            "voiceConfig" : {
              "prebuiltVoiceConfig" : {
                "voiceName" : "Charon"
              }
            }
          }
        """
      ),
      // Note: While multiSpeakerVoiceConfig is not supported by the Live API, we still
      // test that the underlying model correctly encodes this configuration in case
      // future support is added, or to verify encoding behavior.
      (
        LiveGenerationConfig(speech: SpeechConfig(
          multiSpeakerVoiceConfig: MultiSpeakerVoiceConfig(speakerVoiceConfigs: [
            SpeakerVoiceConfig(speaker: "Speaker1", voiceName: "Puck"),
            SpeakerVoiceConfig(speaker: "Speaker2", voiceName: "Charon"),
          ]),
          languageCode: "en-US"
        )),
        """
        "speechConfig" : {
            "languageCode" : "en-US",
            "multiSpeakerVoiceConfig" : {
              "speakerVoiceConfigs" : [
                {
                  "speaker" : "Speaker1",
                  "voiceConfig" : {
                    "prebuiltVoiceConfig" : {
                      "voiceName" : "Puck"
                    }
                  }
                },
                {
                  "speaker" : "Speaker2",
                  "voiceConfig" : {
                    "prebuiltVoiceConfig" : {
                      "voiceName" : "Charon"
                    }
                  }
                }
              ]
            }
          }
        """
      ),
    ]

    for (liveConfig, expectedJSONSnippet) in testCases {
      let jsonData = try encoder.encode(liveConfig.bidiGenerationConfig)
      let json = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
      XCTAssertEqual(json, """
      {
        \(expectedJSONSnippet)
      }
      """)
    }
  }
}
