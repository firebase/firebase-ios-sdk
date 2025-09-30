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

  /// Task that doesn't complete until the server sends a setupComplete message.
  ///
  /// Used to hold off on sending messages until the server is ready.
  private var setupTask: Task<Void, Error>

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
    setupTask = Task {}
  }

  deinit {
    setupTask.cancel()
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
  func connect() {
    setupTask.cancel()
    // we launch the setup task in a seperate task to avoid blocking the parent context
    setupTask = Task { [weak self] in
      // we need a continuation to surface that the setup is complete, while still allowing us to listen to the server
      try await withCheckedThrowingContinuation { setupContinuation in
        // nested task so we can use await
        Task { [weak self] in
          guard let self else { return }
          await self.listenToServer(setupContinuation)
        }
      }
    }
  }

  /// Cancel any running tasks and close the websocket.
  ///
  /// This method is idempotent; if it's already ran once, it will effectively be a no-op.
  func close() {
    setupTask.cancel()
    responsesTask?.cancel()
    messageQueueTask?.cancel()
    webSocket?.disconnect()

    webSocket = nil
    responsesTask = nil
    messageQueueTask = nil
  }

  /// Start a fresh websocket to the backend, and listen for responses.
  ///
  /// Will hold off on sending any messages until the server sends a setupComplete mesage.
  ///
  /// Will also close out the old websocket and the previous long running tasks.
  private func listenToServer(_ setupComplete: CheckedContinuation<Void, any Error>) async {
    // close out the existing connections, if any
    webSocket?.disconnect()
    responsesTask?.cancel()
    messageQueueTask?.cancel()

    do {
      webSocket = try await createWebsocket()
    } catch {
      let error = LiveSessionSetupError(underlyingError: error)
      close()
      setupComplete.resume(throwing: error)
      return
    }

    guard let webSocket else { return }
    let stream = webSocket.connect()

    var resumed = false

    // remove the uncommon (and unexpected) responses from the stream, to make normal path cleaner
    let dataStream = stream.compactMap { (message: URLSessionWebSocketTask.Message) -> Data? in
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
      setupComplete.resume(throwing: error)
      return
    }

    responsesTask = Task {
      do {
        for try await message in dataStream {
          let response: BidiGenerateContentServerMessage
          do {
            response = try jsonDecoder.decode(
              BidiGenerateContentServerMessage.self,
              from: message
            )
          } catch {
            throw LiveSessionUnsupportedMessageError(underlyingError: error)
          }

          if case .setupComplete = response.messageType {
            if resumed {
              AILog.debug(
                code: .duplicateLiveSessionSetupComplete,
                "Setup complete was received multiple times; this may be a bug in the model."
              )
            } else {
              // calling resume multiple times is an error in swift, so we catch multiple calls
              // to avoid causing any issues due to model quirks
              resumed = true
              setupComplete.resume()
            }
          } else if let liveMessage = LiveServerMessage.tryFrom(response) {
            if case let .goAway(message) = liveMessage.messageType {
              // TODO: (b/444045023) When auto session resumption is enabled, call `connect` again
              AILog.debug(
                code: .liveSessionGoingAwaySoon,
                "Session expires in: \(message.goAway.timeLeft?.timeInterval ?? 0)"
              )
            }

            responseContinuation.yield(liveMessage)
          } else {
            // we don't raise an error, since this allows us to add support internally but not
            // publicly. We still log it in debug though, in case it's not expected.
            AILog.debug(
              code: .liveSessionUnsupportedMessage,
              "The server sent a message that we don't currently have a mapping for: \(response)"
            )
          }
        }
      } catch {
        if let error = error as? WebSocketClosedError {
          // only raise an error if the session didn't close normally (ie; the user calling close)
          if error.closeCode != .goingAway {
            let closureError: Error
            if let error = error.underlyingError as? NSError, error.domain == NSURLErrorDomain,
               error.code == NSURLErrorNetworkConnectionLost {
              closureError = LiveSessionLostConnectionError(underlyingError: error)
            } else {
              closureError = LiveSessionUnexpectedClosureError(underlyingError: error)
            }
            close()
            responseContinuation.finish(throwing: closureError)
          }
        } else {
          // an error occurred outside the websocket, so it's likely not closed
          close()
          responseContinuation.finish(throwing: error)
        }
      }
    }

    messageQueueTask = Task {
      for await message in messageQueue {
        // we don't propogate errors, since those are surfaced in the responses stream
        guard let _ = try? await setupTask.value else {
          break
        }

        let data: Data
        do {
          data = try jsonEncoder.encode(message)
        } catch {
          AILog.error(code: .liveSessionFailedToEncodeClientMessage, error.localizedDescription)
          AILog.debug(
            code: .liveSessionFailedToEncodeClientMessagePayload,
            String(describing: message)
          )
          continue
        }

        do {
          try await webSocket.send(.data(data))
        } catch {
          AILog.error(code: .liveSessionFailedToSendClientMessage, error.localizedDescription)
        }
      }
    }
  }

  /// Creates a websocket pointing to the backend.
  ///
  /// Will apply the required app check and auth headers, as the backend expects them.
  private nonisolated func createWebsocket() async throws -> AsyncWebSocket {
    let urlString = switch apiConfig.service {
    case .vertexAI:
      "wss://firebasevertexai.googleapis.com/ws/google.firebase.vertexai.v1beta.LlmBidiService/BidiGenerateContent/locations/us-central1"
    case .googleAI:
      "wss://firebasevertexai.googleapis.com/ws/google.firebase.vertexai.v1beta.GenerativeService/BidiGenerateContent"
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

/// The live model sent a message that the SDK failed to parse.
///
/// This may indicate that the SDK version needs updating, a model is too old for the current SDK
/// version, or that the model is just
/// not supported.
///
/// Check the `NSUnderlyingErrorKey` entry in ``errorUserInfo`` for the error that caused this.
public struct LiveSessionUnsupportedMessageError: Error, Sendable, CustomNSError {
  let underlyingError: Error

  init(underlyingError: Error) {
    self.underlyingError = underlyingError
  }

  public var errorUserInfo: [String: Any] {
    [
      NSLocalizedDescriptionKey: "Failed to parse a live message from the model. Cause: \(underlyingError.localizedDescription)",
      NSUnderlyingErrorKey: underlyingError,
    ]
  }
}

/// The live session was closed, because the network connection was lost.
///
/// Check the `NSUnderlyingErrorKey` entry in ``errorUserInfo`` for the error that caused this.
public struct LiveSessionLostConnectionError: Error, Sendable, CustomNSError {
  let underlyingError: Error

  init(underlyingError: Error) {
    self.underlyingError = underlyingError
  }

  public var errorUserInfo: [String: Any] {
    [
      NSLocalizedDescriptionKey: "The live session lost connection to the server. Cause: \(underlyingError.localizedDescription)",
      NSUnderlyingErrorKey: underlyingError,
    ]
  }
}

/// The live session was closed, but not for a reason the SDK expected.
///
/// Check the `NSUnderlyingErrorKey` entry in ``errorUserInfo`` for the error that caused this.
public struct LiveSessionUnexpectedClosureError: Error, Sendable, CustomNSError {
  let underlyingError: WebSocketClosedError

  init(underlyingError: WebSocketClosedError) {
    self.underlyingError = underlyingError
  }

  public var errorUserInfo: [String: Any] {
    [
      NSLocalizedDescriptionKey: "The live session was closed for some unexpected reason. Cause: \(underlyingError.localizedDescription)",
      NSUnderlyingErrorKey: underlyingError,
    ]
  }
}

/// The live model refused our request to setup a live session.
///
/// This can occur due to the model not supporting the requested response modalities, the project
/// not having access to the model,
/// the model being invalid,  or some internal error.
///
/// Check the `NSUnderlyingErrorKey` entry in ``errorUserInfo`` for the error that caused this.
public struct LiveSessionSetupError: Error, Sendable, CustomNSError {
  let underlyingError: Error

  init(underlyingError: Error) {
    self.underlyingError = underlyingError
  }

  public var errorUserInfo: [String: Any] {
    [
      NSLocalizedDescriptionKey: "The model did not accept the live session request. Reason: \(underlyingError.localizedDescription)",
      NSUnderlyingErrorKey: underlyingError,
    ]
  }
}
