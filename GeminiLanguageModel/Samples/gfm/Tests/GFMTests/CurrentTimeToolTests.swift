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

  @Suite("CurrentTimeTool Tests")
  struct CurrentTimeToolTests {
    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func toolMetadata() {
      let tool = CurrentTimeTool()

      #expect(tool.name == "current_time")
      #expect(!tool.description.isEmpty)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func toolCallExecution() async throws {
      let tool = CurrentTimeTool()

      let result = try await tool.call(arguments: CurrentTimeTool.Arguments())

      #expect(!result.isEmpty)
      #expect(result.count > 5)
    }
  }
#endif
