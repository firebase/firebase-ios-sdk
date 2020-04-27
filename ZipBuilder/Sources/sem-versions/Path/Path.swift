/*
 * Copyright 2020 Google LLC
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

import Darwin

typealias Path = String

extension Path {
  func glob(pattern: String) -> [Path] {
    // glob behaves differently in Ruby:
    // - "**/*.m" will match to .m files in the directory and subdirectories in Ruby
    // - "**/*.m" will match to .m in subdirectories only for BSD glob
    // To match Ruby behaviour let's perform two searches, one for the original pattern and another for the pattern with "**/" removed.

    let subDirPaths = _nativeGlob(pattern: pattern)

    let dirPattern = pattern.replacingOccurrences(of: "**/", with: "")
    let dirPaths = _nativeGlob(pattern: dirPattern)
    return dirPaths + subDirPaths
  }

  private func _nativeGlob(pattern: String) -> [Path] {
    let fullPathPattern = appending("/\(pattern)")
    var globInstance = glob_t()
    let cPattern = strdup(fullPathPattern)
    defer {
      globfree(&globInstance)
      free(cPattern)
    }

    let flags = GLOB_TILDE | GLOB_BRACE | GLOB_MARK
    if Darwin.glob(cPattern, flags, nil, &globInstance) == 0 {
      let matchCount = globInstance.gl_matchc
      return (0 ..< Int(matchCount)).compactMap { index in
        guard
          let cPath = globInstance.gl_pathv[index],
          let path = String(validatingUTF8: cPath)
        else {
          return nil
        }

        return path
      }
    }

    // GLOB_NOMATCH
    return []
  }
}
