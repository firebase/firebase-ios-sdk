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
import XCTest

@available(watchOS, unavailable)
final class SpeechConfigTests: XCTestCase {
  func testSingleSpeakerConstructor_setsVoiceAndLanguageCode() {
    let config = SpeechConfig(voiceName: "Charon", languageCode: "en-US")
    XCTAssertEqual(
      config.speechConfig.voiceConfig,
      .prebuiltVoiceConfig(.init(voiceName: "Charon"))
    )
    XCTAssertEqual(config.speechConfig.languageCode, "en-US")
    XCTAssertNil(config.speechConfig.multiSpeakerConfig)
  }

  func testSingleSpeakerConstructor_defaultLanguageCode() {
    let config = SpeechConfig(voiceName: "Charon")
    XCTAssertEqual(
      config.speechConfig.voiceConfig,
      .prebuiltVoiceConfig(.init(voiceName: "Charon"))
    )
    XCTAssertNil(config.speechConfig.languageCode)
    XCTAssertNil(config.speechConfig.multiSpeakerConfig)
  }

  func testMultiSpeakerConstructor_setsConfigAndLanguageCode() {
    let speakerConfigs = [
      SpeakerVoiceConfig(speaker: "Joe", voiceName: "Charon"),
      SpeakerVoiceConfig(speaker: "Jane", voiceName: "Charon"),
    ]
    let multiConfig = MultiSpeakerVoiceConfig(speakerVoiceConfigs: speakerConfigs)
    let config = SpeechConfig(multiSpeakerConfig: multiConfig, languageCode: "en-US")
    XCTAssertEqual(config.speechConfig.multiSpeakerConfig, multiConfig.multiSpeakerVoiceConfig)
    XCTAssertEqual(config.speechConfig.languageCode, "en-US")
    XCTAssertNil(config.speechConfig.voiceConfig)
  }

  func testMultiSpeakerConstructor_defaultLanguageCode() {
    let speakerConfigs = [
      SpeakerVoiceConfig(speaker: "Joe", voiceName: "Charon"),
      SpeakerVoiceConfig(speaker: "Jane", voiceName: "Charon"),
    ]
    let multiConfig = MultiSpeakerVoiceConfig(speakerVoiceConfigs: speakerConfigs)
    let config = SpeechConfig(multiSpeakerConfig: multiConfig)
    XCTAssertEqual(config.speechConfig.multiSpeakerConfig, multiConfig.multiSpeakerVoiceConfig)
    XCTAssertNil(config.speechConfig.languageCode)
    XCTAssertNil(config.speechConfig.voiceConfig)
  }
}
