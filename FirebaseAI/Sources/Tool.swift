// Copyright 2024 Google LLC
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

import CoreLocation
import Foundation
#if canImport(FoundationModels)
  import FoundationModels
#endif // canImport(FoundationModels)

/// Structured representation of a function declaration.
///
/// This `FunctionDeclaration` is a representation of a block of code that can be used as a ``Tool``
/// by the model and executed by the client.
public struct FunctionDeclaration: Sendable {
  enum Kind {
    case manual
    case foundationModels(any Sendable)
  }

  /// The name of the function.
  let name: String

  /// A brief description of the function.
  let description: String

  /// Describes the parameters to this function; must be of type `DataType.object`.
  let parameters: Schema?

  let parametersJSONSchema: FirebaseAI.GenerationSchema?

  let responseJSONSchema: JSONObject?

  let kind: Kind

  /// Constructs a new `FunctionDeclaration`.
  ///
  /// - Parameters:
  ///   - name: The name of the function; must be a-z, A-Z, 0-9, or contain underscores and dashes,
  ///   with a maximum length of 63.
  ///   - description: A brief description of the function.
  ///   - parameters: Describes the parameters to this function.
  ///   - optionalParameters: The names of parameters that may be omitted by the model in function
  ///   calls; by default, all parameters are considered required.
  public init(name: String, description: String, parameters: [String: Schema],
              optionalParameters: [String] = []) {
    self.name = name
    self.description = description
    self.parameters = Schema.object(
      properties: parameters,
      optionalProperties: optionalParameters,
      nullable: false
    )
    parametersJSONSchema = nil
    responseJSONSchema = nil
    kind = .manual
  }

  #if compiler(>=6.2.3)
    #if canImport(FoundationModels)
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      init<T: FoundationModels.Tool>(foundationModelsTool: T) {
        name = foundationModelsTool.name
        description = foundationModelsTool.description
        parameters = nil
        parametersJSONSchema = FirebaseAI.GenerationSchema(foundationModelsTool.parameters)
        // Gemini requires function responses to be JSON objects (not arrays or primitives); don't
        // provide a `responseJSONSchema` in this scenario since it is optional.
        if let generableOutputMetatype = T.Output.self as? any FoundationModels.Generable.Type,
           let responseSchema = try? FirebaseAI.GenerationSchema(
             generableOutputMetatype.generationSchema
           ).toGeminiJSONSchema(), responseSchema["type"] == .string("object") {
          responseJSONSchema = responseSchema
        } else {
          responseJSONSchema = nil
        }
        kind = .foundationModels(foundationModelsTool)
      }
    #endif // canImport(FoundationModels)
  #endif // compiler(>=6.2.3)
}

/// A tool that allows the generative model to connect to Google Search to access and incorporate
/// up-to-date information from the web into its responses.
///
/// > Important: When using this feature, you are required to comply with the
/// "Grounding with Google Search" usage requirements for your chosen API provider:
/// [Gemini Developer API](https://ai.google.dev/gemini-api/terms#grounding-with-google-search)
/// or Vertex AI Gemini API (see [Service Terms](https://cloud.google.com/terms/service-terms)
/// section within the Service Specific Terms).
public struct GoogleSearch: Sendable {
  public init() {}
}

/// A helper tool that the model may use when generating responses.
///
/// A `Tool` is a piece of code that enables the system to interact with external systems to perform
/// an action, or set of actions, outside of knowledge and scope of the model.
public struct Tool: Sendable {
  /// A list of `FunctionDeclarations` available to the model.
  let functionDeclarations: [FunctionDeclaration]?

  /// Specifies the Google Search configuration.
  let googleSearch: GoogleSearch?

  /// Specifies the Google Maps configuration.
  let googleMaps: GoogleMaps?

  let codeExecution: CodeExecution?
  let urlContext: URLContext?

  init(functionDeclarations: [FunctionDeclaration]? = nil,
       googleSearch: GoogleSearch? = nil,
       googleMaps: GoogleMaps? = nil,
       urlContext: URLContext? = nil,
       codeExecution: CodeExecution? = nil) {
    self.functionDeclarations = functionDeclarations
    self.googleSearch = googleSearch
    self.googleMaps = googleMaps
    self.urlContext = urlContext
    self.codeExecution = codeExecution
  }
}

/// Configuration for specifying function calling behavior.
public struct FunctionCallingConfig: Sendable {
  /// Defines the execution behavior for function calling by defining the execution mode.
  enum Mode: String {
    case auto = "AUTO"
    case any = "ANY"
    case none = "NONE"
  }

  /// Specifies the mode in which function calling should execute.
  let mode: Mode?

  /// A set of function names that, when provided, limits the functions the model will call.
  let allowedFunctionNames: [String]?

  init(mode: FunctionCallingConfig.Mode? = nil, allowedFunctionNames: [String]? = nil) {
    self.mode = mode
    self.allowedFunctionNames = allowedFunctionNames
  }

  /// Creates a function calling config where the model calls functions at its discretion.
  ///
  /// > Note: This is the default behavior.
  public static func auto() -> FunctionCallingConfig {
    return FunctionCallingConfig(mode: .auto)
  }

  /// Creates a function calling config where the model will always call a provided function.
  ///
  ///  - Parameters:
  ///    - allowedFunctionNames: A set of function names that, when provided, limits the functions
  ///    that the model will call.
  public static func any(allowedFunctionNames: [String]? = nil) -> FunctionCallingConfig {
    return FunctionCallingConfig(mode: .any, allowedFunctionNames: allowedFunctionNames)
  }

  /// Creates a function calling config where the model will never call a function.
  ///
  /// > Note: This can also be achieved by not passing any ``FunctionDeclaration`` tools when
  /// > instantiating the model.
  public static func none() -> FunctionCallingConfig {
    return FunctionCallingConfig(mode: FunctionCallingConfig.Mode.none)
  }
}

/// Tool configuration for any `Tool` specified in the request.
public struct ToolConfig: Sendable {
  let functionCallingConfig: FunctionCallingConfig?
  let retrievalConfig: RetrievalConfig?

  public init(functionCallingConfig: FunctionCallingConfig? = nil,
              retrievalConfig: RetrievalConfig? = nil) {
    self.functionCallingConfig = functionCallingConfig
    self.retrievalConfig = retrievalConfig
  }
}

/// Retrieval configuration.
public struct RetrievalConfig: Sendable, Encodable {
  /// The location for the search.
  public let latLng: CLLocationCoordinate2D?
  /// The language code of the user.
  public let languageCode: String?

  public init(latLng: CLLocationCoordinate2D? = nil, languageCode: String? = nil) {
    self.latLng = latLng
    self.languageCode = languageCode
  }
}

extension CLLocationCoordinate2D: @unchecked Sendable {}

extension CLLocationCoordinate2D: Encodable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(latitude, forKey: .latitude)
    try container.encode(longitude, forKey: .longitude)
  }

  enum CodingKeys: String, CodingKey {
    case latitude
    case longitude
  }
}

// MARK: - ToolRepresentable Conformances

extension FirebaseAILogic.Tool: ToolRepresentable {
  public var toolRepresentation: FirebaseAILogic.Tool {
    return self
  }
}

public extension ToolRepresentable where Self == FirebaseAILogic.Tool {
  /// Creates a tool that allows the model to perform function calling.
  ///
  /// Function calling can be used to provide data to the model that was not known at the time it
  /// was trained (for example, the current date or weather conditions) or to allow it to interact
  /// with external systems (for example, making an API request or querying/updating a database).
  /// For more details and use cases, see [Function calling using the Gemini
  /// API](http://firebase.google.com/docs/vertex-ai/function-calling?platform=ios).
  ///
  /// - Parameters:
  ///   - functionDeclarations: A list of `FunctionDeclarations` available to the model that can be
  ///   used for function calling.
  ///   The model or system does not execute the function. Instead the defined function may be
  ///   returned as a ``FunctionCallPart`` with arguments to the client side for execution. The
  ///   model may decide to call none, some or all of the declared functions; this behavior may be
  ///   configured by specifying a ``ToolConfig`` when instantiating the model. When a
  ///   ``FunctionCallPart`` is received, the next conversation turn may contain a
  ///   ``FunctionResponsePart`` in ``ModelContent/parts`` with a ``ModelContent/role`` of
  ///   `"function"`; this response contains the result of executing the function on the client,
  ///   providing generation context for the model's next turn.
  static func functionDeclarations(_ functionDeclarations: [FunctionDeclaration]) -> Tool {
    return self.init(functionDeclarations: functionDeclarations)
  }

  #if compiler(>=6.2.3)
    #if canImport(FoundationModels)
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      static func autoFunctionDeclaration(_ tool: any FoundationModels.Tool) -> Tool {
        return self.init(functionDeclarations: [FunctionDeclaration(foundationModelsTool: tool)])
      }
    #endif // canImport(FoundationModels)
  #endif // compiler(>=6.2.3)

  /// Creates a tool that allows the model to use Grounding with Google Search.
  ///
  /// Grounding with Google Search can be used to allow the model to connect to Google Search to
  /// access and incorporate up-to-date information from the web into it's responses.
  ///
  /// > Important: When using this feature, you are required to comply with the
  /// "Grounding with Google Search" usage requirements for your chosen API provider:
  /// [Gemini Developer API](https://ai.google.dev/gemini-api/terms#grounding-with-google-search)
  /// or Vertex AI Gemini API (see [Service Terms](https://cloud.google.com/terms/service-terms)
  /// section within the Service Specific Terms).
  ///
  /// - Parameters:
  ///   - googleSearch: An empty ``GoogleSearch`` object. The presence of this object in the list
  ///     of tools enables the model to use Google Search.
  ///
  /// - Returns: A `Tool` configured for Google Search.
  static func googleSearch(_ googleSearch: GoogleSearch = GoogleSearch()) -> Tool {
    return FirebaseAILogic.Tool(googleSearch: googleSearch)
  }

  /// Creates a tool that allows the model to use Grounding with Google Maps.
  ///
  /// Grounding with Google Maps can be used to allow the model to connect to Google Maps to
  /// access and incorporate up-to-date information from the web into it's responses.
  ///
  /// > Important: When using this feature, you are required to comply with the
  /// "Grounding with Google Maps" usage requirements for your chosen API provider.
  ///
  /// - Parameters:
  ///   - googleMaps: A ``GoogleMaps`` object. The presence of this object in the list
  ///     of tools enables the model to use Google Maps.
  ///
  /// - Returns: A `Tool` configured for Google Maps.
  static func googleMaps() -> Tool {
    return self.init(googleMaps: GoogleMaps())
  }

  /// Creates a tool that allows you to provide additional context to the models in the form of
  /// public web URLs.
  ///
  /// By including URLs in your request, the Gemini model will access the content from those pages
  /// to inform and enhance its response.
  static func urlContext() -> Tool {
    return self.init(urlContext: URLContext())
  }

  /// Creates a tool that allows the model to execute code.
  ///
  /// For more details, see ``CodeExecution``.
  static func codeExecution() -> Tool {
    return self.init(codeExecution: CodeExecution())
  }
}

// MARK: - Automatic Function Calling Helpers

#if compiler(>=6.2.3)
  extension FunctionDeclaration {
    static func toFunctionResponse(output: JSONValue,
                                   functionCall: FunctionCallPart) -> FunctionResponsePart {
      let outputJSONObject: JSONObject
      if case let .object(value) = output {
        outputJSONObject = value
      } else {
        outputJSONObject = ["result": output]
      }

      return FunctionResponsePart(
        name: functionCall.name,
        response: outputJSONObject,
        functionId: functionCall.functionId
      )
    }
  }

  #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    extension FunctionDeclaration {
      static func call<T: FoundationModels.Tool>(tool: T,
                                                 functionCall: FunctionCallPart) async throws
        -> FunctionResponsePart {
        let arguments = try T.Arguments(functionCall.args.firebaseGeneratedContent.generatedContent)
        let output = try await tool.call(arguments: arguments)
        let outputErrorMessage = """
        Unsupported output type "\(output.self)" for tool "\(tool.name)"; the associated type \
        `Output` for the `FoundationModels.Tool` must conform to `ConvertibleToGeneratedContent`.
        """
        assert(output is (any FoundationModels.ConvertibleToGeneratedContent), outputErrorMessage)
        guard let output = output as? (any FoundationModels.ConvertibleToGeneratedContent) else {
          throw NSError(
            domain: "\(Constants.baseErrorDomain).\(Self.self)",
            code: AILog.MessageCode.invalidToolOutputType.rawValue,
            userInfo: [NSLocalizedDescriptionKey: outputErrorMessage]
          )
        }
        let generatedContent = output.generatedContent
        let firebaseGeneratedContent = FirebaseAI.GeneratedContent(
          kind: generatedContent.kind,
          id: FirebaseAI.GenerationID(responseID: nil, generationID: generatedContent.id),
          isComplete: generatedContent.isComplete
        )
        let outputJSONValue = try JSONValue(firebaseGeneratedContent)

        return toFunctionResponse(output: outputJSONValue, functionCall: functionCall)
      }
    }
  #endif // canImport(FoundationModels)
#endif // compiler(>=6.2.3)

// MARK: - Codable Conformance

extension FunctionDeclaration: Encodable {
  enum CodingKeys: String, CodingKey {
    case name
    case description
    case parameters
    case parametersJSONSchema = "parametersJsonSchema"
    case responseJSONSchema = "responseJsonSchema"
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(description, forKey: .description)
    try container.encodeIfPresent(parameters, forKey: .parameters)
    #if canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
      if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
        try container.encodeIfPresent(parametersJSONSchema, forKey: .parametersJSONSchema)
        try container.encodeIfPresent(responseJSONSchema, forKey: .responseJSONSchema)
      }
    #endif // canImport(FoundationModels) && IS_FOUNDATION_MODELS_SUPPORTED_PLATFORM
  }
}

extension Tool: Encodable {}

extension FunctionCallingConfig: Encodable {}

extension FunctionCallingConfig.Mode: Encodable {}

extension GoogleSearch: Encodable {}

extension ToolConfig: Encodable {}
