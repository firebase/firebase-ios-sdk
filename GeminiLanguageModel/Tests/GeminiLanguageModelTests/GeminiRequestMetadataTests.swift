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
  import GeminiTestUtilities
  import Testing

  @testable import GeminiLanguageModel

  @Suite("GeminiRequestMetadata Tests", .requireFoundationModels)
  struct GeminiRequestMetadataTests {
    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func encodeAndDecodeThinkingSummariesAuto() {
      let metadata = GeminiRequestMetadata(thinkingSummaries: .auto)
      let content = metadata.generatedContent

      let decoded = GeminiRequestMetadata(content)

      #expect(decoded.thinkingSummaries == .auto)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func encodeAndDecodeThinkingSummariesOff() {
      let metadata = GeminiRequestMetadata(thinkingSummaries: .off)
      let content = metadata.generatedContent

      let decoded = GeminiRequestMetadata(content)

      #expect(decoded.thinkingSummaries == .off)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func encodeAndDecodeThinkingSummariesNil() {
      let metadata = GeminiRequestMetadata(thinkingSummaries: nil)
      let content = metadata.generatedContent

      let decoded = GeminiRequestMetadata(content)

      #expect(decoded.thinkingSummaries == nil)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func decodeFromBooleanContent() {
      let boolTrueContent = GeneratedContent(kind: .bool(true))
      let decodedTrue = GeminiRequestMetadata(boolTrueContent)
      #expect(decodedTrue.thinkingSummaries == .auto)

      let boolFalseContent = GeneratedContent(kind: .bool(false))
      let decodedFalse = GeminiRequestMetadata(boolFalseContent)
      #expect(decodedFalse.thinkingSummaries == .off)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func dictionaryGeminiHelper() {
      let dict: [String: any ConvertibleToGeneratedContent] = .gemini(thinkingSummaries: .auto)

      #expect(dict.count == 1)
      let entry = dict[GeminiRequestMetadata.metadataKey]
      let geminiMetadata = entry as? GeminiRequestMetadata
      #expect(geminiMetadata?.thinkingSummaries == .auto)
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
