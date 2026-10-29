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

struct OutputTests {
  /// The zip's size in the `Zip:` log line; compared with `ByteCountFormatter` itself, since its
  /// wording depends on the locale.
  @Test func formatsAFileSize() throws {
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-size-\(UUID().uuidString)")
    try Data(count: 2048).write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }
    #expect(formattedSize(ofFile: file.path)
      == ByteCountFormatter.string(fromByteCount: 2048, countStyle: .file))
  }

  /// A file that can't be read counts as empty: the size is only logged.
  @Test func aMissingFileHasNoSize() {
    #expect(formattedSize(ofFile: "/nonexistent/Firebase.zip")
      == ByteCountFormatter.string(fromByteCount: 0, countStyle: .file))
  }
}
