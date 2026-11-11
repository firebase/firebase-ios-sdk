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

#if compiler(>=6.4) && (FoundationModelsFake || canImport(FoundationModels))
  #if canImport(CoreGraphics)
    import CoreGraphics
  #endif
  import Foundation
  #if FoundationModelsFake
    import FoundationModelsFake
  #else
    import FoundationModels
  #endif
  import GeminiAPIClient
  import GeminiAPIDataModels
  import GeminiTestUtilities
  import Synchronization
  import Testing

  #if canImport(FoundationNetworking)
    import FoundationNetworking
  #endif

  @testable import GeminiLanguageModel

  #if FoundationModelsFake
    /// Foundation Models' `Tool`, spelled out to avoid clashing with
    /// `GeminiAPIDataModels.Tool`.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    typealias FoundationModelsTool = FoundationModelsFake.Tool
  #else
    /// Foundation Models' `Tool`, spelled out to avoid clashing with
    /// `GeminiAPIDataModels.Tool`.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    typealias FoundationModelsTool = FoundationModels.Tool
  #endif

  @Suite(
    "GeminiLanguageModel Tests",
    .serialized,
    .requireFoundationModels,
    // Fails runaway tool-call loops instead of hanging.
    .timeLimit(.minutes(1))
  )
  struct GeminiLanguageModelTests {
    @Generable(description: "A city summary")
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct CitySummary {
      var name: String
      var population: Int
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func modelInitializationAndCapabilities() {
      let model = GeminiLanguageModel(
        modelResource: .gemini35FlashLite,
        endpointConfiguration: .geminiDeveloperAPI
      )

      #expect(model.executorConfiguration.modelResource == .gemini35FlashLite)
      #expect(model.executorConfiguration.endpointConfiguration == .geminiDeveloperAPI)
      #expect(model.capabilities.contains(.reasoning))
      #expect(model.capabilities.contains(.guidedGeneration))
      #expect(model.capabilities.contains(.toolCalling))
      #expect(model.capabilities.contains(.vision))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondGuidedGeneration() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let ssePayload = """
        data: {"candidates": [{"content": {"parts": [{"text": "{\\"name\\": \\"Tokyo\\", \\"population\\": 14000000}"}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

        """
      let receivedRequest = Mutex<GenerateContentRequest?>(nil)
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        if let body = request.httpBodyData,
          let decoded = try? JSONDecoder().decode(GenerateContentRequest.self, from: body)
        {
          receivedRequest.withLock { $0 = decoded }
        }
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let session = LanguageModelSession(model: model)

      let response = try await session.respond(
        to: "Tell me about Tokyo",
        generating: CitySummary.self
      )

      #expect(response.content.name == "Tokyo")
      #expect(response.content.population == 14_000_000)
      let capturedRequest = try #require(receivedRequest.withLock { $0 })
      let generationConfig = try #require(capturedRequest.generationConfig)
      #expect(generationConfig.responseMIMEType == "application/json")
      let schemaObject = try #require(generationConfig.responseJSONSchema)
      #expect(schemaObject["x-order"] == nil)
      #expect(schemaObject["propertyOrdering"] != nil)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondSingleTurn() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let ssePayload = """
        data: {"candidates": [{"content": {"parts": [{"text": "Hello world from Gemini!"}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

        """
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let session = LanguageModelSession(model: model)

      let response = try await session.respond(to: "Hello")

      #expect(response.content == "Hello world from Gemini!")
    }

    #if canImport(ImageIO)
      @Test
      @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
      func sessionRespondWithImageAttachmentSendsInlineData() async throws {
        defer { MockHTTPURLProtocol.reset() }
        let model = Self.makeMockModel()
        let expectedURL = try Self.makeExpectedStreamURL()
        let httpResponse = try HTTPURLResponse.mock(
          url: expectedURL,
          headerFields: ["Content-Type": "text/event-stream"]
        )
        let ssePayload = """
          data: {"candidates": [{"content": {"parts": [{"text": "red"}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

          """
        let receivedRequest = Mutex<GenerateContentRequest?>(nil)
        MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
          if let body = request.httpBodyData,
            let decoded = try? JSONDecoder().decode(GenerateContentRequest.self, from: body)
          {
            receivedRequest.withLock { $0 = decoded }
          }
          proto.client?.urlProtocol(
            proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
          proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
          proto.client?.urlProtocolDidFinishLoading(proto)
        }
        let image = try TestImages.solid(.red, width: 32, height: 32)
        let session = LanguageModelSession(model: model)

        let response = try await session.respond {
          "What color is this image?"
          Attachment(image)
        }

        #expect(response.content == "red")
        let capturedRequest = try #require(receivedRequest.withLock { $0 })
        let parts = try #require(capturedRequest.contents?.first?.parts)
        #expect(parts.count == 2)
        #expect(parts[0].data == .text("What color is this image?"))
        guard case .inlineData(let blob) = parts[1].data else {
          Issue.record("Expected inline data, got \(String(describing: parts[1].data)).")
          return
        }
        #expect(blob.mimeType == "image/jpeg")
        let decodedImage = try TestImages.decode(try #require(blob.data))
        #expect(decodedImage.width == 32)
        #expect(try TestImages.quadrantColors(of: decodedImage).topLeft == .red)
      }
    #endif  // canImport(ImageIO)

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondMultiTurn() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let firstPayload = """
        data: {"candidates": [{"content": {"parts": [{"text": "Nice to meet you, Alice."}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

        """
      let secondPayload = """
        data: {"candidates": [{"content": {"parts": [{"text": "Your name is Alice."}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

        """
      let requestCount = Mutex<Int>(0)
      let lastReceivedContents = Mutex<[Content]>([])
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        let currentCount = requestCount.withLock { count in
          count += 1
          return count
        }
        if let body = request.httpBodyData,
          let decoded = try? JSONDecoder().decode(GenerateContentRequest.self, from: body)
        {
          lastReceivedContents.withLock { $0 = decoded.contents ?? [] }
        }
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        let payload = currentCount == 1 ? firstPayload : secondPayload
        proto.client?.urlProtocol(proto, didLoad: Data(payload.utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let session = LanguageModelSession(model: model)

      let firstResponse = try await session.respond(to: "My name is Alice.")
      let secondResponse = try await session.respond(to: "What is my name?")

      #expect(firstResponse.content == "Nice to meet you, Alice.")
      #expect(secondResponse.content == "Your name is Alice.")
      #expect(requestCount.withLock { $0 } == 2)
      let contents = lastReceivedContents.withLock { $0 }
      #expect(contents.count == 3)
      #expect(contents.first?.parts?.first?.data == .text("My name is Alice."))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionWithInstructions() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let ssePayload = """
        data: {"candidates": [{"content": {"parts": [{"text": "Ahoy matey!"}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

        """
      let receivedSystemInstruction = Mutex<Content?>(nil)
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        if let body = request.httpBodyData,
          let decoded = try? JSONDecoder().decode(GenerateContentRequest.self, from: body)
        {
          receivedSystemInstruction.withLock { $0 = decoded.systemInstruction }
        }
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let session = LanguageModelSession(model: model, instructions: "Respond like a pirate.")

      let response = try await session.respond(to: "Hello")

      #expect(response.content == "Ahoy matey!")
      let instruction = receivedSystemInstruction.withLock { $0 }
      #expect(instruction?.parts?.first?.data == .text("Respond like a pirate."))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionStreamResponse() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let ssePayload = """
        data: {"candidates": [{"content": {"parts": [{"text": "42", "thoughtSignature": "test-signature-123"}], "role": "model"}, "finishReason": "STOP", "index": 0}], "usageMetadata": {"candidatesTokenCount": 2, "promptTokenCount": 5, "totalTokenCount": 7}}

        """
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let session = LanguageModelSession(model: model)

      let stream = session.streamResponse(to: "What is 6x7?")
      var accumulated = ""
      var lastUsage: LanguageModelSession.Usage?
      for try await snapshot in stream {
        accumulated = snapshot.content
        lastUsage = snapshot.usage
      }

      #expect(accumulated == "42")
      let usage = try #require(lastUsage)
      #expect(usage.input.totalTokenCount == 5)
      #expect(usage.output.totalTokenCount == 2)
      #expect(usage.totalTokenCount == 7)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionStreamResponseReportsFinalChunkUsage() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let chunks = [
        Self.streamChunk(
          "Hello ",
          usageMetadata: #"{"promptTokenCount": 5, "totalTokenCount": 5}"#
        ),
        Self.streamChunk(
          "world!",
          isFinal: true,
          usageMetadata:
            #"{"promptTokenCount": 5, "candidatesTokenCount": 2, "totalTokenCount": 7}"#
        ),
      ]
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        for chunk in chunks {
          proto.client?.urlProtocol(proto, didLoad: Data(chunk.utf8))
        }
        proto.client?.urlProtocolDidFinishLoading(proto)
      }
      let session = LanguageModelSession(model: model)

      var accumulated = ""
      var lastUsage: LanguageModelSession.Usage?
      for try await snapshot in session.streamResponse(to: "Say hello") {
        accumulated = snapshot.content
        lastUsage = snapshot.usage
      }

      #expect(accumulated == "Hello world!")
      let usage = try #require(lastUsage)
      #expect(usage.input.totalTokenCount == 5)
      #expect(usage.output.totalTokenCount == 2)
      #expect(usage.totalTokenCount == 7)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionStreamResponseCachedTokensOnlyInFinalChunk() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      // The Gemini Developer API reports implicitly cached tokens only in the final chunk. In
      // testing, reporting the first chunk's usage before it decreased the uncached input token
      // count, which crashes `LanguageModelSession`.
      let chunks = [
        Self.streamChunk(
          "Hello ",
          usageMetadata:
            #"{"promptTokenCount": 50, "candidatesTokenCount": 2, "totalTokenCount": 52}"#
        ),
        Self.streamChunk(
          "world!",
          isFinal: true,
          usageMetadata: #"{"promptTokenCount": 50, "cachedContentTokenCount": 40, "#
            + #""candidatesTokenCount": 4, "totalTokenCount": 54}"#
        ),
      ]
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        for chunk in chunks {
          proto.client?.urlProtocol(proto, didLoad: Data(chunk.utf8))
        }
        proto.client?.urlProtocolDidFinishLoading(proto)
      }
      let session = LanguageModelSession(model: model)

      var accumulated = ""
      var lastUsage: LanguageModelSession.Usage?
      for try await snapshot in session.streamResponse(to: "Say hello") {
        accumulated = snapshot.content
        lastUsage = snapshot.usage
      }

      #expect(accumulated == "Hello world!")
      let usage = try #require(lastUsage)
      #expect(usage.input.totalTokenCount == 50)
      #expect(usage.input.cachedTokenCount == 40)
      #expect(usage.output.totalTokenCount == 4)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionStreamResponseDeliversSnapshotsBeforeResponseCompletes() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      // The Gemini Enterprise Agent Platform omits token counts until the final chunk. In testing,
      // `LanguageModelSession` delivers each streamed snapshot only when a later event arrives, so
      // intermediate chunks keep arriving, as they would while the model is still generating,
      // until the consumer receives one.
      let finalChunk = Self.streamChunk(
        "done.",
        isFinal: true,
        usageMetadata: #"{"promptTokenCount": 5, "candidatesTokenCount": 5, "totalTokenCount": 10}"#
      )
      let snapshotReceived = DispatchSemaphore(value: 0)
      // Stops the background chunk loop promptly if the test exits early.
      defer { snapshotReceived.signal() }
      let isResponseComplete = Mutex(false)
      let intermediateChunkCount = Mutex(0)
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        nonisolated(unsafe) let proto = proto
        DispatchQueue.global().async {
          let deadline = DispatchTime.now() + .seconds(5)
          repeat {
            let index = intermediateChunkCount.withLock { count in
              count += 1
              return count
            }
            let chunk = Self.streamChunk("\(index) ", usageMetadata: "{}")
            proto.client?.urlProtocol(proto, didLoad: Data(chunk.utf8))
          } while snapshotReceived.wait(timeout: .now() + .milliseconds(20)) == .timedOut
            && DispatchTime.now() < deadline
          isResponseComplete.withLock { $0 = true }
          proto.client?.urlProtocol(proto, didLoad: Data(finalChunk.utf8))
          proto.client?.urlProtocolDidFinishLoading(proto)
        }
      }
      let session = LanguageModelSession(model: model)

      var accumulated = ""
      var receivedSnapshotBeforeResponseCompleted: Bool?
      for try await snapshot in session.streamResponse(to: "Count") {
        if receivedSnapshotBeforeResponseCompleted == nil {
          receivedSnapshotBeforeResponseCompleted = !isResponseComplete.withLock { $0 }
          snapshotReceived.signal()
        }
        accumulated = snapshot.content
      }

      #expect(receivedSnapshotBeforeResponseCompleted == true)
      let chunkCount = intermediateChunkCount.withLock { $0 }
      #expect(accumulated == (1...chunkCount).map { "\($0) " }.joined() + "done.")
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionStreamResponseUsageTracksRunningOutputTokenCount() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let chunks = [
        Self.streamChunk(
          "One ",
          usageMetadata:
            #"{"promptTokenCount": 5, "candidatesTokenCount": 10, "totalTokenCount": 15}"#
        ),
        Self.streamChunk(
          "two ",
          usageMetadata:
            #"{"promptTokenCount": 5, "candidatesTokenCount": 20, "totalTokenCount": 25}"#
        ),
        Self.streamChunk(
          "three.",
          isFinal: true,
          usageMetadata:
            #"{"promptTokenCount": 5, "candidatesTokenCount": 30, "totalTokenCount": 35}"#
        ),
      ]
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        for chunk in chunks {
          proto.client?.urlProtocol(proto, didLoad: Data(chunk.utf8))
        }
        proto.client?.urlProtocolDidFinishLoading(proto)
      }
      let session = LanguageModelSession(model: model)

      var outputTokenCounts: [Int] = []
      for try await snapshot in session.streamResponse(to: "Count to three") {
        outputTokenCounts.append(snapshot.usage.output.totalTokenCount)
      }

      #expect(outputTokenCounts.last == 30)
      // While streaming, snapshots report Gemini's running totals (10, then 20) rather than a
      // count of chunks. Snapshots may be merged, so not every total is necessarily reported.
      let streamedOutputTokenCounts = outputTokenCounts.filter { $0 < 30 }
      #expect(!streamedOutputTokenCounts.isEmpty)
      #expect(streamedOutputTokenCounts.allSatisfy { [10, 20].contains($0) })
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionStreamResponseCachedTokensWithoutPromptTokenCount() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      // A cached token count above the input total would crash `LanguageModelSession`.
      let chunks = [
        Self.streamChunk(
          "Hello!",
          isFinal: true,
          usageMetadata:
            #"{"cachedContentTokenCount": 40, "candidatesTokenCount": 2, "totalTokenCount": 42}"#
        )
      ]
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        for chunk in chunks {
          proto.client?.urlProtocol(proto, didLoad: Data(chunk.utf8))
        }
        proto.client?.urlProtocolDidFinishLoading(proto)
      }
      let session = LanguageModelSession(model: model)

      var lastUsage: LanguageModelSession.Usage?
      for try await snapshot in session.streamResponse(to: "Say hello") {
        lastUsage = snapshot.usage
      }

      let usage = try #require(lastUsage)
      #expect(usage.input.totalTokenCount == 0)
      #expect(usage.input.cachedTokenCount == 0)
      #expect(usage.output.totalTokenCount == 2)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionStreamResponseUsageIncludesReasoningTokens() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      // Gemini's `candidatesTokenCount` excludes thinking tokens, which it reports separately in
      // `thoughtsTokenCount`.
      let chunks = [
        Self.streamChunk(
          "Thinking it over.",
          isThought: true,
          usageMetadata:
            #"{"promptTokenCount": 5, "thoughtsTokenCount": 7, "totalTokenCount": 12}"#
        ),
        Self.streamChunk(
          "Answer.",
          isFinal: true,
          usageMetadata: #"{"promptTokenCount": 5, "candidatesTokenCount": 4, "#
            + #""thoughtsTokenCount": 7, "totalTokenCount": 16}"#
        ),
      ]
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        for chunk in chunks {
          proto.client?.urlProtocol(proto, didLoad: Data(chunk.utf8))
        }
        proto.client?.urlProtocolDidFinishLoading(proto)
      }
      let session = LanguageModelSession(model: model)

      var accumulated = ""
      var lastUsage: LanguageModelSession.Usage?
      for try await snapshot in session.streamResponse(to: "Think, then answer") {
        accumulated = snapshot.content
        lastUsage = snapshot.usage
      }

      #expect(accumulated == "Answer.")
      let usage = try #require(lastUsage)
      #expect(usage.output.reasoningTokenCount == 7)
      #expect(usage.output.totalTokenCount == 11)
      #expect(usage.totalTokenCount == 16)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func rateLimitErrorMapping() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        statusCode: 429,
        headerFields: ["Content-Type": "application/json", "Retry-After": "30"]
      )
      let errorPayload = """
        {"error": {"code": 429, "message": "Resource has been exhausted", "status": "RESOURCE_EXHAUSTED"}}
        """
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data(errorPayload.utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let session = LanguageModelSession(model: model)

      do {
        _ = try await session.respond(to: "Hello")
        Issue.record("Expected rateLimited error")
      } catch LanguageModelError.rateLimited(let rateLimited) {
        #expect(rateLimited.debugDescription.contains("Resource has been exhausted"))
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func guardrailViolationErrorMapping() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let ssePayload = """
        data: {"candidates": [{"finishReason": "SAFETY", "finishMessage": "Filtered for safety reasons"}]}

        """
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let session = LanguageModelSession(model: model)

      do {
        _ = try await session.respond(to: "Harmful prompt")
        Issue.record("Expected guardrailViolation error")
      } catch LanguageModelError.guardrailViolation(let violation) {
        #expect(violation.debugDescription.contains("Filtered for safety reasons"))
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func functionCallWithoutNameThrowsInvalidResponse() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let ssePayload = """
        data: {"candidates": [{"content": {"parts": [{"functionCall": {"id": "call-1", "args": {}}}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

        """
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }
      let session = LanguageModelSession(model: model, tools: [MockWeatherTool()])

      do {
        _ = try await session.respond(to: "What's the weather?")
        Issue.record("Expected GeminiLanguageModel.Error.invalidResponse")
      } catch GeminiLanguageModel.Error.invalidResponse(let invalidResponse) {
        #expect(invalidResponse.debugDescription.contains("without a name"))
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func timeoutErrorMapping() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
        proto.client?.urlProtocol(proto, didFailWithError: URLError(.timedOut))
      }

      let session = LanguageModelSession(model: model)

      do {
        _ = try await session.respond(to: "Hello")
        Issue.record("Expected timeout error")
      } catch LanguageModelError.timeout {
      } catch let error as URLError where error.code == .timedOut {
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func unsupportedTranscriptContentThrows() throws {
      let structuredSegment = Transcript.Segment.structure(
        Transcript.StructuredSegment(
          id: "struct-1",
          schemaName: "test",
          content: GeneratedContent("test")
        )
      )
      let transcript = Transcript(
        entries: [.prompt(Transcript.Prompt(segments: [structuredSegment]))]
      )

      do {
        _ = try GeminiTranscriptTranslator.translate(transcript)
        Issue.record("Expected unsupportedTranscriptContent error")
      } catch LanguageModelError.unsupportedTranscriptContent {
        // Success
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }
    }

    /// A mock weather tool for testing tool call execution.
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct MockWeatherTool: FoundationModelsTool {

      let name = "get_weather"
      let description = "Get current weather"

      @Generable
      @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
      @available(tvOS, unavailable)
      struct Arguments {
        var location: String
      }

      func call(arguments: Arguments) async throws -> String {
        "Sunny, 72°F in \(arguments.location)"
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondWithToolCalling() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let turn1SSE = """
        data: {"candidates": [{"content": {"parts": [{"functionCall": {"id": "call-1", "name": "get_weather", "args": {"location": "Paris"}}}], "role": "model"}, "finishReason": "STOP", "index": 0}], "usageMetadata": {"candidatesTokenCount": 5, "promptTokenCount": 10, "totalTokenCount": 15}}

        """
      let turn2SSE = """
        data: {"candidates": [{"content": {"parts": [{"text": "The weather in Paris is sunny, 72°F."}], "role": "model"}, "finishReason": "STOP", "index": 0}], "usageMetadata": {"candidatesTokenCount": 8, "promptTokenCount": 20, "totalTokenCount": 28}}

        """
      let requestCount = Mutex(0)
      MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
        let currentCount = requestCount.withLock { count -> Int in
          count += 1
          return count
        }
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        let payload = currentCount == 1 ? turn1SSE : turn2SSE
        proto.client?.urlProtocol(proto, didLoad: Data(payload.utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }
      let session = LanguageModelSession(model: model, tools: [MockWeatherTool()])

      let response = try await session.respond(to: "What is the weather in Paris?")

      #expect(response.content == "The weather in Paris is sunny, 72°F.")
      #expect(requestCount.withLock { $0 } == 2)
    }

    /// A mock time tool taking no arguments for testing empty argument tool calling.
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct MockTimeTool: FoundationModelsTool {
      let name = "get_current_time"
      let description = "Get the current time"

      @Generable
      @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
      @available(tvOS, unavailable)
      struct Arguments {}

      func call(arguments: Arguments) async throws -> String {
        "12:00 PM"
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondWithEmptyArgumentsToolCalling() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let turn1SSE = """
        data: {"candidates": [{"content": {"parts": [{"functionCall": {"id": "call-1", "name": "get_current_time"}}], "role": "model"}, "finishReason": "STOP", "index": 0}], "usageMetadata": {"candidatesTokenCount": 5, "promptTokenCount": 10, "totalTokenCount": 15}}

        """
      let turn2SSE = """
        data: {"candidates": [{"content": {"parts": [{"text": "The time is 12:00 PM."}], "role": "model"}, "finishReason": "STOP", "index": 0}], "usageMetadata": {"candidatesTokenCount": 8, "promptTokenCount": 20, "totalTokenCount": 28}}

        """
      let requestCount = Mutex(0)
      let capturedRequests = Mutex<[GenerateContentRequest]>([])
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        let currentCount = requestCount.withLock { count -> Int in
          count += 1
          return count
        }
        if let body = request.httpBodyData,
          let decoded = try? JSONDecoder().decode(GenerateContentRequest.self, from: body)
        {
          capturedRequests.withLock { $0.append(decoded) }
        }
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        let payload = currentCount == 1 ? turn1SSE : turn2SSE
        proto.client?.urlProtocol(proto, didLoad: Data(payload.utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }
      let session = LanguageModelSession(model: model, tools: [MockTimeTool()])

      let response = try await session.respond(to: "What time is it?")

      #expect(response.content == "The time is 12:00 PM.")
      #expect(requestCount.withLock { $0 } == 2)
      let requests = capturedRequests.withLock { $0 }
      #expect(requests.count == 2)
      let turn1Tools = try #require(requests.first?.tools)
      #expect(turn1Tools.first?.functionDeclarations?.first?.name == "get_current_time")
      let turn2Contents = try #require(requests.last?.contents)
      let turn2UserTurn = try #require(turn2Contents.last)
      guard case .functionResponse(let fr) = turn2UserTurn.parts?.first?.data else {
        Issue.record("Expected functionResponse in turn 2")
        return
      }
      #expect(fr.name == "get_current_time")
      #expect(fr.response?["result"] == .string("12:00 PM"))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondDisablesFunctionCallingAtToolCallingTurnLimit() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let maximumTurns = GeminiLanguageModel.Executor.Configuration.defaultMaximumToolCallingTurns
      try #require(maximumTurns == 10)
      let recordedRequests = try Self.mockToolCallingLoop { $0 <= maximumTurns }
      let session = LanguageModelSession(model: Self.makeMockModel(), tools: [MockWeatherTool()])

      let response = try await session.respond(
        to: "What is the weather in Paris?",
        options: GenerationOptions(toolCallingMode: .required)
      )

      #expect(response.content == Self.weatherResponseText)
      #expect(Self.toolCallsEntryCount(in: session.transcript) == maximumTurns)
      #expect(Self.toolOutputEntryCount(in: session.transcript) == maximumTurns)
      let requests = recordedRequests.all
      #expect(requests.count == maximumTurns + 1)
      #expect(requests.dropLast().allSatisfy { $0.toolConfig?.functionCallingConfig?.mode == .any })
      #expect(
        requests.last?.toolConfig?.functionCallingConfig?.mode == FunctionCallingConfig.Mode.none)
      #expect(requests.last?.tools?.first?.functionDeclarations?.first?.name == "get_weather")
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func functionCallAfterToolCallingTurnLimitThrowsInvalidResponse() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let maximumTurns = GeminiLanguageModel.Executor.Configuration.defaultMaximumToolCallingTurns
      let recordedRequests = try Self.mockToolCallingLoop { _ in true }
      let session = LanguageModelSession(model: Self.makeMockModel(), tools: [MockWeatherTool()])
      session.transcriptErrorHandlingPolicy = .preserveTranscript

      do {
        _ = try await session.respond(to: "What is the weather in Paris?")
        Issue.record("Expected GeminiLanguageModel.Error.invalidResponse")
      } catch GeminiLanguageModel.Error.invalidResponse(let invalidResponse) {
        #expect(
          invalidResponse.debugDescription.contains("limit of \(maximumTurns) tool-calling turns"))
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }

      #expect(recordedRequests.all.count == maximumTurns + 1)
      #expect(Self.toolOutputEntryCount(in: session.transcript) == maximumTurns)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func newPromptResetsToolCallingTurnCount() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let maximumTurns = GeminiLanguageModel.Executor.Configuration.defaultMaximumToolCallingTurns
      // Each prompt receives `maximumTurns` function calls, then text.
      let recordedRequests = try Self.mockToolCallingLoop { requestNumber in
        requestNumber % (maximumTurns + 1) != 0
      }
      let session = LanguageModelSession(model: Self.makeMockModel(), tools: [MockWeatherTool()])
      _ = try await session.respond(to: "What is the weather in Paris?")

      let response = try await session.respond(to: "And in London?")

      #expect(response.content == Self.weatherResponseText)
      let modes = recordedRequests.all.map { $0.toolConfig?.functionCallingConfig?.mode }
      let validatedModes = Array(
        repeating: FunctionCallingConfig.Mode?.some(.validated), count: maximumTurns)
      let promptModes = validatedModes + [FunctionCallingConfig.Mode.none]
      #expect(modes == promptModes + promptModes)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func parallelFunctionCallsCountAsOneToolCallingTurn() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let maximumTurns = GeminiLanguageModel.Executor.Configuration.defaultMaximumToolCallingTurns
      let recordedRequests = try Self.mockToolCallingLoop(functionCallsPerResponse: 2) {
        $0 <= maximumTurns
      }
      let session = LanguageModelSession(model: Self.makeMockModel(), tools: [MockWeatherTool()])

      let response = try await session.respond(
        to: "What is the weather in Paris and London?",
        options: GenerationOptions(toolCallingMode: .required)
      )

      #expect(response.content == Self.weatherResponseText)
      #expect(Self.toolCallsEntryCount(in: session.transcript) == maximumTurns)
      #expect(Self.toolOutputEntryCount(in: session.transcript) == 2 * maximumTurns)
      let requests = recordedRequests.all
      #expect(requests.count == maximumTurns + 1)
      #expect(requests.dropLast().allSatisfy { $0.toolConfig?.functionCallingConfig?.mode == .any })
      #expect(
        requests.last?.toolConfig?.functionCallingConfig?.mode == FunctionCallingConfig.Mode.none)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func functionCallWithToolCallingModeDisallowedThrowsInvalidResponse() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let recordedRequests = try Self.mockToolCallingLoop { _ in true }
      let session = LanguageModelSession(model: Self.makeMockModel(), tools: [MockWeatherTool()])
      session.transcriptErrorHandlingPolicy = .preserveTranscript

      do {
        _ = try await session.respond(
          to: "What is the weather in Paris?",
          options: GenerationOptions(toolCallingMode: .disallowed)
        )
        Issue.record("Expected GeminiLanguageModel.Error.invalidResponse")
      } catch GeminiLanguageModel.Error.invalidResponse(let invalidResponse) {
        #expect(invalidResponse.debugDescription.contains("tool calling mode was `disallowed`"))
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }

      let requests = recordedRequests.all
      #expect(requests.count == 1)
      #expect(requests.first?.tools == nil)
      #expect(Self.toolOutputEntryCount(in: session.transcript) == 0)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func disallowedRequestAfterToolCallsDeclaresToolsWithFunctionCallingNone() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let recordedRequests = try Self.mockToolCallingLoop { $0 == 1 }
      let session = LanguageModelSession(model: Self.makeMockModel(), tools: [MockWeatherTool()])
      _ = try await session.respond(to: "What is the weather in Paris?")

      let response = try await session.respond(
        to: "Summarize that without calling tools.",
        options: GenerationOptions(toolCallingMode: .disallowed)
      )

      #expect(response.content == Self.weatherResponseText)
      let requests = recordedRequests.all
      #expect(requests.count == 3)
      let lastRequest = try #require(requests.last)
      #expect(lastRequest.tools?.first?.functionDeclarations?.map(\.name) == ["get_weather"])
      #expect(
        lastRequest.toolConfig?.functionCallingConfig?.mode == FunctionCallingConfig.Mode.none)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func functionCallToToolThatIsNotEnabledThrowsInvalidResponse() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let recordedRequests = try Self.mockToolCallingLoop(functionName: "get_current_time") { _ in
        true
      }
      let session = LanguageModelSession(model: Self.makeMockModel(), tools: [MockWeatherTool()])

      do {
        _ = try await session.respond(to: "What time is it?")
        Issue.record("Expected GeminiLanguageModel.Error.invalidResponse")
      } catch GeminiLanguageModel.Error.invalidResponse(let invalidResponse) {
        #expect(
          invalidResponse.debugDescription.contains(
            "`get_current_time`, which isn't an enabled tool"))
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }

      #expect(recordedRequests.all.count == 1)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func functionCallWithoutToolsThrowsInvalidResponse() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let recordedRequests = try Self.mockToolCallingLoop { _ in true }
      let session = LanguageModelSession(model: Self.makeMockModel())

      do {
        _ = try await session.respond(to: "What is the weather in Paris?")
        Issue.record("Expected GeminiLanguageModel.Error.invalidResponse")
      } catch GeminiLanguageModel.Error.invalidResponse(let invalidResponse) {
        #expect(
          invalidResponse.debugDescription.contains("`get_weather`, which isn't an enabled tool"))
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }

      #expect(recordedRequests.all.count == 1)
    }

    /// A case for `functionCallRejectionReason(_:)`.
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct FunctionCallRejectionCase: Sendable, CustomTestStringConvertible {
      /// The tool calling mode of the request.
      let toolCallingMode: GenerationOptions.ToolCallingMode?

      /// The name of the function that Gemini calls.
      let functionName: String

      /// Whether the request enables `MockWeatherTool`.
      let enablesWeatherTool: Bool

      /// Whether the session has reached the tool-calling turn limit.
      let isAtToolCallingTurnLimit: Bool

      /// A substring of the expected rejection reason, or `nil` if the call is allowed.
      let expectedReasonSubstring: String?

      var testDescription: String {
        """
        mode: \(toolCallingMode.map { "\($0.kind)" } ?? "nil"), function: \(functionName), \
        tool enabled: \(enablesWeatherTool), at limit: \(isAtToolCallingTurnLimit)
        """
      }

      /// The cases to test, in order of rejection precedence.
      static let all: [FunctionCallRejectionCase] = [
        .init(
          toolCallingMode: .disallowed, functionName: "get_weather", enablesWeatherTool: true,
          isAtToolCallingTurnLimit: false, expectedReasonSubstring: "`disallowed`"),
        .init(
          toolCallingMode: .disallowed, functionName: "get_weather", enablesWeatherTool: false,
          isAtToolCallingTurnLimit: true, expectedReasonSubstring: "`disallowed`"),
        .init(
          toolCallingMode: .required, functionName: "get_weather", enablesWeatherTool: true,
          isAtToolCallingTurnLimit: true, expectedReasonSubstring: "limit of 2 tool-calling turns"),
        .init(
          toolCallingMode: nil, functionName: "get_time", enablesWeatherTool: false,
          isAtToolCallingTurnLimit: true, expectedReasonSubstring: "limit of 2 tool-calling turns"),
        .init(
          toolCallingMode: nil, functionName: "get_weather", enablesWeatherTool: false,
          isAtToolCallingTurnLimit: false, expectedReasonSubstring: "isn't an enabled tool"),
        .init(
          toolCallingMode: .allowed, functionName: "get_time", enablesWeatherTool: true,
          isAtToolCallingTurnLimit: false, expectedReasonSubstring: "isn't an enabled tool"),
        .init(
          toolCallingMode: nil, functionName: "get_weather", enablesWeatherTool: true,
          isAtToolCallingTurnLimit: false, expectedReasonSubstring: nil),
        .init(
          toolCallingMode: .allowed, functionName: "get_weather", enablesWeatherTool: true,
          isAtToolCallingTurnLimit: false, expectedReasonSubstring: nil),
        .init(
          toolCallingMode: .required, functionName: "get_weather", enablesWeatherTool: true,
          isAtToolCallingTurnLimit: false, expectedReasonSubstring: nil),
      ]
    }

    @Test(arguments: FunctionCallRejectionCase.all)
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func functionCallRejectionReason(_ testCase: FunctionCallRejectionCase) throws {
      let request = LanguageModelExecutorGenerationRequest(
        id: UUID(),
        transcript: Transcript(entries: []),
        enabledTools: testCase.enablesWeatherTool
          ? [Transcript.ToolDefinition(tool: MockWeatherTool())] : [],
        schema: nil,
        generationOptions: GenerationOptions(toolCallingMode: testCase.toolCallingMode),
        contextOptions: ContextOptions(),
        metadata: [:]
      )

      let reason = GeminiLanguageModel.Executor.functionCallRejectionReason(
        forFunctionNamed: testCase.functionName,
        in: request,
        isAtToolCallingTurnLimit: testCase.isAtToolCallingTurnLimit,
        maximumToolCallingTurns: 2
      )

      if let expectedReasonSubstring = testCase.expectedReasonSubstring {
        let reason = try #require(reason)
        #expect(reason.contains(expectedReasonSubstring))
      } else {
        #expect(reason == nil)
      }
    }

    // MARK: - Helper Methods

    /// The final text response sent by `mockToolCallingLoop`.
    private static let weatherResponseText = "The weather in Paris is sunny, 72°F."

    /// Records the Gemini requests intercepted by `MockHTTPURLProtocol`.
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    private final class RecordedRequests: Sendable {
      private let requests = Mutex<[GenerateContentRequest]>([])

      /// The recorded requests, in the order they were sent.
      var all: [GenerateContentRequest] { requests.withLock { $0 } }

      /// Records a request and returns the number of requests recorded so far.
      ///
      /// - Parameter request: The request to record.
      /// - Returns: The number of requests recorded, including `request`.
      func append(_ request: GenerateContentRequest) -> Int {
        requests.withLock {
          $0.append(request)
          return $0.count
        }
      }
    }

    /// Mocks a model that responds to each request with either function calls or text.
    ///
    /// - Parameters:
    ///   - functionName: The name of the function that the mock calls.
    ///   - functionCallsPerResponse: The number of parallel function calls in each function-call
    ///     response.
    ///   - respondsWithFunctionCalls: Returns whether the request with the given 1-based number
    ///     receives function calls; other requests receive `weatherResponseText`.
    /// - Returns: The requests that the mock receives.
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    private static func mockToolCallingLoop(
      functionName: String = "get_weather",
      functionCallsPerResponse: Int = 1,
      respondsWithFunctionCalls: @escaping @Sendable (_ requestNumber: Int) -> Bool
    ) throws -> RecordedRequests {
      let expectedURL = try makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let textSSE = """
        data: {"candidates": [{"content": {"parts": [{"text": "\(weatherResponseText)"}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

        """
      let recordedRequests = RecordedRequests()
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        let body = try #require(request.httpBodyData)
        let requestNumber = recordedRequests.append(
          try JSONDecoder().decode(GenerateContentRequest.self, from: body)
        )
        let payload: String
        if respondsWithFunctionCalls(requestNumber) {
          let parts = (1...functionCallsPerResponse).map { index in
            """
            {"functionCall": {"id": "call-\(requestNumber)-\(index)", "name": "\(functionName)", \
            "args": {"location": "Paris"}}}
            """
          }
          payload = """
            data: {"candidates": [{"content": {"parts": [\(parts.joined(separator: ", "))], "role": "model"}, "finishReason": "STOP", "index": 0}]}

            """
        } else {
          payload = textSSE
        }
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data(payload.utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }
      return recordedRequests
    }

    /// Returns the number of tool-calling turns (non-empty tool-calls entries) in a transcript.
    ///
    /// - Parameter transcript: The transcript to search.
    /// - Returns: The number of non-empty `Transcript.Entry.toolCalls` entries.
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    private static func toolCallsEntryCount(in transcript: Transcript) -> Int {
      transcript.filter { entry in
        guard case .toolCalls(let toolCalls) = entry else { return false }
        return !toolCalls.isEmpty
      }.count
    }

    /// Returns the number of tool outputs in a transcript.
    ///
    /// - Parameter transcript: The transcript to search.
    /// - Returns: The number of `Transcript.Entry.toolOutput` entries.
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    private static func toolOutputEntryCount(in transcript: Transcript) -> Int {
      transcript.filter { entry in
        guard case .toolOutput = entry else { return false }
        return true
      }.count
    }

    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)

    private static func makeMockModel(
      modelResource: ModelResource = .gemini38Flash,
      endpointConfiguration: EndpointConfiguration = .geminiDeveloperAPI,
      headerProvider: (@Sendable () async throws -> [String: String])? = nil
    ) -> GeminiLanguageModel {
      let configuration = URLSessionConfiguration.ephemeral
      configuration.protocolClasses = [MockHTTPURLProtocol.self]
      return GeminiLanguageModel(
        modelResource: modelResource,
        endpointConfiguration: endpointConfiguration,
        headerProvider: headerProvider,
        configuration: configuration
      )
    }

    private static func makeExpectedStreamURL(
      host: String = EndpointConfiguration.geminiDeveloperAPIHost,
      apiVersion: String = EndpointConfiguration.geminiDeveloperAPIVersion,
      urlResourceName: String = ModelResource.gemini38FlashURLResourceName
    ) throws -> URL {
      try #require(
        URL(
          string:
            "https://\(host)/\(apiVersion)/\(urlResourceName):streamGenerateContent?alt=sse"
        )
      )
    }

    /// Returns a server-sent event for a streamed `generateContent` chunk.
    ///
    /// - Parameters:
    ///   - text: The text of the chunk's single part.
    ///   - isThought: Whether the part is a thought summary.
    ///   - isFinal: Whether the chunk ends the response with a `STOP` finish reason.
    ///   - usageMetadata: The chunk's `usageMetadata` JSON object.
    /// - Returns: The `data:` line and its terminating blank line.
    private static func streamChunk(
      _ text: String,
      isThought: Bool = false,
      isFinal: Bool = false,
      usageMetadata: String
    ) -> String {
      let thought = isThought ? #", "thought": true"# : ""
      let finishReason = isFinal ? #", "finishReason": "STOP""# : ""
      return #"data: {"candidates": [{"content": {"parts": [{"text": "\#(text)"\#(thought)}], "#
        + #""role": "model"}\#(finishReason), "index": 0}], "usageMetadata": \#(usageMetadata)}"#
        + "\n\n"
    }
  }
#endif  // compiler(>=6.4) && (FoundationModelsFake || canImport(FoundationModels))
