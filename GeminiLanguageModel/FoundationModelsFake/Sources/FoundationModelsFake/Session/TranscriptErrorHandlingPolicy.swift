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

#if compiler(>=6.4)
  /// A policy that determines how a session handles its transcript when an error occurs.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`TranscriptErrorHandlingPolicy`](https://developer.apple.com/documentation/foundationmodels/transcripterrorhandlingpolicy).
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct TranscriptErrorHandlingPolicy: Sendable {
    /// The ways a session can handle its transcript when an error occurs.
    enum Behavior: Sendable {
      /// Revert the transcript to its state before the most recent request.
      case revert

      /// Keep the transcript as is.
      case preserve
    }

    /// The transcript-handling behavior this policy represents.
    let behavior: Behavior

    /// A policy that reverts the transcript to its state before the most recent request.
    public static let revertTranscript = TranscriptErrorHandlingPolicy(behavior: .revert)

    /// A policy that preserves the transcript as is when an error occurs.
    public static let preserveTranscript = TranscriptErrorHandlingPolicy(behavior: .preserve)
  }
#endif  // compiler(>=6.4)
