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

#if canImport(FoundationModels) && compiler(>=6.4)
  import Foundation
  import FoundationModels
  import GeminiAPIClient
  import GeminiAPIDataModels
  import GeminiTestUtilities
  import Testing

  #if canImport(FoundationNetworking)
    import FoundationNetworking
  #endif

  @testable import GeminiLanguageModel

  @Suite("GeminiForFoundationModels Unit Tests", .serialized, .requireFoundationModels)
  struct GeminiForFoundationModelsTests {
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
      #expect(!model.capabilities.contains(.toolCalling))
      #expect(!model.capabilities.contains(.guidedGeneration))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondSingleTurn() async throws {
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try #require(
        HTTPURLResponse(
          url: expectedURL,
          statusCode: 200,
          httpVersion: "HTTP/1.1",
          headerFields: ["Content-Type": "text/event-stream"]
        )
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

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondMultiTurn() async throws {
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try #require(
        HTTPURLResponse(
          url: expectedURL,
          statusCode: 200,
          httpVersion: "HTTP/1.1",
          headerFields: ["Content-Type": "text/event-stream"]
        )
      )
      let firstPayload = """
        data: {"candidates": [{"content": {"parts": [{"text": "Nice to meet you, Alice."}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

        """
      let secondPayload = """
        data: {"candidates": [{"content": {"parts": [{"text": "Your name is Alice."}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

        """
      nonisolated(unsafe) var requestCount = 0
      nonisolated(unsafe) var lastReceivedContents: [Content] = []
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        requestCount += 1
        if let body = request.httpBodyData,
          let decoded = try? JSONDecoder().decode(GenerateContentRequest.self, from: body)
        {
          lastReceivedContents = decoded.contents
        }
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        let payload = requestCount == 1 ? firstPayload : secondPayload
        proto.client?.urlProtocol(proto, didLoad: Data(payload.utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let session = LanguageModelSession(model: model)

      let firstResponse = try await session.respond(to: "My name is Alice.")
      let secondResponse = try await session.respond(to: "What is my name?")

      #expect(firstResponse.content == "Nice to meet you, Alice.")
      #expect(secondResponse.content == "Your name is Alice.")
      #expect(requestCount == 2)
      #expect(lastReceivedContents.count == 3)
      #expect(lastReceivedContents.first?.parts?.first?.data == .text("My name is Alice."))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionWithInstructions() async throws {
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try #require(
        HTTPURLResponse(
          url: expectedURL,
          statusCode: 200,
          httpVersion: "HTTP/1.1",
          headerFields: ["Content-Type": "text/event-stream"]
        )
      )
      let ssePayload = """
        data: {"candidates": [{"content": {"parts": [{"text": "Ahoy matey!"}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

        """
      nonisolated(unsafe) var receivedSystemInstruction: Content?
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        if let body = request.httpBodyData,
          let decoded = try? JSONDecoder().decode(GenerateContentRequest.self, from: body)
        {
          receivedSystemInstruction = decoded.systemInstruction
        }
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let session = LanguageModelSession(model: model, instructions: "Respond like a pirate.")

      let response = try await session.respond(to: "Hello")

      #expect(response.content == "Ahoy matey!")
      #expect(receivedSystemInstruction?.parts?.first?.data == .text("Respond like a pirate."))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionStreamResponse() async throws {
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try #require(
        HTTPURLResponse(
          url: expectedURL,
          statusCode: 200,
          httpVersion: "HTTP/1.1",
          headerFields: ["Content-Type": "text/event-stream"]
        )
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
    func rateLimitErrorMapping() async throws {
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try #require(
        HTTPURLResponse(
          url: expectedURL,
          statusCode: 429,
          httpVersion: "HTTP/1.1",
          headerFields: ["Content-Type": "application/json", "Retry-After": "30"]
        )
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
      } catch let LanguageModelError.rateLimited(rateLimited) {
        #expect(rateLimited.debugDescription.contains("Resource has been exhausted"))
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func guardrailViolationErrorMapping() async throws {
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try #require(
        HTTPURLResponse(
          url: expectedURL,
          statusCode: 200,
          httpVersion: "HTTP/1.1",
          headerFields: ["Content-Type": "text/event-stream"]
        )
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
      } catch let LanguageModelError.guardrailViolation(violation) {
        #expect(violation.debugDescription.contains("Filtered for safety reasons"))
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func timeoutErrorMapping() async throws {
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
        // Success
      } catch let error as URLError where error.code == .timedOut {
        // Success
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func unsupportedTranscriptContentThrows() throws {
      let toolCall = Transcript.ToolCall(
        id: "call-1",
        toolName: "calculator",
        arguments: GeneratedContent("1+1")
      )
      let toolCallsEntry = Transcript.Entry.toolCalls(
        Transcript.ToolCalls(id: "calls-1", [toolCall])
      )
      let transcript = Transcript(entries: [toolCallsEntry])

      do {
        _ = try GeminiTranscriptTranslator.translate(transcript)
        Issue.record("Expected unsupportedTranscriptContent error")
      } catch LanguageModelError.unsupportedTranscriptContent {
        // Success
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }
    }

    // MARK: - Helper Methods

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
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
