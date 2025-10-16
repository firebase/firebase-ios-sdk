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
final class BidiGenerateContentServerMessageTests: XCTestCase {
  let decoder = JSONDecoder()

  func testDecodeBidiGenerateContentServerMessage_setupComplete() throws {
    let json = """
    {
      "setupComplete" : {}
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let serverMessage = try decoder.decode(BidiGenerateContentServerMessage.self, from: jsonData)
    guard case .setupComplete = serverMessage.messageType else {
      XCTFail("Decoded message is not a setupComplete message.")
      return
    }
  }

  func testDecodeBidiGenerateContentServerMessage_serverContent() throws {
    let json = """
    {
      "serverContent" : {
        "modelTurn" : {
          "parts" : [
            {
              "inlineData" : {
                "data" : "BQUFBQU=",
                "mimeType" : "audio/pcm"
              }
            }
          ],
          "role" : "model"
        },
        "turnComplete": true,
        "groundingMetadata": {
          "webSearchQueries": ["query1", "query2"],
          "groundingChunks": [
            { "web": { "uri": "uri1", "title": "title1" } }
          ],
          "groundingSupports": [
            { "segment": { "endIndex": 10, "text": "text" }, "groundingChunkIndices": [0] }
          ],
          "searchEntryPoint": { "renderedContent": "html" }
        },
        "inputTranscription": {
          "text": "What day of the week is it?"
        },
        "outputTranscription": {
          "text": "Today is friday"
        }
      }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let serverMessage = try decoder.decode(BidiGenerateContentServerMessage.self, from: jsonData)
    guard case let .serverContent(serverContent) = serverMessage.messageType else {
      XCTFail("Decoded message is not a serverContent message.")
      return
    }

    XCTAssertEqual(serverContent.turnComplete, true)
    XCTAssertNil(serverContent.interrupted)
    XCTAssertNil(serverContent.generationComplete)

    let modelTurn = try XCTUnwrap(serverContent.modelTurn)
    XCTAssertEqual(modelTurn.role, "model")
    XCTAssertEqual(modelTurn.parts.count, 1)
    let part = try XCTUnwrap(modelTurn.parts.first as? InlineDataPart)
    XCTAssertEqual(part.data, Data(repeating: 5, count: 5))
    XCTAssertEqual(part.mimeType, "audio/pcm")

    let metadata = try XCTUnwrap(serverContent.groundingMetadata)
    XCTAssertEqual(metadata.webSearchQueries, ["query1", "query2"])
    XCTAssertEqual(metadata.groundingChunks.count, 1)
    let groundingChunk = try XCTUnwrap(metadata.groundingChunks.first)
    let webChunk = try XCTUnwrap(groundingChunk.web)
    XCTAssertEqual(webChunk.uri, "uri1")
    XCTAssertEqual(metadata.groundingSupports.count, 1)
    let groundingSupport = try XCTUnwrap(metadata.groundingSupports.first)
    XCTAssertEqual(groundingSupport.segment.startIndex, 0)
    XCTAssertEqual(groundingSupport.segment.partIndex, 0)
    XCTAssertEqual(groundingSupport.segment.endIndex, 10)
    XCTAssertEqual(groundingSupport.segment.text, "text")
    let searchEntryPoint = try XCTUnwrap(metadata.searchEntryPoint)
    XCTAssertEqual(searchEntryPoint.renderedContent, "html")

    let inputTranscription = try XCTUnwrap(serverContent.inputTranscription)
    XCTAssertEqual(inputTranscription.text, "What day of the week is it?")

    let outputTranscription = try XCTUnwrap(serverContent.outputTranscription)
    XCTAssertEqual(outputTranscription.text, "Today is friday")
  }

  func testDecodeBidiGenerateContentServerMessage_toolCall() throws {
    let json = """
    {
      "toolCall" : {
        "functionCalls" : [
          {
            "name": "changeBackgroundColor",
            "id": "functionCall-12345-67890",
            "args" : {
              "color": "#F54927"
            }
          }
        ]
      }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let serverMessage = try decoder.decode(BidiGenerateContentServerMessage.self, from: jsonData)
    guard case let .toolCall(toolCall) = serverMessage.messageType else {
      XCTFail("Decoded message is not a toolCall message.")
      return
    }

    let functionCalls = try XCTUnwrap(toolCall.functionCalls)
    XCTAssertEqual(functionCalls.count, 1)
    let functionCall = try XCTUnwrap(functionCalls.first)
    XCTAssertEqual(functionCall.name, "changeBackgroundColor")
    XCTAssertEqual(functionCall.id, "functionCall-12345-67890")
    let args = try XCTUnwrap(functionCall.args)
    guard case let .string(color) = args["color"] else {
      XCTFail("Missing color argument")
      return
    }
    XCTAssertEqual(color, "#F54927")
  }

  func testDecodeBidiGenerateContentServerMessage_toolCallCancellation() throws {
    let json = """
    {
      "toolCallCancellation" : {
        "ids" : ["functionCall-12345-67890"]
      }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let serverMessage = try decoder.decode(BidiGenerateContentServerMessage.self, from: jsonData)
    guard case let .toolCallCancellation(toolCallCancellation) = serverMessage.messageType else {
      XCTFail("Decoded message is not a toolCallCancellation message.")
      return
    }

    let ids = try XCTUnwrap(toolCallCancellation.ids)
    XCTAssertEqual(ids, ["functionCall-12345-67890"])
  }

  func testDecodeBidiGenerateContentServerMessage_goAway() throws {
    let json = """
    {
      "goAway" : {
        "timeLeft": "1.23456789s"
      }
    }
    """
    let jsonData = try XCTUnwrap(json.data(using: .utf8))

    let serverMessage = try decoder.decode(BidiGenerateContentServerMessage.self, from: jsonData)
    guard case let .goAway(goAway) = serverMessage.messageType else {
      XCTFail("Decoded message is not a goAway message.")
      return
    }

    XCTAssertEqual(goAway.timeLeft?.seconds, 1)
    XCTAssertEqual(goAway.timeLeft?.nanos, 234_567_890)
  }
}
