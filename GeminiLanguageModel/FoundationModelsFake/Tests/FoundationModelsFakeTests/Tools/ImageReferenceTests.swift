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
  import Synchronization
  import Testing

  @testable import FoundationModelsFake

  #if canImport(FoundationEssentials)
    import FoundationEssentials
  #else
    import Foundation
  #endif

  /// Unit tests for `ImageReference`.
  @Suite("ImageReference Tests")
  struct ImageReferenceTests {
    // MARK: - ImageReference Tests

    @Test
    func imageReferenceGeneratedContentRoundTripAndPartialGeneration() throws {
      let reference = ImageReference(attachmentLabel: "photo-1")
      let partialInput = try GeneratedContent(json: #"{"attachmentLabel":"partial-photo"}"#)
      let emptyInput = GeneratedContent(properties: [:])

      let content = reference.generatedContent
      let decoded = try ImageReference(content)
      let partialFromComplete = reference.asPartiallyGenerated()
      let partialDecoded = try ImageReference.PartiallyGenerated(partialInput)
      let partialEmpty = try ImageReference.PartiallyGenerated(emptyInput)
      let schemaDebug = ImageReference.generationSchema.debugDescription

      #expect(reference.attachmentLabel == "photo-1")
      #expect(decoded == reference)
      #expect(content.jsonString == #"{"attachmentLabel": "photo-1"}"#)
      #expect(partialFromComplete.attachmentLabel == "photo-1")
      #expect(partialDecoded.attachmentLabel == "partial-photo")
      #expect(partialEmpty.attachmentLabel == nil)
      #expect(ImageReference.generationSchema.name == "ImageReference")
      #expect(schemaDebug.contains("A reference for an image in the transcript."))
      #expect(schemaDebug.contains("attachmentLabel"))
      #expect(throws: GeneratedContent.ParsingError.self) {
        _ = try ImageReference(emptyInput)
      }
    }

    @Test
    func imageReferenceResolvedMatchesInputEntriesAndIgnoresOutputEntries() throws {
      let url1 = try #require(URL(string: "file:///tmp/instructions-image.png"))
      let url2 = try #require(URL(string: "file:///tmp/prompt-image.png"))
      let url3 = try #require(URL(string: "file:///tmp/tool-output-image.png"))
      let url4 = try #require(URL(string: "file:///tmp/response-image.png"))
      let instructionsImage = Transcript.ImageAttachment(imageURL: url1)
      let promptImage = Transcript.ImageAttachment(imageURL: url2)
      let toolOutputImage = Transcript.ImageAttachment(imageURL: url3)
      let responseImage = Transcript.ImageAttachment(imageURL: url4)
      let transcript = Transcript(entries: [
        .instructions(
          Transcript.Instructions(
            id: "inst-1",
            segments: [
              .attachment(
                Transcript.AttachmentSegment(
                  id: "seg-1",
                  content: .image(instructionsImage),
                  label: "InstImg"
                )
              )
            ],
            toolDefinitions: []
          )
        ),
        .prompt(
          Transcript.Prompt(
            id: "prompt-1",
            segments: [
              .attachment(
                Transcript.AttachmentSegment(
                  id: "seg-2",
                  content: .image(promptImage),
                  label: "PromptImg"
                )
              )
            ]
          )
        ),
        .toolOutput(
          Transcript.ToolOutput(
            id: "to-1",
            toolName: "customTool",
            segments: [
              .attachment(
                Transcript.AttachmentSegment(
                  id: "seg-3",
                  content: .image(toolOutputImage),
                  label: "ToolImg"
                )
              )
            ]
          )
        ),
        .response(
          Transcript.Response(
            id: "resp-1",
            assetIDs: [],
            segments: [
              .attachment(
                Transcript.AttachmentSegment(
                  id: "seg-4",
                  content: .image(responseImage),
                  label: "RespImg"
                )
              )
            ]
          )
        ),
        .reasoning(
          Transcript.Reasoning(
            id: "reas-1",
            segments: [.text(Transcript.TextSegment(id: "seg-5", content: "thinking"))]
          )
        ),
      ])

      let resolvedInstructions = ImageReference(attachmentLabel: "InstImg").resolved(in: transcript)
      let resolvedPrompt = ImageReference(attachmentLabel: "PromptImg").resolved(in: transcript)
      let resolvedToolOutput = ImageReference(attachmentLabel: "ToolImg").resolved(in: transcript)
      let resolvedResponse = ImageReference(attachmentLabel: "RespImg").resolved(in: transcript)
      let resolvedMissing = ImageReference(attachmentLabel: "Unknown").resolved(in: transcript)

      #expect(resolvedInstructions == instructionsImage)
      #expect(resolvedPrompt == promptImage)
      #expect(resolvedToolOutput == toolOutputImage)
      #expect(resolvedResponse == nil)
      #expect(resolvedMissing == nil)
    }

    @Test
    func imageReferenceResolvedPrecedenceAcrossAndWithinEntries() throws {
      let url1 = try #require(URL(string: "file:///tmp/first-entry-first-seg.png"))
      let url2 = try #require(URL(string: "file:///tmp/first-entry-second-seg.png"))
      let url3 = try #require(URL(string: "file:///tmp/second-entry-first-seg.png"))
      let url4 = try #require(URL(string: "file:///tmp/second-entry-second-seg.png"))
      let firstEntryFirstSeg = Transcript.ImageAttachment(imageURL: url1)
      let firstEntrySecondSeg = Transcript.ImageAttachment(imageURL: url2)
      let secondEntryFirstSeg = Transcript.ImageAttachment(imageURL: url3)
      let secondEntrySecondSeg = Transcript.ImageAttachment(imageURL: url4)
      let singleEntryTranscript = Transcript(entries: [
        .prompt(
          Transcript.Prompt(
            id: "p-1",
            segments: [
              .attachment(
                Transcript.AttachmentSegment(
                  id: "s-1",
                  content: .image(firstEntryFirstSeg),
                  label: "Dup"
                )
              ),
              .attachment(
                Transcript.AttachmentSegment(
                  id: "s-2",
                  content: .image(firstEntrySecondSeg),
                  label: "Dup"
                )
              ),
            ]
          )
        )
      ])
      let multiEntryTranscript = Transcript(entries: [
        .prompt(
          Transcript.Prompt(
            id: "p-1",
            segments: [
              .attachment(
                Transcript.AttachmentSegment(
                  id: "s-1",
                  content: .image(firstEntryFirstSeg),
                  label: "Dup"
                )
              )
            ]
          )
        ),
        .prompt(
          Transcript.Prompt(
            id: "p-2",
            segments: [
              .attachment(
                Transcript.AttachmentSegment(
                  id: "s-3",
                  content: .image(secondEntryFirstSeg),
                  label: "Dup"
                )
              ),
              .attachment(
                Transcript.AttachmentSegment(
                  id: "s-4",
                  content: .image(secondEntrySecondSeg),
                  label: "Dup"
                )
              ),
            ]
          )
        ),
      ])

      let singleResolved = ImageReference(attachmentLabel: "Dup").resolved(
        in: singleEntryTranscript
      )
      let multiResolved = ImageReference(attachmentLabel: "Dup").resolved(
        in: multiEntryTranscript
      )

      #expect(singleResolved == firstEntryFirstSeg)
      #expect(multiResolved == secondEntryFirstSeg)
    }
  }
#endif  // compiler(>=6.4)
