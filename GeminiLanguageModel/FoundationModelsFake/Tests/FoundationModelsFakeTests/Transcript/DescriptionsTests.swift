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
  import Testing

  @testable import FoundationModelsFake

  @Suite("Transcript descriptions")
  struct TranscriptDescriptionsTests {
    @Test
    func promptDescriptionShowsResponseFormatName() throws {
      let url = try #require(URL(string: "data:,"))
      let prompt = Transcript.Prompt(
        id: "p",
        segments: [
          .text(Transcript.TextSegment(content: "Describe this person and photo.")),
          .attachment(
            Transcript.AttachmentSegment(
              id: "prompt-attachment-1",
              content: .image(Transcript.ImageAttachment(imageURL: url))
            )
          ),
        ],
        responseFormat: Transcript.ResponseFormat(schema: String.generationSchema)
      )

      let description = prompt.description

      #expect(description.contains("Describe this person and photo."))
      #expect(description.contains("prompt-attachment-1"))
      #expect(description.contains("String"))
    }
  }
#endif  // compiler(>=6.4)
