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

/// Converts Gemini's running output token totals into the token count of each streamed part.
///
/// `LanguageModelSession` adds the token count of each streamed `appendText` event to the turn's
/// output usage. When Gemini reports running totals mid-stream (the Gemini Developer API does; the
/// Gemini Enterprise Agent Platform doesn't until the final chunk), reporting the tokens generated
/// since the previous part keeps `usage.output` close to the real value while streaming. The exact
/// usage, reported once the stream ends, replaces it.
///
/// Every count is at least 1. In testing, `LanguageModelSession` only produces a streamed snapshot
/// when the output token count rises (this isn't documented), so text sent with a count of 0
/// wouldn't be shown until a later event. When a chunk contains several parts, the first part
/// takes the chunk's new tokens and each later part adds 1, which the final usage corrects.
struct StreamedTokenCounter {
  /// The total number of tokens reported to the session so far.
  private(set) var reportedTokenCount = 0

  /// Returns the token count to send with the next streamed part, and records it.
  ///
  /// - Parameter runningTotal: Gemini's running total for this kind of output, such as
  ///   `UsageMetadata.candidatesTokenCount`, or `nil` if the chunk doesn't include one.
  /// - Returns: How far `runningTotal` exceeds the tokens already reported, or 1 if it doesn't
  ///   exceed them.
  mutating func nextTokenCount(forRunningTotal runningTotal: Int?) -> Int {
    let tokenCount = max(1, (runningTotal ?? 0) - reportedTokenCount)
    reportedTokenCount += tokenCount
    return tokenCount
  }
}
