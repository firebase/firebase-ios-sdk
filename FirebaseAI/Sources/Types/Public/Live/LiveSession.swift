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
/// ``LiveSession/sendContent(_:turnComplete:)-(PartsRepresentable...,_)``).
///
/// To create an instance of this class, see ``LiveGenerativeModel``.
@available(watchOS, unavailable)
public final class LiveSession: Sendable {
  private let service: LiveSessionService

  /// An asynchronous stream of messages from the server.
  ///
  /// These messages are the incremental updates from the model for the current conversation.
  ///
  /// The stream throws if the connection closes unexpectedly, and finishes, at the latest, shortly
  /// after the session is deinitialized, so keep a reference to the ``LiveSession`` for as long as
  /// you're consuming this stream.
  public var responses: AsyncThrowingStream<LiveServerMessage, Error> { service.responses }

  init(service: LiveSessionService) {
    self.service = service
  }

  deinit {
    // `LiveSessionService`'s tasks keep it alive until they're cancelled, so it can't close itself
    // once it's no longer referenced. Close it here to cancel those tasks and disconnect the
    // WebSocket; once the tasks end, the service deinitializes, which finishes `responses`. A
    // `Task` is needed because `deinit` can't `await`, and it must capture `service`, not `self`.
    Task { [service] in
      await service.close()
    }
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
  /// [Supported media
  /// formats](https://firebase.google.com/docs/ai-logic/live-api/limits-and-specs#media-formats).
  ///
  /// - Parameters:
  ///   - audio: Raw 16-bit PCM audio at 16Hz, used to update the model on the client's
  ///     conversation.
  public func sendAudioRealtime(_ audio: Data) async {
    let message = BidiGenerateContentRealtimeInput(
      audio: InlineData(data: audio, mimeType: "audio/pcm")
    )
    await service.send(.realtimeInput(message))
  }

  /// Sends a video frame to the model, using the realtime API.
  ///
  /// Instead of raw video data, the model expects individual frames of the video,
  /// sent as images.
  ///
  /// If your video has audio, send it separately through ``LiveSession/sendAudioRealtime(_:)``.
  ///
  /// For better performance, frames can also be sent at a lower rate than the video;
  /// even as low as 1 frame per second.
  ///
  /// - Parameters:
  ///   - video: Encoded image data extracted from a frame of the video, used to update the model on
  ///     the client's conversation.
  ///   - mimeType: The IANA standard MIME type of the video frame data (eg; `images/png`,
  ///     `images/jpeg`etc.,).
  public func sendVideoRealtime(_ video: Data, mimeType: String) async {
    let message = BidiGenerateContentRealtimeInput(
      video: InlineData(data: video, mimeType: mimeType)
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

  /// Manually marks the start of user activity, using the realtime API.
  ///
  /// The start of user activity is effectively the start of a user's turn, but depending on the
  /// configuration defined in ``RealtimeInputConfig``, it may not be interpreted as an
  /// interruption. An example of the start of user activity could be the user speaking
  /// (not silence).
  ///
  /// Should be followed with a call to ``LiveSession/sendStopActivityRealtime()``, after all the
  /// data has been sent for the user's turn.
  ///
  /// Only required when automatic activity detection is disabled via
  /// ``ActivityDetectionConfig/disabled()``.
  public func sendStartActivityRealtime() async {
    let message = BidiGenerateContentRealtimeInput(activityStart: .init())
    await service.send(.realtimeInput(message))
  }

  /// Manually marks the end of user activity, using the realtime API.
  ///
  /// The end of user activity is effectively the end of a user's turn, and signals that the model
  /// can start sending responses.
  ///
  /// Should follow after a previous call to ``LiveSession/sendStartActivityRealtime()``.
  ///
  /// Only required when automatic activity detection is disabled via
  /// ``ActivityDetectionConfig/disabled()``.
  public func sendStopActivityRealtime() async {
    let message = BidiGenerateContentRealtimeInput(activityEnd: .init())
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
  ///   - parts: Content to append to the current conversation with the model  (see
  ///     ``PartsRepresentable`` for conforming types).
  ///   - turnComplete: Whether the server should start generating content with the currently
  ///     accumulated prompt, or await additional messages before starting generation. By default,
  ///     the server will await additional messages.
  public func sendContent(_ parts: any PartsRepresentable...,
                          turnComplete: Bool = false) async {
    await sendContent([ModelContent(parts: parts)], turnComplete: turnComplete)
  }

  /// Stops the conversation with the model and closes the connection to the server.
  ///
  /// The session is closed automatically when the ``LiveSession`` is deinitialized; call this
  /// method to end the session explicitly, without waiting for it to be released.
  ///
  /// After the session is closed, ``LiveSession/responses`` doesn't receive any new messages from
  /// the server unless the session is resumed with
  /// ``LiveSession/resumeSession(sessionResumption:)``. The stream finishes shortly after the
  /// session is deinitialized.
  public func close() async {
    await service.close()
  }

  /// Resumes an existing live session with the server.
  ///
  /// This closes the current WebSocket connection and establishes a new one using
  /// the same configuration (URI, headers, model, system instruction, tools, etc.)
  /// as the original session.
  ///
  /// To obtain a valid handle, ensure you pass an instance of
  /// ``SessionResumptionConfig`` to ``LiveGenerativeModel/connect(sessionResumption:)``,
  /// and then listen for the hande provided from a ``LiveSessionResumptionUpdate``
  /// server message.
  ///
  /// - Parameters:
  ///   - sessionResumption: The configuration for session resumption,
  ///   such as the handle to the previous session state to restore.
  public func resumeSession(sessionResumption: SessionResumptionConfig? = nil) async throws {
    try await service.connect(sessionResumption: sessionResumption)
  }
}
