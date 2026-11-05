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

import FirebaseCore
import XCTest

@testable import FirebaseAILogic

@available(macOS 12.0, *)
@available(watchOS, unavailable)
final class LiveSessionServiceTests: XCTestCase {
  func testDecodeServerMessage_voiceActivity() async throws {
    let service = makeLiveSessionService()

    let serverMessage = try await service.decodeServerMessage(jsonData("""
    {
      "voiceActivity" : {
        "type" : "ACTIVITY_START",
        "audioOffset" : "2.520s"
      }
    }
    """))

    let message = try XCTUnwrap(serverMessage)
    guard case let .voiceActivity(voiceActivity) = message.messageType else {
      XCTFail("Decoded message is not a voiceActivity message.")
      return
    }
    XCTAssertEqual(voiceActivity.type, .activityStart)
    XCTAssertEqual(voiceActivity.audioOffset?.seconds, 2)
    XCTAssertEqual(voiceActivity.audioOffset?.nanos, 520_000_000)
  }

  func testDecodeServerMessage_unsupportedMessageType_isIgnoredAndLogsWarning() async throws {
    var warnings = [(code: AILog.MessageCode, message: String)]()
    AILog.logInterceptor = { level, code, message in
      if level == .warning {
        warnings.append((code, message))
      }
    }
    defer { AILog.logInterceptor = nil }
    let service = makeLiveSessionService()

    // Previously, this threw a `LiveSessionUnsupportedMessageError`, which terminated the
    // `LiveSession.responses` stream.
    let serverMessage = try await service.decodeServerMessage(jsonData("""
    {
      "someFutureMessage" : {
        "someField" : "someValue"
      }
    }
    """))

    XCTAssertNil(serverMessage)
    XCTAssertEqual(warnings.count, 1)
    let warning = try XCTUnwrap(warnings.first)
    XCTAssertEqual(warning.code, .liveSessionUnsupportedMessage)
    XCTAssertContains(warning.message, "someFutureMessage")
  }

  func testDecodeServerMessage_invalidJSON_throws() async throws {
    let service = makeLiveSessionService()
    let data = try jsonData("This is not JSON.")

    await XCTAssertThrowsError {
      _ = try await service.decodeServerMessage(data)
    } errorHandler: { error in
      XCTAssert(
        error is LiveSessionUnsupportedMessageError,
        "Expected LiveSessionUnsupportedMessageError, but got \(error) instead."
      )
    }
  }

  func testDecodeServerMessage_malformedSupportedMessageType_throws() async throws {
    let service = makeLiveSessionService()
    // `voiceActivity` is expected to be an object, not a string.
    let data = try jsonData("""
    {
      "voiceActivity" : "ACTIVITY_START"
    }
    """)

    await XCTAssertThrowsError {
      _ = try await service.decodeServerMessage(data)
    } errorHandler: { error in
      XCTAssert(
        error is LiveSessionUnsupportedMessageError,
        "Expected LiveSessionUnsupportedMessageError, but got \(error) instead."
      )
    }
  }

  // MARK: - Helpers

  private func makeLiveSessionService() -> LiveSessionService {
    return LiveSessionService(
      modelResourceName: "projects/my-project-id/locations/global/publishers/google/models/test",
      generationConfig: nil,
      urlSession: URLSession(configuration: .ephemeral),
      apiConfig: APIConfig(service: .googleAI(endpoint: .firebaseProxyProd), version: .v1beta),
      firebaseInfo: GenerativeModelTestUtil.testFirebaseInfo(),
      tools: nil,
      toolConfig: nil,
      systemInstruction: nil,
      requestOptions: RequestOptions()
    )
  }

  private func jsonData(_ json: String) throws -> Data {
    return try XCTUnwrap(json.data(using: .utf8))
  }
}
