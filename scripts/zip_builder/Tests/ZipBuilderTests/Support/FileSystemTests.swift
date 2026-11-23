/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import Testing
@testable import ZipBuilder

struct FileSystemTests {
  @Test func visibleEntriesAreSortedWithoutHiddenFiles() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(atPath: directory) }
    for name in ["b.txt", "a", ".DS_Store", ".hidden", "__MACOSX"] {
      FileManager.default.createFile(atPath: directory + "/" + name, contents: nil)
    }
    #expect(visibleEntries(of: directory) == ["a", "b.txt"])
    #expect(visibleEntries(of: directory + "/missing") == [])
  }

  @Test func isDirectoryIsFalseForFilesAndMissingPaths() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(atPath: directory) }
    FileManager.default.createFile(atPath: directory + "/file", contents: nil)
    #expect(isDirectory(directory))
    #expect(!isDirectory(directory + "/file"))
    #expect(!isDirectory(directory + "/missing"))
  }

  private func temporaryDirectory() throws -> Path {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-fs-\(UUID().uuidString)").path
    try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
    return directory
  }
}
