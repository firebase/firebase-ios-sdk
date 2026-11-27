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
@preconcurrency import PackageGraph

/// A wrapper only exists for SwiftPM: its compiled sources and public headers are all code-free.
/// A code-free target with resources other than a privacy manifest still ships them, so it's a
/// framework.
func isWrapper(_ module: ResolvedModule) -> Bool {
  if module.underlying.resources.contains(where: { $0.path.basename != privacyManifestName }) {
    return false
  }
  let publicHeaders = headers(of: module).filter { $0.visibility == .public }.map(\.path)
  return (module.sources.paths + publicHeaders).allSatisfy { isCodeFreeFile($0.pathString) }
}

/// Whether the file at the absolute `path` is code-free; an unreadable file isn't.
func isCodeFreeFile(_ path: Path) -> Bool {
  (try? String(contentsOfFile: path, encoding: .utf8)).map(isCodeFree) ?? false
}

/// Whether nothing is left of `text` after removing comments, preprocessor directives (with
/// their `\` continuation lines), and whitespace.
func isCodeFree(_ text: String) -> Bool {
  var continuesDirective = false
  for line in removingComments(text).split(whereSeparator: \.isNewline) {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    if continuesDirective || trimmed.hasPrefix("#") {
      continuesDirective = trimmed.hasSuffix("\\")
    } else if !trimmed.isEmpty {
      return false
    }
  }
  return true
}

/// `text` without `//` and `/* */` comments. String and character literals are kept, and a block
/// comment keeps its line breaks.
///
/// Reads one character per step; the state says what that character is part of.
func removingComments(_ text: String) -> String {
  enum State {
    case code
    case quoted(Character) // inside a literal opened by this quote
    case lineComment
    case blockComment
  }
  var state = State.code
  var rest = Array(text)[...]
  var result = ""
  while let character = rest.popFirst() {
    switch state {
    case .code:
      if character == "/", rest.first == "/" {
        rest.removeFirst()
        state = .lineComment
      } else if character == "/", rest.first == "*" {
        rest.removeFirst()
        state = .blockComment
      } else {
        if character == "\"" || character == "'" {
          state = .quoted(character)
        }
        result.append(character)
      }
    case let .quoted(open):
      result.append(character)
      if character == "\\", let escaped = rest.popFirst() {
        result.append(escaped)
      } else if character == open || character.isNewline {
        state = .code // an unterminated literal ends at the line
      }
    case .lineComment:
      // The line break isn't part of the comment.
      if character.isNewline {
        result.append(character)
        state = .code
      }
    case .blockComment:
      if character == "*", rest.first == "/" {
        rest.removeFirst()
        state = .code
      } else if character.isNewline {
        result.append("\n") // keeps the line structure for `isCodeFree`'s directive check
      }
    }
  }
  return result
}
