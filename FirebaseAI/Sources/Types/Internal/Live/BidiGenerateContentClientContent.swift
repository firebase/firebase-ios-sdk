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

import Foundation

/// Incremental update of the current conversation delivered from the client.
/// All the content here is unconditionally appended to the conversation
/// history and used as part of the prompt to the model to generate content.
///
/// A message here will interrupt any current model generation.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
@available(watchOS, unavailable)
struct BidiGenerateContentClientContent: Encodable {
  /// The content appended to the current conversation with the model.
  ///
  /// For single-turn queries, this is a single instance. For multi-turn
  /// queries, this is a repeated field that contains conversation history and
  /// latest request.
  let turns: [ModelContent]?

  /// If true, indicates that the server content generation should start with
  /// the currently accumulated prompt. Otherwise, the server will await
  /// additional messages before starting generation.
  let turnComplete: Bool?
}
