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

#if compiler(>=6.4)
  import Foundation
  import FoundationModelsFake
  import Testing

  #if canImport(UniformTypeIdentifiers)
    import UniformTypeIdentifiers
  #endif

  @Suite("DataEntry and DataAttachment")
  struct DataEntryAndAttachmentTests {
    // MARK: - UTType Tests

    @Test
    func utTypeBuiltInConstantsAndLookup() {
      #expect(UTType.data.identifier == "public.data")
      #expect(UTType.json.identifier == "public.json")
      #expect(UTType.plainText.identifier == "public.plain-text")
      #expect(UTType.utf8PlainText.identifier == "public.utf8-plain-text")
      #expect(UTType.png.identifier == "public.png")
      #expect(UTType.jpeg.identifier == "public.jpeg")
      #expect(UTType.pdf.identifier == "com.adobe.pdf")

      let jsonByID = UTType("public.json")
      #expect(jsonByID == .json)
      #expect(jsonByID?.identifier == "public.json")
      #expect(UTType("") == nil)

      #if !canImport(UniformTypeIdentifiers)
        let custom = UTType("com.example.custom-type")
        #expect(custom?.identifier == "com.example.custom-type")
        let imported = UTType(importedAs: "com.example.telemetry", conformingTo: .json)
        #expect(imported.conforms(to: .json))
        #expect(imported.conforms(to: .data))
        let unknownExtension = UTType(filenameExtension: "zzfake", conformingTo: .text)
        #expect(unknownExtension?.conforms(to: .text) == true)
        #expect(UTType(filenameExtension: "") == nil)
      #endif

      let fromMime = UTType(mimeType: "application/json")
      #expect(fromMime?.conforms(to: .json) == true)

      let fromExt = UTType(filenameExtension: "png")
      #expect(fromExt?.conforms(to: .png) == true)
    }

    #if compiler(>=6.4.2)
      // MARK: - Transcript.DataEntry Tests

      @Test
      func dataEntryInitializationAndDescription() {
        let payload = Data([0x01, 0x02, 0x03, 0x04])
        let metadata = GeneratedContent(properties: ["source": "sensor"])

        let entry = Transcript.DataEntry(
          id: "data-entry-1",
          contentType: .json,
          content: payload,
          metadata: metadata
        )

        #expect(entry.id == "data-entry-1")
        #expect(entry.contentType == .json)
        #expect(entry.content == payload)
        #expect(entry.metadata == metadata)
        #expect(entry.description.contains("public.json"))
        #expect(entry.description.contains("4 bytes"))
        #expect(Transcript.Entry.data(entry).description == entry.description)
        #expect(Transcript.Entry.data(entry).id == "data-entry-1")
      }

      @Test
      func dataEntryTranscriptJSONRoundTrip() throws {
        let payload = Data("hello world".utf8)
        let metadata = GeneratedContent(properties: ["key": "value", "count": 42])
        let entry = Transcript.DataEntry(
          id: "entry-42",
          contentType: .plainText,
          content: payload,
          metadata: metadata
        )
        let transcript = Transcript(entries: [.data(entry)])

        let encodedTranscript = try JSONEncoder().encode(transcript)
        let decodedTranscript = try JSONDecoder().decode(Transcript.self, from: encodedTranscript)

        #expect(decodedTranscript == transcript)
      }

      @Test
      func dataWithAnUndeclaredContentTypeRoundTrips() throws {
        let contentType = UTType(importedAs: "com.example.telemetry")
        let entry = Transcript.DataEntry(
          id: "entry-43", contentType: contentType, content: Data([0x2A]))
        let attachment = Transcript.DataAttachment(contentType: contentType, content: Data([0x2B]))
        let transcript = Transcript(entries: [
          .data(entry),
          .prompt(
            Transcript.Prompt(
              id: "prompt-1",
              segments: [
                .attachment(Transcript.AttachmentSegment(id: "seg-1", content: .data(attachment)))
              ]
            )
          ),
        ])

        let encoded = try JSONEncoder().encode(transcript)
        let decoded = try JSONDecoder().decode(Transcript.self, from: encoded)

        guard case .data(let decodedEntry) = try #require(decoded.first) else {
          Issue.record("Expected a data entry, got \(String(describing: decoded.first))")
          return
        }
        #expect(decodedEntry.contentType.identifier == "com.example.telemetry")
        guard case .prompt(let prompt) = decoded.last,
          case .attachment(let segment) = prompt.segments.first,
          case .data(let decodedAttachment) = segment.content
        else {
          Issue.record("Expected a data attachment, got \(String(describing: decoded.last))")
          return
        }
        #expect(decodedAttachment.contentType.identifier == "com.example.telemetry")
      }

      // MARK: - DataEntryRepresentable Tests

      private struct CustomTelemetryRecord: DataEntryRepresentable, Equatable {
        var id: String
        var bytes: Data

        init(id: String, bytes: Data) {
          self.id = id
          self.bytes = bytes
        }

        init(_ entry: Transcript.DataEntry) throws {
          self.id = entry.id
          self.bytes = entry.content
        }

        var transcriptRepresentation: Transcript.DataEntry {
          Transcript.DataEntry(id: id, contentType: .data, content: bytes)
        }
      }

      @Test
      func dataEntryRepresentableRoundTrip() throws {
        let original = CustomTelemetryRecord(id: "telemetry-1", bytes: Data([0xAA, 0xBB]))

        let dataEntry = original.transcriptRepresentation
        let restored = try CustomTelemetryRecord(dataEntry)

        #expect(dataEntry.id == "telemetry-1")
        #expect(dataEntry.contentType == .data)
        #expect(restored == original)
      }

      // MARK: - Transcript.DataAttachment & DataAttachmentRepresentable Tests

      private struct CustomPDFPayload: DataAttachmentRepresentable, Equatable {
        var data: Data

        init(data: Data) {
          self.data = data
        }

        init(_ attachment: Transcript.DataAttachment) throws {
          self.data = attachment.content
        }

        var transcriptRepresentation: Transcript.DataAttachment {
          Transcript.DataAttachment(
            contentType: .pdf,
            content: data,
            metadata: GeneratedContent(properties: ["format": "pdf"])
          )
        }
      }

      @Test
      func dataAttachmentInitializationDescriptionAndTranscriptJSONRoundTrip() throws {
        let payload = Data([0x25, 0x50, 0x44, 0x46])
        let metadata = GeneratedContent(properties: ["pageCount": 1])
        let dataAttachment = Transcript.DataAttachment(
          contentType: .pdf,
          content: payload,
          metadata: metadata
        )
        let segment = Transcript.AttachmentSegment(
          id: "seg-pdf-1",
          content: .data(dataAttachment),
          label: "invoice"
        )
        let prompt = Transcript.Prompt(id: "p-1", segments: [.attachment(segment)])
        let transcript = Transcript(entries: [.prompt(prompt)])

        let encodedTranscript = try JSONEncoder().encode(transcript)
        let decodedTranscript = try JSONDecoder().decode(Transcript.self, from: encodedTranscript)

        #expect(segment.description.contains("com.adobe.pdf"))
        #expect(decodedTranscript == transcript)
      }

      /// Wraps a `Transcript.DataAttachment`, which doesn't conform to `DataAttachmentRepresentable`.
      private struct RawDataPayload: DataAttachmentRepresentable {
        var attachment: Transcript.DataAttachment

        init(_ attachment: Transcript.DataAttachment) {
          self.attachment = attachment
        }

        var transcriptRepresentation: Transcript.DataAttachment {
          attachment
        }
      }

      @Test
      func attachmentBuilderWithDataAttachmentRepresentableInPromptAndInstructions() async throws {
        let pdf = CustomPDFPayload(data: Data([0x01, 0x02, 0x03]))
        let directAttachment = Transcript.DataAttachment(
          contentType: .json,
          content: Data("{}".utf8)
        )
        let prompt = Prompt {
          "Analyze this PDF:"
          Attachment(pdf).label("doc-1")
          Attachment(RawDataPayload(directAttachment)).label("json-1")
        }
        let instructions = Instructions {
          "Reference attachment:"
          Attachment(pdf).label("ref-doc")
        }
        let model = MockDataModel(supportedAttachments: [.pdf, .json])
        let session = LanguageModelSession(model: model, instructions: instructions)

        _ = try await session.respond(to: prompt)

        #expect(session.transcript.count == 3)
        if case .instructions(let instEntry) = session.transcript[0] {
          #expect(instEntry.segments.count == 2)
          if case .attachment(let attSeg) = instEntry.segments[1] {
            #expect(attSeg.label == "ref-doc")
            #expect(attSeg.content == .data(pdf.transcriptRepresentation))
            let roundTripped = try CustomPDFPayload(pdf.transcriptRepresentation)
            #expect(roundTripped == pdf)
          } else {
            Issue.record("Expected attachment segment in instructions")
          }
        } else {
          Issue.record("Expected instructions entry")
        }

        if case .prompt(let promptEntry) = session.transcript[1] {
          #expect(promptEntry.segments.count == 3)
          if case .attachment(let firstAtt) = promptEntry.segments[1],
            case .attachment(let secondAtt) = promptEntry.segments[2]
          {
            #expect(firstAtt.label == "doc-1")
            #expect(firstAtt.content == .data(pdf.transcriptRepresentation))
            #expect(secondAtt.label == "json-1")
            #expect(secondAtt.content == .data(directAttachment))
          } else {
            Issue.record("Expected two attachment segments in prompt")
          }
        } else {
          Issue.record("Expected prompt entry")
        }
      }

      // MARK: - Capability Validation & Channel Event Tests

      private struct MockDataModel: LanguageModel {
        struct Executor: LanguageModelExecutor {
          typealias Model = MockDataModel
          struct Configuration: Hashable, Sendable {}

          init(configuration: Configuration) throws {}

          func respond(
            to request: LanguageModelExecutorGenerationRequest,
            model: MockDataModel,
            streamingInto channel: LanguageModelExecutorGenerationChannel
          ) async throws {
            if model.emitsDataEntries {
              await channel.send(
                .data(
                  entryID: "emitted-data-1",
                  action: .update(
                    contentType: .plainText,
                    content: Data("first".utf8),
                    metadata: GeneratedContent(properties: ["step": 1])
                  )
                )
              )
              await channel.send(
                .data(
                  entryID: "emitted-data-1",
                  action: .update(
                    contentType: .json,
                    content: Data("{\"updated\":true}".utf8),
                    metadata: GeneratedContent(properties: ["step": 2])
                  )
                )
              )
              await channel.send(
                .data(
                  action: .update(
                    contentType: .data,
                    content: Data([0xFF])
                  )
                )
              )
            }
            await channel.send(.response(action: .appendText("Done", tokenCount: 1)))
          }
        }

        var supportedAttachments: Set<UTType> = []
        var supportedEntries: Set<UTType> = []
        var emitsDataEntries: Bool = false

        var capabilities: LanguageModelCapabilities {
          LanguageModelCapabilities([])
        }

        var executorConfiguration: Executor.Configuration {
          Executor.Configuration()
        }

        func supportsDataAttachmentType(_ type: UTType) async throws -> Bool {
          supportedAttachments.contains(type)
        }

        func supportsDataEntryType(_ type: UTType) async throws -> Bool {
          supportedEntries.contains(type)
        }
      }

      @Test
      func sessionRejectsUnsupportedDataAttachmentInPrompt() async throws {
        let model = MockDataModel(supportedAttachments: [.png])
        let session = LanguageModelSession(model: model)
        let jsonAttachment = Transcript.DataAttachment(
          contentType: .json,
          content: Data("{}".utf8)
        )

        await #expect(throws: LanguageModelError.self) {
          try await session.respond {
            "Read JSON:"
            Attachment(RawDataPayload(jsonAttachment))
          }
        }

        let supportedSession = LanguageModelSession(
          model: MockDataModel(supportedAttachments: [.json])
        )
        let response = try await supportedSession.respond {
          "Read JSON:"
          Attachment(RawDataPayload(jsonAttachment))
        }
        #expect(response.content == "Done")
      }

      @Test
      func sessionRejectsUnsupportedDataEntryInTranscriptForRespondAndStream() async throws {
        let dataEntry = Transcript.DataEntry(
          id: "d-1",
          contentType: .pdf,
          content: Data([0x01, 0x02])
        )
        let transcript = Transcript(entries: [.data(dataEntry)])
        let unsupportedSession = LanguageModelSession(
          model: MockDataModel(supportedEntries: []),
          transcript: transcript
        )

        await #expect(throws: LanguageModelError.self) {
          try await unsupportedSession.respond(to: "Hello")
        }

        let stream = unsupportedSession.streamResponse(to: "Hello")
        await #expect(throws: LanguageModelError.self) {
          _ = try await stream.collect()
        }

        let supportedSession = LanguageModelSession(
          model: MockDataModel(supportedEntries: [.pdf]),
          transcript: transcript
        )
        let response = try await supportedSession.respond(to: "Hello")
        #expect(response.content == "Done")
      }

      @Test
      func channelDataEventCreatesAndUpdatesDataEntryInPlace() async throws {
        let model = MockDataModel(emitsDataEntries: true)
        let session = LanguageModelSession(model: model)

        let response = try await session.respond(to: "Emit data")

        #expect(response.content == "Done")
        let dataEntries = session.transcript.compactMap { entry -> Transcript.DataEntry? in
          if case .data(let d) = entry { return d }
          return nil
        }
        #expect(dataEntries.count == 2)
        #expect(dataEntries[0].id == "emitted-data-1")
        #expect(dataEntries[0].contentType == .json)
        #expect(dataEntries[0].content == Data("{\"updated\":true}".utf8))
        #expect(dataEntries[0].metadata == GeneratedContent(properties: ["step": 2]))
        #expect(dataEntries[1].contentType == .data)
        #expect(dataEntries[1].content == Data([0xFF]))
      }
    #endif  // compiler(>=6.4.2)
  }
#endif  // compiler(>=6.4)
