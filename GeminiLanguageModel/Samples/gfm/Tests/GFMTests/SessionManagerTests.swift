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

  @Suite("SessionManager Tests")
  struct SessionManagerTests {
    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionURLResolution() {
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString,
        isDirectory: true
      )
      let manager = SessionManager(sessionsDirectory: tempDir)

      let namedURL = manager.resolveSessionURL(for: "test-session")
      let jsonURL = manager.resolveSessionURL(for: "test-session.json")
      let absoluteURL = manager.resolveSessionURL(for: "/tmp/custom.json")

      #expect(namedURL.path == tempDir.appendingPathComponent("test-session.json").path)
      #expect(jsonURL.path == tempDir.appendingPathComponent("test-session.json").path)
      #expect(absoluteURL.path == "/tmp/custom.json")
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func saveAndLoadSessionTranscript() throws {
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString,
        isDirectory: true
      )
      let manager = SessionManager(sessionsDirectory: tempDir)
      defer { try? FileManager.default.removeItem(at: tempDir) }
      let transcript = Transcript(entries: [])

      try manager.saveSession(transcript: transcript, nameOrPath: "my-test-session")
      let loaded = try manager.loadSession(nameOrPath: "my-test-session")
      let list = try manager.listSessionNames()

      #expect(loaded == transcript)
      #expect(list.contains("my-test-session"))
      let mostRecent = try manager.mostRecentSessionName()
      #expect(mostRecent == "my-test-session")
    }
  }
#endif
