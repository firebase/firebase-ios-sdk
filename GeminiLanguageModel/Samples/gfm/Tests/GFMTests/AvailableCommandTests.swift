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

import Foundation
import Testing

@testable import GFMCore

#if canImport(FoundationModels) && compiler(>=6.4)
  import FoundationModels

  @Suite("AvailableCommand Tests")
  struct AvailableCommandTests {
    @Test
    func modelChoiceDisplayNames() {
      let geminiChoice = ModelChoice.gemini
      let systemChoice = ModelChoice.system

      #expect(geminiChoice.displayName == "Gemini model")
      #expect(systemChoice.displayName == "System model")
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func geminiAvailabilityWithExplicitKey() {
      let resolver = ModelResolver(explicitAPIKey: "fake-key")

      let status = resolver.checkAvailability(for: .gemini)

      #expect(status == .available)
      #expect(status.isAvailable == true)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func geminiAvailabilityWithoutKey() {
      let resolver = ModelResolver(explicitAPIKey: nil)

      // Only check if no environment variable is set
      if resolver.resolveAPIKey() == nil {
        let status = resolver.checkAvailability(for: .gemini)

        #expect(status == .unavailable(reason: "missingAPIKey"))
        #expect(status.isAvailable == false)
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func systemAvailabilityEvaluation() {
      let resolver = ModelResolver()

      let status = resolver.checkAvailability(for: .system)

      switch status {
      case .available:
        #expect(status.isAvailable == true)
      case .unavailable(let reason):
        #expect(!reason.isEmpty)
        #expect(status.isAvailable == false)
      }
    }
  }
#endif
