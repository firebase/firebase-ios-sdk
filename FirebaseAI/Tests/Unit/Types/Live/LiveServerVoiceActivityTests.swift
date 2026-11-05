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

import XCTest

@testable import FirebaseAILogic

@available(watchOS, unavailable)
final class LiveServerVoiceActivityTests: XCTestCase {
  let decoder = JSONDecoder()

  // MARK: - VoiceActivityType

  func testDecodeVoiceActivityType_activityStart() throws {
    let type = try decodeVoiceActivityType("ACTIVITY_START")

    XCTAssertEqual(type, .activityStart)
  }

  func testDecodeVoiceActivityType_activityEnd() throws {
    let type = try decodeVoiceActivityType("ACTIVITY_END")

    XCTAssertEqual(type, .activityEnd)
  }

  func testDecodeVoiceActivityType_unspecified() throws {
    let type = try decodeVoiceActivityType("TYPE_UNSPECIFIED")

    XCTAssertEqual(type, .unknown)
  }

  func testDecodeVoiceActivityType_unrecognized_logsError() throws {
    var loggedCodes = [AILog.MessageCode]()
    AILog.logInterceptor = { _, code, _ in
      loggedCodes.append(code)
    }
    defer { AILog.logInterceptor = nil }

    let type = try decodeVoiceActivityType("ACTIVITY_PAUSED")

    XCTAssertEqual(type.rawValue, "ACTIVITY_PAUSED")
    XCTAssertEqual(loggedCodes, [.liveSessionUnrecognizedVoiceActivityType])
  }

  func testVoiceActivityType_equatableAndHashable() {
    XCTAssertEqual(VoiceActivityType.activityStart, VoiceActivityType.activityStart)
    XCTAssertNotEqual(VoiceActivityType.activityStart, VoiceActivityType.activityEnd)
    XCTAssertNotEqual(VoiceActivityType.activityStart, VoiceActivityType.unknown)
    XCTAssertNotEqual(VoiceActivityType.activityEnd, VoiceActivityType.unknown)

    let types: Set<VoiceActivityType> = [.activityStart, .activityEnd, .unknown, .activityStart]
    XCTAssertEqual(types.count, 3)
  }

  // MARK: - LiveServerVoiceActivity

  func testLiveServerMessage_voiceActivity_activityStart() throws {
    let voiceActivity = try decodeLiveServerVoiceActivity("""
    {
      "voiceActivity" : {
        "type" : "ACTIVITY_START",
        "audioOffset" : "2.520s"
      }
    }
    """)

    XCTAssertEqual(voiceActivity.type, .activityStart)
    let audioOffset = try XCTUnwrap(voiceActivity.audioOffset)
    XCTAssertEqual(audioOffset, 2.52, accuracy: 1e-9)
  }

  func testLiveServerMessage_voiceActivity_activityEnd() throws {
    let voiceActivity = try decodeLiveServerVoiceActivity("""
    {
      "voiceActivity" : {
        "type" : "ACTIVITY_END",
        "audioOffset" : "3.640s"
      }
    }
    """)

    XCTAssertEqual(voiceActivity.type, .activityEnd)
    let audioOffset = try XCTUnwrap(voiceActivity.audioOffset)
    XCTAssertEqual(audioOffset, 3.64, accuracy: 1e-9)
  }

  func testLiveServerMessage_voiceActivity_wholeSecondAudioOffset() throws {
    let voiceActivity = try decodeLiveServerVoiceActivity("""
    {
      "voiceActivity" : {
        "type" : "ACTIVITY_START",
        "audioOffset" : "12s"
      }
    }
    """)

    let audioOffset = try XCTUnwrap(voiceActivity.audioOffset)
    XCTAssertEqual(audioOffset, 12, accuracy: 1e-9)
  }

  func testLiveServerMessage_voiceActivity_unspecifiedType_isUnknown() throws {
    let voiceActivity = try decodeLiveServerVoiceActivity("""
    {
      "voiceActivity" : {
        "type" : "TYPE_UNSPECIFIED",
        "audioOffset" : "1s"
      }
    }
    """)

    XCTAssertEqual(voiceActivity.type, .unknown)
  }

  func testLiveServerMessage_voiceActivity_unrecognizedType_isUnknown() throws {
    let voiceActivity = try decodeLiveServerVoiceActivity("""
    {
      "voiceActivity" : {
        "type" : "ACTIVITY_PAUSED",
        "audioOffset" : "1.5s"
      }
    }
    """)

    XCTAssertEqual(voiceActivity.type, .unknown)
    let audioOffset = try XCTUnwrap(voiceActivity.audioOffset)
    XCTAssertEqual(audioOffset, 1.5, accuracy: 1e-9)
  }

  func testLiveServerMessage_voiceActivity_missingFields() throws {
    let voiceActivity = try decodeLiveServerVoiceActivity("""
    {
      "voiceActivity" : {}
    }
    """)

    XCTAssertEqual(voiceActivity.type, .unknown)
    XCTAssertNil(voiceActivity.audioOffset)
  }

  func testLiveServerMessage_voiceActivity_usageMetadata() throws {
    let json = """
    {
      "voiceActivity" : {
        "type" : "ACTIVITY_END",
        "audioOffset" : "3.640s"
      },
      "usageMetadata" : {
        "promptTokenCount" : 10,
        "totalTokenCount" : 10
      }
    }
    """
    let liveServerMessage = try decodeLiveServerMessage(json)

    let content = try liveServerContent(from: liveServerMessage)
    let voiceActivity = try XCTUnwrap(content.voiceActivity)
    XCTAssertEqual(voiceActivity.type, .activityEnd)
    let usageMetadata = try XCTUnwrap(liveServerMessage.usageMetadata)
    XCTAssertEqual(usageMetadata.promptTokenCount, 10)
    XCTAssertEqual(usageMetadata.totalTokenCount, 10)
  }

  func testLiveServerMessage_voiceActivity_isDeliveredAsOtherwiseEmptyContent() throws {
    let liveServerMessage = try decodeLiveServerMessage("""
    {
      "voiceActivity" : {
        "type" : "ACTIVITY_START",
        "audioOffset" : "2.520s"
      }
    }
    """)

    let content = try liveServerContent(from: liveServerMessage)
    XCTAssertNotNil(content.voiceActivity)
    XCTAssertNil(content.modelTurn)
    XCTAssertFalse(content.isTurnComplete)
    XCTAssertFalse(content.wasInterrupted)
    XCTAssertFalse(content.isGenerationComplete)
    XCTAssertNil(content.groundingMetadata)
    XCTAssertNil(content.inputAudioTranscription)
    XCTAssertNil(content.outputAudioTranscription)
  }

  func testLiveServerMessage_serverContent_hasNoVoiceActivity() throws {
    let liveServerMessage = try decodeLiveServerMessage("""
    {
      "serverContent" : {
        "turnComplete" : true
      }
    }
    """)

    let content = try liveServerContent(from: liveServerMessage)
    XCTAssertNil(content.voiceActivity)
    XCTAssertTrue(content.isTurnComplete)
  }

  // MARK: - Helpers

  private func decodeVoiceActivityType(_ rawValue: String) throws -> VoiceActivityType {
    let jsonData = try XCTUnwrap("\"\(rawValue)\"".data(using: .utf8))

    return try decoder.decode(VoiceActivityType.self, from: jsonData)
  }

  private func decodeLiveServerMessage(_ json: String) throws -> LiveServerMessage {
    let jsonData = try XCTUnwrap(json.data(using: .utf8))
    let serverMessage = try decoder.decode(BidiGenerateContentServerMessage.self, from: jsonData)

    return try XCTUnwrap(LiveServerMessage(from: serverMessage))
  }

  private func liveServerContent(from liveServerMessage: LiveServerMessage) throws
    -> LiveServerContent {
    guard case let .content(content) = liveServerMessage.payload else {
      return try XCTUnwrap(
        nil,
        "Expected a content payload, but got \(liveServerMessage.payload) instead."
      )
    }

    return content
  }

  private func decodeLiveServerVoiceActivity(_ json: String) throws -> LiveServerVoiceActivity {
    let content = try liveServerContent(from: decodeLiveServerMessage(json))

    return try XCTUnwrap(content.voiceActivity, "Expected the content to have a voice activity.")
  }
}
