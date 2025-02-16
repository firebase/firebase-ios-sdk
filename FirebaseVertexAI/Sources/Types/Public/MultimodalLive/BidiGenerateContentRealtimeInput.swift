// Copyright 2025 Google LLC
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

// User input that is sent in real time.
//
// This is different from `ClientContentUpdate` in a few ways:
//
// - Can be sent continuously without interruption to model generation.
// - If there is a need to mix data interleaved across the
//   `ClientContentUpdate` and the `RealtimeUpdate`, server attempts to
//   optimize for best response, but there are no guarantees.
// - End of turn is not explicitly specified, but is rather derived from user
//   activity (for example, end of speech).
// - Even before the end of turn, the data is processed incrementally
//   to optimize for a fast start of the response from the model.
// - Is always assumed to be the user's input (cannot be used to populate
//   conversation history).
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct BidiGenerateContentRealtimeInput {
  // Inlined bytes data for media input.
  let mediaChunks: [InlineData]
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension BidiGenerateContentRealtimeInput: Encodable {}
