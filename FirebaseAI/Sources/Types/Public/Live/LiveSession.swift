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

/// A live WebSocket session, capable of streaming content to and from the model.
///
/// Messages are streamed through ``LiveSession/responses``, and can be sent through either the
/// dedicated realtime API function (such as ``LiveSession/sendAudioRealtime(_:)`` and
/// ``LiveSession/sendTextRealtime(_:)``), or through the incremental API (such as
/// ``LiveSession/sendContent(_:turnComplete:)-6x3ae``).
///
/// To create an instance of this class, see ``LiveGenerativeModel``.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
@available(watchOS, unavailable)
public final class LiveSession: Sendable {
  private let service: LiveSessionService

  /// An asynchronous stream of messages from the server.
  ///
  /// These messages from the incremental updates from the model, for the current conversation.
  public var responses: AsyncThrowingStream<LiveServerMessage, Error> { service.responses }

  init(service: LiveSessionService) {
    self.service = service
  }

  /// Response to a ``LiveServerToolCall`` received from the server.
  ///
  /// This method is used both for the realtime API and the incremental API.
  ///
  /// - Parameters:
  ///   - responses: Client generated function results, matched to their respective
  ///     ``FunctionCallPart`` by the ``FunctionCallPart/functionId`` field.
  public func sendFunctionResponses(_ responses: [FunctionResponsePart]) async {
    let message = BidiGenerateContentToolResponse(
      functionResponses: responses.map { $0.functionResponse }
    )
    await service.send(.toolResponse(message))
  }

  /// Sends an audio input stream to the model, using the realtime API.
  ///
  /// To learn more about audio formats, and the required state they should be provided in, see the
  /// docs on
  /// [Supported audio formats](https://cloud.google.com/vertex-ai/generative-ai/docs/live-api#supported-audio-formats).
  ///
  /// - Parameters:
  ///   - audio: Raw 16-bit PCM audio at 16Hz, used to update the model on the client's
  ///     conversation.
  public func sendAudioRealtime(_ audio: Data) async {
    // TODO: (b/443984790) address when we add RealtimeInputConfig support
    let message = BidiGenerateContentRealtimeInput(
      audio: InlineData(data: audio, mimeType: "audio/pcm")
    )
    await service.send(.realtimeInput(message))
  }

  /// Sends a video input stream to the model, using the realtime API.
  ///
  /// - Parameters:
  ///   - video: Encoded video data, used to update the model on the client's conversation.
  ///   - format: The format that the video was encoded in (eg; `mp4`, `webm`, `wmv`, etc.,).
  // TODO: (b/448671945) Make public after testing and next release
  func sendVideoRealtime(_ video: Data, format: String) async {
    let message = BidiGenerateContentRealtimeInput(
      video: InlineData(data: video, mimeType: "video/\(format)")
    )
    await service.send(.realtimeInput(message))
  }

  /// Sends a text input stream to the model, using the realtime API.
  ///
  /// - Parameters:
  ///   - text: Text content to append to the current client's conversation.
  public func sendTextRealtime(_ text: String) async {
    let message = BidiGenerateContentRealtimeInput(text: text)
    await service.send(.realtimeInput(message))
  }

  /// Incremental update of the current conversation.
  ///
  /// The content is unconditionally appended to the conversation history and used as part of the
  /// prompt to the model to generate content.
  ///
  /// Sending this message will also cause an interruption, if the server is actively generating
  /// content.
  ///
  /// - Parameters:
  ///   - content: Content to append to the current conversation with the model.
  ///   - turnComplete: Whether the server should start generating content with the currently
  ///     accumulated prompt, or await additional messages before starting generation. By default,
  ///     the server will await additional messages.
  public func sendContent(_ content: [ModelContent], turnComplete: Bool = false) async {
    let message = BidiGenerateContentClientContent(turns: content, turnComplete: turnComplete)
    await service.send(.clientContent(message))
  }

  /// Incremental update of the current conversation.
  ///
  /// The content is unconditionally appended to the conversation history and used as part of the
  /// prompt to the model to generate content.
  ///
  /// Sending this message will also cause an interruption, if the server is actively generating
  /// content.
  ///
  /// - Parameters:
  ///   - content: Content to append to the current conversation with the model  (see
  ///     ``PartsRepresentable`` for conforming types).
  ///   - turnComplete: Whether the server should start generating content with the currently
  ///     accumulated prompt, or await additional messages before starting generation. By default,
  ///     the server will await additional messages.
  public func sendContent(_ parts: any PartsRepresentable...,
                          turnComplete: Bool = false) async {
    await sendContent([ModelContent(parts: parts)], turnComplete: turnComplete)
  }

  /// Permanently stop the conversation with the model, and close the connection to the server
  ///
  /// This method will be called automatically when the ``LiveSession`` is deinitialized, but this
  /// method can be called manually to explicitly end the session.
  ///
  /// Attempting to receive content from a closed session will cause a
  /// ``LiveSessionUnexpectedClosureError`` error to be thrown.
  public func close() async {
    await service.close()
  }

  // TODO: b(445716402) Add a start method when we support session resumption
}
