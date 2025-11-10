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

import Foundation

/// Messages sent by the client in the BidiGenerateContent RPC call.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
enum BidiGenerateContentClientMessage {
  /// Message to be sent in the first and only first client message.
  case setup(BidiGenerateContentSetup)

  /// Incremental update of the current conversation delivered from the client.
  case clientContent(BidiGenerateContentClientContent)

  /// User input that is sent in real time.
  case realtimeInput(BidiGenerateContentRealtimeInput)

  /// Response to a `ToolCallMessage` received from the server.
  case toolResponse(BidiGenerateContentToolResponse)
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
extension BidiGenerateContentClientMessage: Encodable {
  enum CodingKeys: CodingKey {
    case setup
    case clientContent
    case realtimeInput
    case toolResponse
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case let .setup(setup):
      try container.encode(setup, forKey: .setup)
    case let .clientContent(clientContent):
      try container.encode(clientContent, forKey: .clientContent)
    case let .realtimeInput(realtimeInput):
      try container.encode(realtimeInput, forKey: .realtimeInput)
    case let .toolResponse(toolResponse):
      try container.encode(toolResponse, forKey: .toolResponse)
    }
  }
}
