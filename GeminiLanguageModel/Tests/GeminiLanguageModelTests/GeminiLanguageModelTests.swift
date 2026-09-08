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
  import Synchronization
  import Testing

  #if canImport(FoundationNetworking)
    import FoundationNetworking
  #endif

  @testable import GeminiLanguageModel

  @Suite("GeminiLanguageModel Tests", .serialized, .requireFoundationModels)
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
      let textFormat = try #require(capturedRequest.generationConfig?.responseFormat?.text)
      #expect(textFormat.mimeType == .applicationJson)
      guard case .object(let schemaObject) = textFormat.schema else {
        Issue.record("Expected schema to be a JSON object.")
        return
      }
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
          lastReceivedContents.withLock { $0 = decoded.contents }
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
    struct MockWeatherTool: FoundationModels.Tool {

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
    struct MockTimeTool: FoundationModels.Tool {
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
    func sessionRespondWithThinkingSummariesIntoTranscript() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel(
        thinking: GeminiLanguageModel.Thinking(summaries: .auto)
      )
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let ssePayload = """
        data: {"candidates": [{"content": {"parts": [{"text": "I am thinking through the problem.", "thought": true}], "role": "model"}, "index": 0}]}

        data: {"candidates": [{"content": {"parts": [{"text": "Here is the final answer."}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

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

      let response = try await session.respond(to: "Solve this problem")

      #expect(response.content == "Here is the final answer.")
      let capturedRequest = try #require(receivedRequest.withLock { $0 })
      #expect(capturedRequest.generationConfig?.thinkingConfig?.includeThoughts == true)

      let reasoningEntries = session.transcript.compactMap { entry -> Transcript.Reasoning? in
        if case .reasoning(let reasoning) = entry {
          return reasoning
        }
        return nil
      }
      #expect(reasoningEntries.count == 1)
      let reasoning = try #require(reasoningEntries.first)
      let reasoningText = reasoning.segments.compactMap { segment -> String? in
        if case .text(let textSegment) = segment {
          return textSegment.content
        }
        return nil
      }.joined()
      #expect(reasoningText == "I am thinking through the problem.")
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionDynamicProfileWithGeminiThinkingAction() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let ssePayload = """
        data: {"candidates": [{"content": {"parts": [{"text": "Step 1. ", "thought": true}], "role": "model"}, "index": 0}]}

        data: {"candidates": [{"content": {"parts": [{"text": "Step 2.", "thought": true}], "role": "model"}, "index": 0}]}

        data: {"candidates": [{"content": {"parts": [{"text": "Done."}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

        """
      MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let observedThoughts = Mutex<[String]>([])
      let profile = LanguageModelSession.Profile {
        Instructions("You are a helpful assistant.")
      }
      .model(model)
      .geminiThinking { summary in
        observedThoughts.withLock { $0.append(summary) }
      }
      let session = LanguageModelSession(profile: profile)

      let response = try await session.respond(to: "Think step by step")

      #expect(response.content == "Done.")
      let thoughts = observedThoughts.withLock { $0 }
      #expect(thoughts == ["Step 1. Step 2."])
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondWithRequestMetadata() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let ssePayload = """
        data: {"candidates": [{"content": {"parts": [{"text": "Thoughts...", "thought": true}], "role": "model"}, "index": 0}]}

        data: {"candidates": [{"content": {"parts": [{"text": "Direct answer."}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

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
        metadata: .gemini(thinkingSummaries: .auto)
      ) {
        "Explain quantum computing"
      }

      #expect(response.content == "Direct answer.")
      let capturedRequest = try #require(receivedRequest.withLock { $0 })
      #expect(capturedRequest.generationConfig?.thinkingConfig?.includeThoughts == true)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionDynamicProfileWithGeminiThinkingModifier() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let baseModel = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let ssePayload = """
        data: {"candidates": [{"content": {"parts": [{"text": "Thinking...", "thought": true}], "role": "model"}, "index": 0}]}

        data: {"candidates": [{"content": {"parts": [{"text": "Result."}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

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

      let profile = LanguageModelSession.Profile {
        Instructions("You are a helpful assistant.")
      }
      .model(baseModel)
      .geminiThinking(summaries: .auto)
      let session = LanguageModelSession(profile: profile)

      let response = try await session.respond(to: "Hello")

      #expect(response.content == "Result.")
      let capturedRequest = try #require(receivedRequest.withLock { $0 })
      #expect(capturedRequest.generationConfig?.thinkingConfig?.includeThoughts == true)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionDynamicProfileWithGeminiThinkingModifierMultiTurn() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let baseModel = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let turn1SSE = """
        data: {"candidates": [{"content": {"parts": [{"text": "Thinking 1...", "thought": true}], "role": "model"}, "index": 0}]}

        data: {"candidates": [{"content": {"parts": [{"text": "Result 1."}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

        """
      let turn2SSE = """
        data: {"candidates": [{"content": {"parts": [{"text": "Thinking 2...", "thought": true}], "role": "model"}, "index": 0}]}

        data: {"candidates": [{"content": {"parts": [{"text": "Result 2."}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

        """
      let capturedRequests = Mutex<[GenerateContentRequest]>([])
      let requestCount = Mutex(0)
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        let count = requestCount.withLock { c -> Int in
          c += 1
          return c
        }
        if let body = request.httpBodyData,
          let decoded = try? JSONDecoder().decode(GenerateContentRequest.self, from: body)
        {
          capturedRequests.withLock { $0.append(decoded) }
        }
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        let payload = count == 1 ? turn1SSE : turn2SSE
        proto.client?.urlProtocol(proto, didLoad: Data(payload.utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let profile = LanguageModelSession.Profile {
        Instructions("You are a helpful assistant.")
      }
      .model(baseModel)
      .geminiThinking(summaries: .auto)
      let session = LanguageModelSession(profile: profile)

      let res1 = try await session.respond(to: "First prompt")
      #expect(res1.content == "Result 1.")

      let res2 = try await session.respond(to: "Second prompt")
      #expect(res2.content == "Result 2.")

      let requests = capturedRequests.withLock { $0 }
      #expect(requests.count == 2)
      #expect(requests[0].generationConfig?.thinkingConfig?.includeThoughts == true)
      #expect(requests[1].generationConfig?.thinkingConfig?.includeThoughts == true)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionDynamicProfileWithGeminiThinkingModifierOff() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let baseModel = Self.makeMockModel(
        thinking: GeminiLanguageModel.Thinking(summaries: .auto)
      )
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let ssePayload = """
        data: {"candidates": [{"content": {"parts": [{"text": "Result without thoughts."}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

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

      let profile = LanguageModelSession.Profile {
        Instructions("You are a helpful assistant.")
      }
      .model(baseModel)
      .geminiThinking(summaries: .off)
      let session = LanguageModelSession(profile: profile)

      let response = try await session.respond(to: "Hello")

      #expect(response.content == "Result without thoughts.")
      let capturedRequest = try #require(receivedRequest.withLock { $0 })
      #expect(capturedRequest.generationConfig?.thinkingConfig?.includeThoughts == false)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func responseGeminiThoughtSummary() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let ssePayload = """
        data: {"candidates": [{"content": {"parts": [{"text": "Deep thinking step 1...", "thought": true}], "role": "model"}, "index": 0}]}

        data: {"candidates": [{"content": {"parts": [{"text": "Deep thinking step 2...", "thought": true}], "role": "model"}, "index": 0}]}

        data: {"candidates": [{"content": {"parts": [{"text": "Final answer."}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

        """
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let session = LanguageModelSession(model: model)
      let response = try await session.respond(to: "Solve problem")

      #expect(response.content == "Final answer.")
      #expect(response.geminiThoughtSummary == "Deep thinking step 1...Deep thinking step 2...")
      #expect(
        session.transcript.geminiThoughtSummary == "Deep thinking step 1...Deep thinking step 2..."
      )
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func snapshotGeminiThoughtSummary() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let ssePayload = """
        data: {"candidates": [{"content": {"parts": [{"text": "Thinking in stream...", "thought": true}], "role": "model"}, "index": 0}]}

        data: {"candidates": [{"content": {"parts": [{"text": "Streaming answer."}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

        """
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let session = LanguageModelSession(model: model)
      let stream = session.streamResponse(to: "Stream with thoughts")

      var lastThoughtSummary: String?
      for try await snapshot in stream {
        if let thought = snapshot.geminiThoughtSummary {
          lastThoughtSummary = thought
        }
      }

      #expect(lastThoughtSummary == "Thinking in stream...")
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionPropertiesGeminiThoughtSummary() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let baseModel = Self.makeMockModel()
      let expectedURL = try Self.makeExpectedStreamURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let turn1SSE = """
        data: {"candidates": [{"content": {"parts": [{"text": "Thought for turn 1", "thought": true}], "role": "model"}, "index": 0}]}

        data: {"candidates": [{"content": {"parts": [{"text": "Response 1."}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

        """
      let turn2SSE = """
        data: {"candidates": [{"content": {"parts": [{"text": "Thought for turn 2", "thought": true}], "role": "model"}, "index": 0}]}

        data: {"candidates": [{"content": {"parts": [{"text": "Response 2."}], "role": "model"}, "finishReason": "STOP", "index": 0}]}

        """
      let requestCount = Mutex(0)
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        let count = requestCount.withLock { c -> Int in
          c += 1
          return c
        }
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        let payload = count == 1 ? turn1SSE : turn2SSE
        proto.client?.urlProtocol(proto, didLoad: Data(payload.utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let profile = LanguageModelSession.Profile {
        Instructions("You are a helpful assistant.")
      }
      .model(baseModel)
      .geminiThinking(summaries: .auto)
      let session = LanguageModelSession(profile: profile)

      #expect(session.properties.geminiThoughtSummary == nil)

      let res1 = try await session.respond(to: "First")
      #expect(res1.content == "Response 1.")
      #expect(res1.geminiThoughtSummary == "Thought for turn 1")
      #expect(session.properties.geminiThoughtSummary == "Thought for turn 1")

      let res2 = try await session.respond(to: "Second")
      #expect(res2.content == "Response 2.")
      #expect(res2.geminiThoughtSummary == "Thought for turn 2")
      #expect(session.properties.geminiThoughtSummary == "Thought for turn 2")
    }

    // MARK: - Helper Methods

    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)

    private static func makeMockModel(
      modelResource: ModelResource = .gemini38Flash,
      endpointConfiguration: EndpointConfiguration = .geminiDeveloperAPI,
      headerProvider: (@Sendable () async throws -> [String: String])? = nil,
      thinking: GeminiLanguageModel.Thinking? = nil
    ) -> GeminiLanguageModel {
      let configuration = URLSessionConfiguration.ephemeral
      configuration.protocolClasses = [MockHTTPURLProtocol.self]
      return GeminiLanguageModel(
        modelResource: modelResource,
        endpointConfiguration: endpointConfiguration,
        headerProvider: headerProvider,
        configuration: configuration,
        thinking: thinking
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
