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

// TODO: remove @preconcurrency when we update to Swift 6
// for context, see
// https://forums.swift.org/t/why-does-sending-a-sendable-value-risk-causing-data-races/73074
@preconcurrency import FirebaseAppCheckInterop
@preconcurrency import FirebaseAuthInterop

/// Facilitates communication with the backend for a ``LiveSession``.
///
/// Using an actor will make it easier to adopt session resumption, as we have an isolated place for
/// mainting mutablity, which is backed by Swift concurrency implicity; allowing us to avoid various
/// edge-case issues with dead-locks and data races.
///
/// This mainly comes into play when we don't want to block developers from sending messages while a
/// session is being reloaded.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
@available(watchOS, unavailable)
actor LiveSessionService {
  let responses: AsyncThrowingStream<LiveServerMessage, Error>
  private let responseContinuation: AsyncThrowingStream<LiveServerMessage, Error>
    .Continuation

  // to ensure messages are sent in order, since swift actors are reentrant
  private let messageQueue: AsyncStream<BidiGenerateContentClientMessage>
  private let messageQueueContinuation: AsyncStream<BidiGenerateContentClientMessage>.Continuation

  let modelResourceName: String
  let generationConfig: LiveGenerationConfig?
  let urlSession: URLSession
  let apiConfig: APIConfig
  let firebaseInfo: FirebaseInfo
  let requestOptions: RequestOptions
  let tools: [Tool]?
  let toolConfig: ToolConfig?
  let systemInstruction: ModelContent?

  var webSocket: AsyncWebSocket?

  private let jsonEncoder = JSONEncoder()
  private let jsonDecoder = JSONDecoder()

  /// Long running task that that wraps around the websocket, propogating messages through the
  /// public stream.
  private var responsesTask: Task<Void, Never>?

  /// Long running task that consumes user messages from the ``messageQueue`` and sends them through
  /// the websocket.
  private var messageQueueTask: Task<Void, Never>?

  init(modelResourceName: String,
       generationConfig: LiveGenerationConfig?,
       urlSession: URLSession,
       apiConfig: APIConfig,
       firebaseInfo: FirebaseInfo,
       tools: [Tool]?,
       toolConfig: ToolConfig?,
       systemInstruction: ModelContent?,
       requestOptions: RequestOptions) {
    (responses, responseContinuation) = AsyncThrowingStream.makeStream()
    (messageQueue, messageQueueContinuation) = AsyncStream.makeStream()
    self.modelResourceName = modelResourceName
    self.generationConfig = generationConfig
    self.urlSession = urlSession
    self.apiConfig = apiConfig
    self.firebaseInfo = firebaseInfo
    self.tools = tools
    self.toolConfig = toolConfig
    self.systemInstruction = systemInstruction
    self.requestOptions = requestOptions
  }

  deinit {
    responsesTask?.cancel()
    messageQueueTask?.cancel()
    webSocket?.disconnect()

    webSocket = nil
    responsesTask = nil
    messageQueueTask = nil
  }

  /// Queue a message to be sent to the model.
  ///
  /// If there's any issues while sending the message, details about the issue will be logged.
  ///
  /// Since messages are queued synchronously, they are sent in-order.
  func send(_ message: BidiGenerateContentClientMessage) {
    messageQueueContinuation.yield(message)
  }

  /// Start a new connection to the backend.
  ///
  /// Seperated into its own function to make it easier to surface a way to call it seperately when
  /// resuming the same session.
  ///
  /// This function will yield until the websocket is ready to communicate with the client.
  func connect() async throws {
    close()

    let stream = try await setupWebsocket()
    try await waitForSetupComplete(stream: stream)
    spawnMessageTasks(stream: stream)
  }

  /// Cancel any running tasks and close the websocket.
  ///
  /// This method is idempotent; if it's already ran once, it will effectively be a no-op.
  func close() {
    responsesTask?.cancel()
    messageQueueTask?.cancel()
    webSocket?.disconnect()

    webSocket = nil
    responsesTask = nil
    messageQueueTask = nil
  }

  /// Performs the initial setup procedure for the model.
  ///
  /// The setup procedure with the model follows the procedure:
  ///
  /// - Client sends `BidiGenerateContentSetup`
  /// - Server sends back `BidiGenerateContentSetupComplete` when it's ready
  ///
  /// This function will yield until the setup is complete.
  private func waitForSetupComplete(stream: MappedStream<
    URLSessionWebSocketTask.Message,
    Data
  >) async throws {
    guard let webSocket else { return }

    do {
      let setup = BidiGenerateContentSetup(
        model: modelResourceName,
        generationConfig: generationConfig?.bidiGenerationConfig,
        systemInstruction: systemInstruction,
        tools: tools,
        toolConfig: toolConfig,
        inputAudioTranscription: generationConfig?.inputAudioTranscription,
        outputAudioTranscription: generationConfig?.outputAudioTranscription
      )
      let data = try jsonEncoder.encode(BidiGenerateContentClientMessage.setup(setup))
      try await webSocket.send(.data(data))
    } catch {
      let error = LiveSessionSetupError(underlyingError: error)
      close()
      throw error
    }

    do {
      for try await message in stream {
        let response = try decodeServerMessage(message)
        if case .setupComplete = response.messageType {
          break
        } else {
          AILog.error(
            code: .liveSessionUnexpectedResponse,
            "The model sent us a message that wasn't a setup complete: \(response)"
          )
        }
      }
    } catch {
      if let error = mapWebsocketError(error) {
        close()
        throw error
      }
      // the user called close while setup was running
      // this can't currently happen, but could when we add automatic session resumption
      // in such case, we don't want to raise an error. this log is more-so to catch any edge cases
      AILog.debug(
        code: .liveSessionClosedDuringSetup,
        "The live session was closed before setup could complete: \(error.localizedDescription)"
      )
    }
  }

  /// Performs the initial setup procedure for a websocket.
  ///
  /// This includes creating the websocket url and connecting it.
  ///
  ///   - Returns: A stream of `Data` frames from the websocket.
  private func setupWebsocket() async throws
    -> MappedStream<URLSessionWebSocketTask.Message, Data> {
    do {
      let webSocket = try await createWebsocket()
      self.webSocket = webSocket

      let stream = webSocket.connect()

      // remove the uncommon (and unexpected) frames from the stream, to make normal path cleaner
      return stream.compactMap { message in
        switch message {
        case let .string(string):
          AILog.error(code: .liveSessionUnexpectedResponse, "Unexpected string response: \(string)")
        case let .data(data):
          return data
        @unknown default:
          AILog.error(code: .liveSessionUnexpectedResponse, "Unknown message received: \(message)")
        }
        return nil
      }
    } catch {
      let error = LiveSessionSetupError(underlyingError: error)
      close()
      throw error
    }
  }

  /// Spawn tasks for interacting with the model.
  ///
  /// The following tasks will be spawned:
  ///
  ///  - `responsesTask`: Listen to messages from the server and yield them through `responses`.
  ///  - `messageQueueTask`: Listen to messages from the client and send them through the websocket.
  private func spawnMessageTasks(stream: MappedStream<URLSessionWebSocketTask.Message, Data>) {
    guard let webSocket else { return }

    responsesTask = Task {
      do {
        for try await message in stream {
          let response = try decodeServerMessage(message)

          if case .setupComplete = response.messageType {
            AILog.debug(
              code: .duplicateLiveSessionSetupComplete,
              "Setup complete was received multiple times; this may be a bug in the model."
            )
          } else if let liveMessage = LiveServerMessage(from: response) {
            if case let .goingAwayNotice(message) = liveMessage.payload {
              // TODO: (b/444045023) When auto session resumption is enabled, call `connect` again
              AILog.debug(
                code: .liveSessionGoingAwaySoon,
                "Session expires in: \(message.goAway.timeLeft?.timeInterval ?? 0)"
              )
            }

            responseContinuation.yield(liveMessage)
          }
        }
      } catch {
        if let error = mapWebsocketError(error) {
          close()
          responseContinuation.finish(throwing: error)
        }
      }
    }

    messageQueueTask = Task {
      for await message in messageQueue {
        guard let data = encodeClientMessage(message) else { continue }

        do {
          try await webSocket.send(.data(data))
        } catch {
          AILog.error(code: .liveSessionFailedToSendClientMessage, error.localizedDescription)
        }
      }
    }
  }

  /// Checks if an error should be propogated up, and maps it accordingly.
  ///
  /// Some errors have public api alternatives. This function will ensure they're mapped
  /// accordingly.
  private func mapWebsocketError(_ error: Error) -> Error? {
    if let error = error as? WebSocketClosedError {
      // only raise an error if the session didn't close normally (ie; the user calling close)
      if error.closeCode == .goingAway {
        return nil
      }

      let closureError: Error

      if let error = error.underlyingError as? NSError, error.domain == NSURLErrorDomain,
         error.code == NSURLErrorNetworkConnectionLost {
        closureError = LiveSessionLostConnectionError(underlyingError: error)
      } else {
        closureError = LiveSessionUnexpectedClosureError(underlyingError: error)
      }

      return closureError
    }

    return error
  }

  /// Decodes a message from the server's websocket into a valid `BidiGenerateContentServerMessage`.
  ///
  /// Will throw an error if decoding fails.
  private func decodeServerMessage(_ message: Data) throws -> BidiGenerateContentServerMessage {
    do {
      return try jsonDecoder.decode(
        BidiGenerateContentServerMessage.self,
        from: message
      )
    } catch {
      // only log the json if it wasn't a decoding error, but an unsupported message type
      if error is InvalidMessageTypeError {
        AILog.error(
          code: .liveSessionUnsupportedMessage,
          "The server sent a message that we don't currently have a mapping for."
        )
        AILog.debug(
          code: .liveSessionUnsupportedMessagePayload,
          message.encodeToJsonString() ?? "\(message)"
        )
      }

      throw LiveSessionUnsupportedMessageError(underlyingError: error)
    }
  }

  /// Encodes a message from the client into `Data` that can be sent through a websocket data frame.
  ///
  /// Will return `nil` if decoding fails, and log an error describing why.
  private func encodeClientMessage(_ message: BidiGenerateContentClientMessage) -> Data? {
    do {
      return try jsonEncoder.encode(message)
    } catch {
      AILog.error(code: .liveSessionFailedToEncodeClientMessage, error.localizedDescription)
      AILog.debug(
        code: .liveSessionFailedToEncodeClientMessagePayload,
        String(describing: message)
      )
    }

    return nil
  }

  /// Creates a websocket pointing to the backend.
  ///
  /// Will apply the required app check and auth headers, as the backend expects them.
  private nonisolated func createWebsocket() async throws -> AsyncWebSocket {
    let host = apiConfig.service.endpoint.rawValue.withoutPrefix("https://")
    let urlString = switch apiConfig.service {
    case let .vertexAI(_, location: location):
      "wss://\(host)/ws/google.firebase.vertexai.\(apiConfig.version.rawValue).LlmBidiService/BidiGenerateContent/locations/\(location)"
    case .googleAI:
      "wss://\(host)/ws/google.firebase.vertexai.\(apiConfig.version.rawValue).GenerativeService/BidiGenerateContent"
    }
    guard let url = URL(string: urlString) else {
      throw NSError(
        domain: "\(Constants.baseErrorDomain).\(Self.self)",
        code: AILog.MessageCode.invalidWebsocketURL.rawValue,
        userInfo: [
          NSLocalizedDescriptionKey: "The live API websocket URL is not a valid URL",
        ]
      )
    }
    var urlRequest = URLRequest(url: url)
    urlRequest.timeoutInterval = requestOptions.timeout
    urlRequest.setValue(firebaseInfo.apiKey, forHTTPHeaderField: "x-goog-api-key")
    urlRequest.setValue(
      "\(GenerativeAIService.languageTag) \(GenerativeAIService.firebaseVersionTag)",
      forHTTPHeaderField: "x-goog-api-client"
    )
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

    if let appCheck = firebaseInfo.appCheck {
      let tokenResult = try await appCheck.fetchAppCheckToken(
        limitedUse: firebaseInfo.useLimitedUseAppCheckTokens,
        domain: "LiveSessionService"
      )
      urlRequest.setValue(tokenResult.token, forHTTPHeaderField: "X-Firebase-AppCheck")
      if let error = tokenResult.error {
        AILog.error(
          code: .appCheckTokenFetchFailed,
          "Failed to fetch AppCheck token. Error: \(error)"
        )
      }
    }

    if let auth = firebaseInfo.auth, let authToken = try await auth.getToken(
      forcingRefresh: false
    ) {
      urlRequest.setValue("Firebase \(authToken)", forHTTPHeaderField: "Authorization")
    }

    if firebaseInfo.app.isDataCollectionDefaultEnabled {
      urlRequest.setValue(firebaseInfo.firebaseAppID, forHTTPHeaderField: "X-Firebase-AppId")
      if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
        urlRequest.setValue(appVersion, forHTTPHeaderField: "X-Firebase-AppVersion")
      }
    }

    return AsyncWebSocket(urlSession: urlSession, urlRequest: urlRequest)
  }
}

private extension Data {
  /// Encodes this into a raw json string, with no regard to specific keys.
  ///
  /// Will return `nil` if this data doesn't represent a valid json object.
  func encodeToJsonString() -> String? {
    do {
      let object = try JSONSerialization.jsonObject(with: self)
      let data = try JSONSerialization.data(withJSONObject: object)

      return String(data: data, encoding: .utf8)
    } catch {
      return nil
    }
  }
}

private extension String {
  /// Create a new string with the given prefix removed, if it's present.
  ///
  /// If the prefix isn't present, this string will be returned instead.
  func withoutPrefix(_ prefix: String) -> String {
    if let index = range(of: prefix, options: .anchored) {
      return String(self[index.upperBound...])
    } else {
      return self
    }
  }
}

/// Helper alias for a compact mapped throwing stream.
///
/// We use this to make signatures easier to read, since we can't support `AsyncSequence` quite yet.
private typealias MappedStream<T, V> = AsyncCompactMapSequence<AsyncThrowingStream<T, any Error>, V>
