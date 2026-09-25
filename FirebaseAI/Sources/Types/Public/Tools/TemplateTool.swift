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

/// A tool that a model may use when generating responses with server prompt templates.
///
/// In Server Prompt Templates, tools available to the model must be listed in the `tools` object of
/// the template's frontmatter. Server-side tools like Grounding with Google Search
/// (`googleSearch`), Python code execution (`codeExecution`), and URL context (`urlContext`) are
/// configured directly in the template and do not require client-side tool objects.
///
/// `TemplateTool` is used to configure client-involved tools:
/// - ``functionDeclarations(_:)``: Provides client-side schemas or declarations for functions
///   listed in the template.
/// - ``googleMaps()``: Configures Grounding with Google Maps.
///
/// For more details, see
/// [Tool use in server prompt templates](https://firebase.google.com/docs/ai-logic/server-prompt-templates/syntax-and-examples#tools)
/// and [Function calling with server prompt templates](https://firebase.google.com/docs/ai-logic/server-prompt-templates/multi-turn-interactions#function-calling).
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
  /// Creates a tool that allows the model to perform function calling in server prompt templates.
  ///
  /// In Server Prompt Templates, functions available to the model must be listed in the `tools`
  /// object of the template's frontmatter. Defining schemas in client code via this method allows
  /// you to provide or override schemas for functions specified in the template.
  ///
  /// If a function's schema is provided in client code, it overrides any schema specified in the
  /// template. The function name in the ``FunctionDeclaration`` must match the function name
  /// listed in the template.
  ///
  /// > Note: Only the ``FunctionDeclaration``'s name and schemas are sent to the backend. The
  /// `description` is required when constructing a ``FunctionDeclaration``, but server prompt
  /// templates source function descriptions from the template's frontmatter, so any description
  /// provided in client code is ignored. To change how a function is described to the model, edit
  /// the template rather than the client code.
  ///
  /// - Parameter functionDeclarations: A list of ``FunctionDeclaration``s available to the model
  ///   that can be used for function calling.
  ///   The model does not execute the function directly. Instead, it returns a ``FunctionCallPart``
  ///   with arguments to the client for execution. When a ``FunctionCallPart`` is received, the
  ///   next conversation turn must supply a ``FunctionResponsePart`` in ``ModelContent/parts`` with
  ///   a ``ModelContent/role`` of `"user"`, providing the execution result to the model.
  static func functionDeclarations(_ functionDeclarations: [FunctionDeclaration])
    -> TemplateTool {
    return self.init(functionDeclarations: functionDeclarations)
  }

  /// Creates a tool that allows the model to use Grounding with Google Maps.
  ///
  /// Grounding with Google Maps connects the model to Google Maps to access geospatial data and
  /// incorporate location-aware information into responses. To use this tool, `googleMaps` must
  /// also be listed in the `tools` object of the template's frontmatter.
  ///
  /// You can optionally configure location coordinates and language preferences by passing a
  /// ``TemplateToolConfig`` with a ``RetrievalConfig`` when initializing the model.
  ///
  /// > Important: When using this feature, you are required to comply with the
  /// "Grounding with Google Maps" usage requirements for your chosen API provider. For more
  /// details, see
  /// [Grounding with Google Maps](https://firebase.google.com/docs/ai-logic/grounding-google-maps).
  ///
  /// - Returns: A ``TemplateTool`` configured with the ``GoogleMaps`` tool.
  static func googleMaps() -> TemplateTool {
    return self.init(googleMaps: GoogleMaps())
  }
}
