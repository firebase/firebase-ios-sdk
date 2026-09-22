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

/// Tool details that the model may use to generate a response.
///
/// A tool is a piece of code that enables the system to interact with external systems to perform
/// an action, or set of actions, outside of knowledge and scope of the model. A tool object should
/// contain exactly one type of tool.
public struct TemplateTool: Sendable {
  /// A list of user-provided functions for function calling.
  ///
  /// For functions whose names are listed in the template frontmatter, the model may decide to
  /// call a subset of these functions by populating ``FunctionCallPart`` in the response. The user
  /// should provide a ``FunctionResponsePart`` for each function call in the next turn.
  let functionDeclarations: [FunctionDeclaration]?

  /// A Google Maps tool.
  let googleMaps: GoogleMaps?

  /// Initializes a new `TemplateTool`.
  ///
  /// - Parameters:
  ///   - functionDeclarations: A list of user-provided functions for function calling.
  ///   - googleMaps: A Google Maps tool configuration.
  init(functionDeclarations: [FunctionDeclaration]? = nil, googleMaps: GoogleMaps? = nil) {
    self.functionDeclarations = functionDeclarations
    self.googleMaps = googleMaps
  }
}

public extension TemplateTool {
  /// Creates a tool that allows the model to perform function calling.
  ///
  /// Function calling can be used to provide data to the model that was not known at the time it
  /// was trained (for example, the current date or weather conditions) or to allow it to interact
  /// with external systems (for example, making an API request or querying/updating a database).
  /// For more details and use cases, see [Function calling using the Gemini
  /// API](https://firebase.google.com/docs/ai-logic/function-calling).
  ///
  /// - Parameter functionDeclarations: A list of ``FunctionDeclaration``s available to the model
  ///   that can be used for function calling.
  ///   The model or system does not execute the function. Instead the defined function may be
  ///   returned as a ``FunctionCallPart`` with arguments to the client side for execution. The
  ///   model may decide to call none, some or all of the declared functions. When a
  ///   ``FunctionCallPart`` is received, the next conversation turn must contain a
  ///   ``FunctionResponsePart`` in ``ModelContent/parts`` with a ``ModelContent/role`` of
  ///   `"user"`; this response contains the result of executing the function on the client,
  ///   providing generation context for the model's next turn.
  static func functionDeclarations(_ functionDeclarations: [FunctionDeclaration])
    -> TemplateTool {
    return self.init(functionDeclarations: functionDeclarations)
  }

  /// Creates a tool that allows the model to use Grounding with Google Maps.
  ///
  /// Grounding with Google Maps can be used to allow the model to connect to Google Maps to
  /// access and incorporate up-to-date information from the web into its responses.
  ///
  /// > Important: When using this feature, you are required to comply with the
  /// "Grounding with Google Maps" usage requirements for your chosen API provider.
  ///
  /// - Returns: A ``TemplateTool`` configured with the ``GoogleMaps`` tool.
  static func googleMaps() -> TemplateTool {
    return self.init(googleMaps: GoogleMaps())
  }
}
