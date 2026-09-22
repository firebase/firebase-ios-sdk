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

/// Tool configuration options for tools used with server prompt templates.
///
/// In Server Prompt Templates, `TemplateToolConfig` allows the client application to supply
/// runtime configuration parameters for tools declared in the template's frontmatter.
///
/// For more details, see
/// [Grounding with Google Maps in server prompt templates](https://firebase.google.com/docs/ai-logic/server-prompt-templates/syntax-and-examples#grounding-with-google-maps).
public struct TemplateToolConfig: Sendable, Encodable {
  /// Configures how the model should use retrieval options for Grounding with Google Maps.
  public let retrievalConfig: RetrievalConfig?

  /// Constructs a new `TemplateToolConfig`.
  ///
  /// - Parameter retrievalConfig: Configures retrieval options (such as user location coordinates
  ///   and language preferences) for Grounding with Google Maps.
  public init(retrievalConfig: RetrievalConfig? = nil) {
    self.retrievalConfig = retrievalConfig
  }
}
