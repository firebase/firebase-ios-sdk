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

  @Suite("LanguageModelErrorTests")
  struct LanguageModelErrorTests {
    @Test
    func contextSizeExceeded() {
      let payload = LanguageModelError.ContextSizeExceeded(
        contextSize: 4096,
        tokenCount: 5000,
        debugDescription: "context debug",
        metadata: [:]
      )
      let error = LanguageModelError.contextSizeExceeded(payload)

      #expect(error.errorDescription?.isEmpty == false)
      #expect(error.recoverySuggestion?.isEmpty == false)
      #expect(error.failureReason == nil)
      #expect(error.debugDescription == "context debug")
      #expect(String(describing: error) == "context debug")
      #expect(payload.contextSize == 4096)
      #expect(payload.tokenCount == 5000)
    }

    @Test
    func rateLimitedWithDate() {
      let date = Date(timeIntervalSinceReferenceDate: 821692800.0)
      let payload = LanguageModelError.RateLimited(
        resetDate: date,
        debugDescription: "rate debug"
      )
      let error = LanguageModelError.rateLimited(payload)

      #expect(error.errorDescription?.isEmpty == false)
      #expect(
        error.recoverySuggestion?.contains(date.formatted(date: .numeric, time: .complete)) == true
      )
      #expect(error.failureReason == nil)
      #expect(error.debugDescription == "rate debug")
      #expect(payload.resetDate == date)
    }

    @Test
    func rateLimitedWithoutDate() {
      let payload = LanguageModelError.RateLimited(
        resetDate: nil,
        debugDescription: "rate debug"
      )
      let error = LanguageModelError.rateLimited(payload)

      #expect(error.errorDescription?.isEmpty == false)
      #expect(error.recoverySuggestion?.isEmpty == false)
      #expect(error.failureReason == nil)
      #expect(error.debugDescription == "rate debug")
    }

    @Test
    func guardrailViolation() {
      let payload = LanguageModelError.GuardrailViolation(debugDescription: "guardrail debug")
      let error = LanguageModelError.guardrailViolation(payload)

      #expect(error.errorDescription?.isEmpty == false)
      #expect(error.recoverySuggestion?.isEmpty == false)
      #expect(error.failureReason == nil)
      #expect(error.debugDescription == "guardrail debug")
    }

    @Test
    func refusal() {
      let payload = LanguageModelError.Refusal(
        explanation: "I can't help with that.",
        debugDescription: "refusal debug"
      )
      let error = LanguageModelError.refusal(payload)

      #expect(error.errorDescription?.isEmpty == false)
      #expect(error.recoverySuggestion == nil)
      #expect(error.failureReason == nil)
      #expect(error.debugDescription == "refusal debug")
    }

    @Test
    func unsupportedCapability() {
      let cases: [(LanguageModelCapabilities.Capability, String)] = [
        (.vision, "images"),
        (.guidedGeneration, "guided generation"),
        (.reasoning, "reasoning"),
        (.toolCalling, "tool calling"),
      ]

      for (cap, capabilityName) in cases {
        let payload = LanguageModelError.UnsupportedCapability(
          capability: cap,
          debugDescription: "cap debug"
        )
        let error = LanguageModelError.unsupportedCapability(payload)

        #expect(error.errorDescription?.isEmpty == false)
        #expect(error.recoverySuggestion?.contains(capabilityName) == true)
        #expect(error.failureReason == nil)
        #expect(error.debugDescription == "cap debug")
      }
    }

    @Test
    func unsupportedTranscriptContent() {
      let payload = LanguageModelError.UnsupportedTranscriptContent(
        unsupportedContent: [],
        debugDescription: "content debug"
      )
      let error = LanguageModelError.unsupportedTranscriptContent(payload)

      #expect(error.errorDescription?.isEmpty == false)
      #expect(error.recoverySuggestion?.isEmpty == false)
      #expect(error.failureReason == nil)
      #expect(error.debugDescription == "content debug")
    }

    @Test
    func unsupportedGenerationGuide() {
      let payload = LanguageModelError.UnsupportedGenerationGuide(
        schemaName: "Person",
        debugDescription: "guide debug"
      )
      let error = LanguageModelError.unsupportedGenerationGuide(payload)

      #expect(error.errorDescription?.isEmpty == false)
      #expect(error.recoverySuggestion?.isEmpty == false)
      #expect(error.failureReason == nil)
      #expect(error.debugDescription == "guide debug")
    }

    @Test
    func unsupportedLanguageOrLocale() {
      let payload = LanguageModelError.UnsupportedLanguageOrLocale(
        languageCode: Locale.LanguageCode("fr"),
        debugDescription: "lang debug"
      )
      let error = LanguageModelError.unsupportedLanguageOrLocale(payload)

      #expect(error.errorDescription?.isEmpty == false)
      #expect(error.recoverySuggestion?.isEmpty == false)
      #expect(error.failureReason == nil)
      #expect(error.debugDescription == "lang debug")
    }

    @Test
    func timeout() {
      let payload = LanguageModelError.Timeout(debugDescription: "timeout debug")
      let error = LanguageModelError.timeout(payload)

      #expect(error.errorDescription?.isEmpty == false)
      #expect(error.recoverySuggestion?.isEmpty == false)
      #expect(error.failureReason == nil)
      #expect(error.debugDescription == "timeout debug")
    }
  }
#endif  // compiler(>=6.4)
