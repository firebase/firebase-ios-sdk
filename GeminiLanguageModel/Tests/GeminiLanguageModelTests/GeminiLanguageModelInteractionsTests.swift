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
  import GeminiSharedDataModels
  import GeminiTestUtilities
  import InteractionsDataModels
  import Synchronization
  import Testing

  #if canImport(FoundationNetworking)
    import FoundationNetworking
  #endif

  @testable import GeminiLanguageModel

  extension GeminiLanguageModelTests {
    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondInteractionsBasicText() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockInteractionsModel()
      let expectedURL = try Self.makeExpectedInteractionsURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let ssePayload = """
        event: interaction.created
        data: {"id": "interaction-123", "status": "processing"}

        event: step.start
        data: {"index": 0, "step": {"type": "model_output"}}

        event: step.delta
        data: {"delta": {"text": "Hello, world!", "type": "text"}, "index": 0}

        event: step.stop
        data: {"index": 0}

        event: interaction.completed
        data: {"interaction": {"usage": {"total_input_tokens": 5, "total_output_tokens": 4}}}

        """
      let receivedRequest = Mutex<CreateModelInteraction?>(nil)
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        if let body = request.httpBodyData,
          let decoded = try? JSONDecoder().decode(CreateModelInteraction.self, from: body)
        {
          receivedRequest.withLock { $0 = decoded }
        }
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let session = LanguageModelSession(model: model)

      let response = try await session.respond(to: "Hi")

      #expect(response.content == "Hello, world!")
      let captured = try #require(receivedRequest.withLock { $0 })
      #expect(captured.model?.rawValue == "gemini-3.8-flash")
      #expect(captured.store == false)
      #expect(captured.stream == true)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondInteractionsGuidedGeneration() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockInteractionsModel()
      let expectedURL = try Self.makeExpectedInteractionsURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let ssePayload = """
        event: step.start
        data: {"index": 0, "step": {"type": "model_output"}}

        event: step.delta
        data: {"delta": {"text": "{\\"name\\": \\"Tokyo\\", \\"population\\": 14000000}", "type": "text"}, "index": 0}

        event: step.stop
        data: {"index": 0}

        event: interaction.completed
        data: {"interaction": {"usage": {"total_input_tokens": 10, "total_output_tokens": 15}}}

        """
      let receivedRequest = Mutex<CreateModelInteraction?>(nil)
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        if let body = request.httpBodyData,
          let decoded = try? JSONDecoder().decode(CreateModelInteraction.self, from: body)
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
      let captured = try #require(receivedRequest.withLock { $0 })
      let responseFormat = try #require(captured.responseFormat)
      guard case .object(let schema) = responseFormat else {
        Issue.record("Expected responseFormat object")
        return
      }
      #expect(schema["type"] == .string("object"))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondInteractionsToolCalling() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockInteractionsModel()
      let expectedURL = try Self.makeExpectedInteractionsURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let turn1SSE = """
        event: step.start
        data: {"index": 0, "step": {"id": "call-1", "name": "get_current_time", "type": "function_call"}}

        event: step.stop
        data: {"index": 0}

        """
      let turn2SSE = """
        event: step.start
        data: {"index": 0, "step": {"type": "model_output"}}

        event: step.delta
        data: {"delta": {"text": "The time is 12:00 PM.", "type": "text"}, "index": 0}

        event: step.stop
        data: {"index": 0}

        event: interaction.completed
        data: {"interaction": {"usage": {"total_input_tokens": 15, "total_output_tokens": 8}}}

        """
      let requestCount = Mutex(0)
      let capturedRequests = Mutex<[CreateModelInteraction]>([])
      MockHTTPURLProtocol.setHandler(for: expectedURL) { request, proto in
        let currentCount = requestCount.withLock { count -> Int in
          count += 1
          return count
        }
        if let body = request.httpBodyData,
          let decoded = try? JSONDecoder().decode(CreateModelInteraction.self, from: body)
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
      guard case .function(let fn) = turn1Tools.first else {
        Issue.record("Expected function tool in turn 1")
        return
      }
      #expect(fn.name == "get_current_time")

      guard case .stepList(let turn2Steps) = try #require(requests.last?.input) else {
        Issue.record("Expected stepList in turn 2")
        return
      }
      let turn2LastStep = try #require(turn2Steps.last)
      guard case .functionResultStep(let fr) = turn2LastStep else {
        Issue.record("Expected functionResultStep in turn 2")
        return
      }
      #expect(fr.name == "get_current_time")
      #expect(fr.callId == "call-1")
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondInteractionsStreamingArgumentsToolCalling() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockInteractionsModel()
      let expectedURL = try Self.makeExpectedInteractionsURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let turn1SSE = """
        event: step.start
        data: {"index": 0, "step": {"id": "call-weather", "name": "get_weather", "type": "function_call"}}

        event: step.delta
        data: {"delta": {"arguments": "{\\"location\\": \\"Paris\\"}", "type": "arguments_delta"}, "index": 0}

        event: step.stop
        data: {"index": 0}

        """
      let turn2SSE = """
        event: step.start
        data: {"index": 0, "step": {"type": "model_output"}}

        event: step.delta
        data: {"delta": {"text": "Weather in Paris is sunny.", "type": "text"}, "index": 0}

        event: step.stop
        data: {"index": 0}

        event: interaction.completed
        data: {"interaction": {"usage": {"total_input_tokens": 12, "total_output_tokens": 6}}}

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

      let response = try await session.respond(to: "Weather in Paris?")

      #expect(response.content == "Weather in Paris is sunny.")
      #expect(requestCount.withLock { $0 } == 2)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionStreamResponseInteractions() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockInteractionsModel()
      let expectedURL = try Self.makeExpectedInteractionsURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let ssePayload = """
        event: step.start
        data: {"index": 0, "step": {"type": "model_output"}}

        event: step.delta
        data: {"delta": {"text": "Hello ", "type": "text"}, "index": 0}

        event: step.delta
        data: {"delta": {"text": "stream!", "type": "text"}, "index": 0}

        event: step.stop
        data: {"index": 0}

        event: interaction.completed
        data: {"interaction": {"usage": {"total_input_tokens": 4, "total_output_tokens": 3}}}

        """
      MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data(ssePayload.utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let session = LanguageModelSession(model: model)

      let stream = session.streamResponse(to: "Hi")
      var accumulated = ""
      var lastUsage: LanguageModelSession.Usage?
      for try await snapshot in stream {
        accumulated = snapshot.content
        lastUsage = snapshot.usage
      }

      #expect(accumulated == "Hello stream!")
      let usage = try #require(lastUsage)
      #expect(usage.input.totalTokenCount == 4)
      #expect(usage.output.totalTokenCount == 3)
      #expect(usage.totalTokenCount == 7)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondInteractionsErrorEvent() async throws {
      defer { MockHTTPURLProtocol.reset() }
      let model = Self.makeMockInteractionsModel()
      let expectedURL = try Self.makeExpectedInteractionsURL()
      let httpResponse = try HTTPURLResponse.mock(
        url: expectedURL,
        headerFields: ["Content-Type": "text/event-stream"]
      )
      let errorSSE = """
        event: error
        data: {"error": {"code": "INVALID_ARGUMENT", "message": "Interaction failed validation"}}

        """
      MockHTTPURLProtocol.setHandler(for: expectedURL) { _, proto in
        proto.client?.urlProtocol(proto, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        proto.client?.urlProtocol(proto, didLoad: Data(errorSSE.utf8))
        proto.client?.urlProtocolDidFinishLoading(proto)
      }

      let session = LanguageModelSession(model: model)

      do {
        _ = try await session.respond(to: "Trigger error")
        Issue.record("Expected error to be thrown")
      } catch {
        #expect("\(error)".contains("Interaction failed validation"))
      }
    }

    // MARK: - Helper Methods

    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    private static func makeMockInteractionsModel(
      modelResource: ModelResource = .gemini38Flash,
      endpointConfiguration: EndpointConfiguration = .geminiDeveloperAPI
    ) -> GeminiLanguageModel {
      let configuration = URLSessionConfiguration.ephemeral
      configuration.protocolClasses = [MockHTTPURLProtocol.self]
      return GeminiLanguageModel(
        modelResource: modelResource,
        endpointConfiguration: endpointConfiguration,
        configuration: configuration,
        apiVariant: .interactions
      )
    }

    private static func makeExpectedInteractionsURL(
      host: String = EndpointConfiguration.geminiDeveloperAPIHost,
      apiVersion: String = EndpointConfiguration.geminiDeveloperAPIVersion
    ) throws -> URL {
      try #require(
        URL(string: "https://\(host)/\(apiVersion)/interactions")
      )
    }
  }
#endif
