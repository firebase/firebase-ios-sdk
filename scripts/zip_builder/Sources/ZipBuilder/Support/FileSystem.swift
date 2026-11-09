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

/// Entries of a directory, sorted, without `.DS_Store`, `__MACOSX` and other hidden files.
func visibleEntries(of directory: Path) -> [String] {
  let entries = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
  return entries.filter { !$0.hasPrefix(".") && $0 != "__MACOSX" }.sorted()
}

func isDirectory(_ path: Path) -> Bool {
  var isDirectory: ObjCBool = false
  return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
    && isDirectory.boolValue
}
