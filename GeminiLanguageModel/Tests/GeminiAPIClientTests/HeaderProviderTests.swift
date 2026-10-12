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

@testable import GeminiAPIClient

@Suite("HeaderProvider Tests")
struct HeaderProviderTests {
  @Test
  func callsUnderlyingClosure() async throws {
    let expectedHeaders = [
      "x-goog-api-key": "test-key-123",
      "x-custom-header": "custom-value",
    ]
    let provider = HeaderProvider {
      expectedHeaders
    }

    let headers = try await provider()

    #expect(headers == expectedHeaders)
  }

  @Test
  func propagatesErrorFromClosure() async {
    struct TestError: Error, Equatable {}
    let provider = HeaderProvider {
      throw TestError()
    }

    await #expect(throws: TestError.self) {
      _ = try await provider()
    }
  }

  @Test
  func equalityAndHashing() {
    let provider1 = HeaderProvider { ["key": "val1"] }
    let provider2 = HeaderProvider { ["key": "val1"] }
    let provider1Copy = provider1

    #expect(provider1 == provider1Copy)
    #expect(provider1.hashValue == provider1Copy.hashValue)
    #expect(provider1 != provider2)
  }

  @Test
  func storageInCollections() {
    let provider1 = HeaderProvider { ["key": "val1"] }
    let provider2 = HeaderProvider { ["key": "val2"] }

    let set: Set<HeaderProvider> = [provider1, provider2, provider1]

    #expect(set.count == 2)
    #expect(set.contains(provider1))
    #expect(set.contains(provider2))
  }
}
