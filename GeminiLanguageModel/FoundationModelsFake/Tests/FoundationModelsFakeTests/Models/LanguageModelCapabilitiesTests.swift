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

  @Suite("LanguageModelCapabilitiesTests")
  struct LanguageModelCapabilitiesTests {
    @Test
    func capabilitiesContainment() throws {
      let capabilities = LanguageModelCapabilities([.toolCalling, .vision])

      let containsVision = capabilities.contains(.vision)
      let containsToolCalling = capabilities.contains(.toolCalling)
      let containsReasoning = capabilities.contains(.reasoning)
      let containsGuidedGeneration = capabilities.contains(.guidedGeneration)

      #expect(containsVision)
      #expect(containsToolCalling)
      #expect(!containsReasoning)
      #expect(!containsGuidedGeneration)
    }

    @Test
    func capabilityEqualityAndHashing() {
      let cap1 = LanguageModelCapabilities.Capability.vision
      let cap2 = LanguageModelCapabilities.Capability.vision
      let cap3 = LanguageModelCapabilities.Capability.reasoning

      #expect(cap1 == cap2)
      #expect(cap1 != cap3)
      #expect(cap1.hashValue == cap2.hashValue)
    }

    @Test
    func capabilitiesDescription() {
      let capabilities = LanguageModelCapabilities([.vision])

      let desc = String(describing: capabilities)

      #expect(desc.contains("LanguageModelCapabilities"))
      #expect(desc.contains("vision"))
    }
  }
#endif  // compiler(>=6.4)
