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

import Foundation
internal import GenerateContentAPI
#if canImport(FoundationModels)
  import FoundationModels
#endif // canImport(FoundationModels)

/// A discrete piece of data in a media format interpretable by an AI model.
///
/// Within a single value of ``Part``, different data types may not mix.
public protocol Part: PartsRepresentable, Codable, Sendable, Equatable {
  /// Indicates whether this `Part` is a summary of the model's internal thinking process.
  ///
  /// When `includeThoughts` is set to `true` in ``ThinkingConfig``, the model may return one or
  /// more "thought" parts that provide insight into how it reasoned through the prompt to arrive
  /// at the final answer. These parts will have `isThought` set to `true`.
  var isThought: Bool { get }
}

/// A text part containing a string value.
public struct TextPart: Part {
  /// Text value.
  public let text: String

  public var isThought: Bool { _isThought ?? false }

  let thoughtSignature: Data?

  let _isThought: Bool?

  public init(_ text: String) {
    self.init(text, isThought: nil, thoughtSignature: nil)
  }

  init(_ text: String, isThought: Bool?, thoughtSignature: Data?) {
    self.text = text
    _isThought = isThought
    self.thoughtSignature = thoughtSignature
  }
}

/// A data part that is provided inline in requests.
///
/// Data provided as an inline data part is encoded as base64 and included directly (inline) in the
/// request. For large files, see ``FileDataPart`` which references content by URI instead of
/// including the data in the request.
///
/// > Important: Only small files can be sent as inline data because of limits on total request
/// sizes;
///  see [input files and requirements
///  ](https://firebase.google.com/docs/vertex-ai/input-file-requirements#provide-file-as-inline-data)
///  for more details and size limits.
public struct InlineDataPart: Part {
  let inlineData: GenerateContentAPI.Blob
  let _isThought: Bool?

  /// The data provided in the inline data part.
  public var data: Data { AILog.safeUnwrap(inlineData.data, fallback: Data()) }

  /// The IANA standard MIME type of the data.
  public var mimeType: String {
    AILog.safeUnwrap(inlineData.mimeType, fallback: Constants.unknownDataMIMEType)
  }

  public var isThought: Bool { _isThought ?? false }

  let thoughtSignature: Data?

  /// Creates an inline data part from data and a MIME type.
  ///
  /// > Important: Supported input types depend on the model on the model being used; see [input
  ///  files and requirements](https://firebase.google.com/docs/vertex-ai/input-file-requirements)
  ///  for more details.
  ///
  /// - Parameters:
  ///   - data: The data representation of an image, video, audio or document; see [input files and
  ///     requirements](https://firebase.google.com/docs/vertex-ai/input-file-requirements) for
  ///     supported media types.
  ///   - mimeType: The IANA standard MIME type of the data, for example, `"image/jpeg"` or
  ///     `"video/mp4"`; see [input files and
  ///     requirements](https://firebase.google.com/docs/vertex-ai/input-file-requirements) for
  ///     supported values.
  public init(data: Data, mimeType: String) {
    self.init(
      GenerateContentAPI.Blob(mimeType: mimeType, data: data),
      isThought: nil,
      thoughtSignature: nil
    )
  }

  init(_ inlineData: GenerateContentAPI.Blob, isThought: Bool?, thoughtSignature: Data?) {
    self.inlineData = inlineData
    _isThought = isThought
    self.thoughtSignature = thoughtSignature
  }
}

/// File data stored in Cloud Storage for Firebase, referenced by URI.
public struct FileDataPart: Part {
  let fileData: FileData
  let _isThought: Bool?
  let thoughtSignature: Data?

  public var uri: String {
    AILog.safeUnwrap(fileData.fileUri, fallback: Constants.unknownFileURI)
  }

  public var mimeType: String {
    AILog.safeUnwrap(fileData.mimeType, fallback: Constants.unknownDataMIMEType)
  }

  public var isThought: Bool { _isThought ?? false }

  /// Constructs a new file data part.
  ///
  /// - Parameters:
  ///   - uri: The `"gs://"`-prefixed URI of the file in Cloud Storage for Firebase, for example,
  ///     `"gs://bucket-name/path/image.jpg"`.
  ///   - mimeType: The IANA standard MIME type of the uploaded file, for example, `"image/jpeg"`
  ///     or `"video/mp4"`; see [supported input files and
  ///     requirements](https://firebase.google.com/docs/vertex-ai/input-file-requirements) for
  ///     supported values.
  public init(uri: String, mimeType: String) {
    self.init(
      GenerateContentAPI.FileData(mimeType: mimeType, fileUri: uri),
      isThought: nil,
      thoughtSignature: nil
    )
  }

  init(_ fileData: GenerateContentAPI.FileData, isThought: Bool?, thoughtSignature: Data?) {
    self.fileData = fileData
    _isThought = isThought
    self.thoughtSignature = thoughtSignature
  }
}

/// A predicted function call returned from the model.
public struct FunctionCallPart: Part {
  let functionCall: GenerateContentAPI.FunctionCall
  let _isThought: Bool?
  let thoughtSignature: Data?

  /// The name of the function to call.
  public var name: String {
    AILog.safeUnwrap(functionCall.name, fallback: Constants.unknownFunctionName)
  }

  /// The function parameters and values.
  public var args: JSONObject { functionCall.args?.mapValues { JSONValue($0) } ?? [:] }

  public var isThought: Bool { _isThought ?? false }

  /// Unique id of the function call.
  ///
  /// If present, the returned ``FunctionResponsePart`` should have a matching `functionId` field.
  public var functionId: String? { functionCall.id }

  /// Constructs a new function call part.
  ///
  /// > Note: A `FunctionCallPart` is typically received from the model, rather than created
  /// manually.
  ///
  /// - Parameters:
  ///   - name: The name of the function to call.
  ///   - args: The function parameters and values.
  ///   - id: Unique id of the function call. If present, the returned ``FunctionResponsePart``
  ///     should have a matching ``FunctionResponsePart/functionId`` field.
  public init(name: String, args: JSONObject, id: String? = nil) {
    self.init(
      GenerateContentAPI.FunctionCall(
        id: id,
        name: name,
        args: args.mapValues { $0.toRequestPayload() }
      ),
      isThought: nil,
      thoughtSignature: nil
    )
  }

  init(_ functionCall: GenerateContentAPI.FunctionCall, isThought: Bool? = nil, thoughtSignature: Data? = nil) {
    self.functionCall = functionCall
    _isThought = isThought
    self.thoughtSignature = thoughtSignature
  }
}

/// Result output from a function call.
///
/// Contains a string representing the `FunctionDeclaration.name` and a structured JSON object
/// containing any output from the function is used as context to the model. This should contain the
/// result of a ``FunctionCallPart`` made based on model prediction.
public struct FunctionResponsePart: Part {
  let functionResponse: GenerateContentAPI.FunctionResponse
  let _isThought: Bool?
  let thoughtSignature: Data?

  /// Matching ``FunctionCallPart/functionId`` for a ``FunctionCallPart``, if one was provided.
  public var functionId: String? { functionResponse.id }

  /// The name of the function that was called.
  public var name: String {
    AILog.safeUnwrap(functionResponse.name, fallback: Constants.unknownFunctionName)
  }

  /// The function's response or return value.
  public var response: JSONObject { functionResponse.response?.mapValues { JSONValue($0) } ?? [:] }

  public var isThought: Bool { _isThought ?? false }

  /// Constructs a new `FunctionResponse`.
  ///
  /// - Parameters:
  ///   - name: The name of the function that was called.
  ///   - response: The function's response.
  ///   - functionId: Matching ``FunctionCallPart/functionId`` for a ``FunctionCallPart``, if one
  ///     was provided.
  public init(name: String, response: JSONObject, functionId: String? = nil) {
    self.init(
      GenerateContentAPI.FunctionResponse(
        id: functionId,
        name: name,
        response: response.mapValues { $0.toRequestPayload() }
      ),
      isThought: nil,
      thoughtSignature: nil
    )
  }

  init(_ functionResponse: FunctionResponse, isThought: Bool?, thoughtSignature: Data?) {
    self.functionResponse = functionResponse
    _isThought = isThought
    self.thoughtSignature = thoughtSignature
  }
}

/// A part containing code that was executed by the model.
public struct ExecutableCodePart: Part {
  /// The language of the code in an ``ExecutableCodePart``.
  public struct Language: Sendable, Equatable, CustomStringConvertible {
    let internalLanguage: GenerateContentAPI.ExecutableCode.Language

    /// The Python programming language.
    public static let python = ExecutableCodePart.Language(.python)

    public var description: String { internalLanguage.rawValue }

    init(_ language: GenerateContentAPI.ExecutableCode.Language) {
      internalLanguage = language
    }
  }

  let executableCode: GenerateContentAPI.ExecutableCode
  let _isThought: Bool?
  let thoughtSignature: Data?

  /// The language of the code.
  public var language: ExecutableCodePart.Language {
    // Fallback to "LANGUAGE_UNSPECIFIED" if the value is ever omitted by the backend; this should
    // never happen.
    ExecutableCodePart.Language(
      AILog.safeUnwrap(
        executableCode.language, fallback: .unrecognized("LANGUAGE_UNSPECIFIED")
      )
    )
  }

  /// The code that was executed.
  public var code: String {
    // Fallback to empty string if `code` is ever omitted by the backend; this should never happen.
    AILog.safeUnwrap(executableCode.code, fallback: "")
  }

  public var isThought: Bool { _isThought ?? false }

  public init(language: ExecutableCodePart.Language, code: String) {
    self.init(
      GenerateContentAPI.ExecutableCode(language: language.internalLanguage, code: code),
      isThought: nil,
      thoughtSignature: nil
    )
  }

  init(_ executableCode: ExecutableCode, isThought: Bool?, thoughtSignature: Data?) {
    self.executableCode = executableCode
    _isThought = isThought
    self.thoughtSignature = thoughtSignature
  }
}

/// The result of executing code.
public struct CodeExecutionResultPart: Part {
  /// The outcome of a code execution.
  public struct Outcome: Sendable, Equatable, CustomStringConvertible {
    let internalOutcome: CodeExecutionResult.Outcome

    /// The code executed without errors.
    public static let ok = CodeExecutionResultPart.Outcome(.ok)

    /// The code failed to execute.
    public static let failed = CodeExecutionResultPart.Outcome(.failed)

    /// The code took too long to execute.
    public static let deadlineExceeded = CodeExecutionResultPart.Outcome(.deadlineExceeded)

    public var description: String { internalOutcome.rawValue }

    init(_ outcome: GenerateContentAPI.CodeExecutionResult.Outcome) {
      internalOutcome = outcome
    }
  }

  let codeExecutionResult: GenerateContentAPI.CodeExecutionResult
  let _isThought: Bool?
  let thoughtSignature: Data?

  /// The outcome of the code execution.
  public var outcome: CodeExecutionResultPart.Outcome {
    CodeExecutionResultPart.Outcome(
      // Fallback to "OUTCOME_UNSPECIFIED" if this value is ever omitted by the backend; this should
      // never happen.
      AILog.safeUnwrap(codeExecutionResult.outcome, fallback: .unrecognized("OUTCOME_UNSPECIFIED"))
    )
  }

  /// The output of the code execution.
  public var output: String? { codeExecutionResult.output }

  public var isThought: Bool { _isThought ?? false }

  public init(outcome: CodeExecutionResultPart.Outcome, output: String) {
    self.init(
      codeExecutionResult: CodeExecutionResult(outcome: outcome.internalOutcome, output: output),
      isThought: nil,
      thoughtSignature: nil
    )
  }

  init(codeExecutionResult: CodeExecutionResult, isThought: Bool?, thoughtSignature: Data?) {
    self.codeExecutionResult = codeExecutionResult
    _isThought = isThought
    self.thoughtSignature = thoughtSignature
  }
}

#if compiler(>=6.2.3) && canImport(FoundationModels)
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  extension [any Part] {
    func toFoundationModelsPrompt() throws -> FoundationModels.Prompt {
      let promptParts: [any FoundationModels.PromptRepresentable] = try self
        .compactMap { part in
          // Skip any `thought` parts since they are unused by Foundation Models.
          guard !part.isThought else { return nil }

          guard let textPart = part as? TextPart else {
            throw GenerativeModelSession.GenerationError.unsupportedPromptContent(
              GenerativeModelSession.GenerationError.Context(
                debugDescription: """
                Prompt data type "\(type(of: part))" is not supported by the on-device model; currently only \
                text content is supported.
                """
              )
            )
          }

          return textPart.text
        }

      return Prompt {
        for part in promptParts {
          part.promptRepresentation
        }
      }
    }
  }
#endif // compiler(>=6.2.3) && canImport(FoundationModels)

// MARK: - Payload Convertible Conformances

extension TextPart: ConvertibleToRequestPayload {
  public func encode(to encoder: any Encoder) throws {
    try defaultEncode(to: encoder)
  }

  func toRequestPayload() throws -> GenerateContentAPI.Part {
    return GenerateContentAPI.Part(
      data: .text(text),
      thought: _isThought,
      thoughtSignature: thoughtSignature
    )
  }
}

extension InlineDataPart: ConvertibleToRequestPayload {
  public func encode(to encoder: any Encoder) throws {
    try defaultEncode(to: encoder)
  }

  func toRequestPayload() throws -> GenerateContentAPI.Part {
    return GenerateContentAPI.Part(
      data: .inlineData(inlineData),
      thought: _isThought,
      thoughtSignature: thoughtSignature
    )
  }
}

extension FileDataPart: ConvertibleToRequestPayload {
  public func encode(to encoder: any Encoder) throws {
    try defaultEncode(to: encoder)
  }

  func toRequestPayload() throws -> GenerateContentAPI.Part {
    let fileDataPayload = GenerateContentAPI.FileData(mimeType: mimeType, fileUri: uri)
    return GenerateContentAPI.Part(
      data: .fileData(fileDataPayload),
      thought: _isThought,
      thoughtSignature: thoughtSignature
    )
  }
}

extension FunctionCallPart: ConvertibleToRequestPayload {
  public func encode(to encoder: any Encoder) throws {
    try defaultEncode(to: encoder)
  }

  func toRequestPayload() throws -> GenerateContentAPI.Part {
    return GenerateContentAPI.Part(
      data: .functionCall(functionCall),
      thought: _isThought,
      thoughtSignature: thoughtSignature
    )
  }
}

extension FunctionResponsePart: ConvertibleToRequestPayload {
  public func encode(to encoder: any Encoder) throws {
    try defaultEncode(to: encoder)
  }

  func toRequestPayload() throws -> GenerateContentAPI.Part {
    return GenerateContentAPI.Part(
      data: .functionResponse(functionResponse),
      thought: _isThought,
      thoughtSignature: thoughtSignature
    )
  }
}

extension ExecutableCodePart: ConvertibleToRequestPayload {
  public func encode(to encoder: any Encoder) throws {
    try defaultEncode(to: encoder)
  }

  func toRequestPayload() throws -> GenerateContentAPI.Part {
    return GenerateContentAPI.Part(
      data: .executableCode(executableCode),
      thought: _isThought,
      thoughtSignature: thoughtSignature
    )
  }
}

extension CodeExecutionResultPart: ConvertibleToRequestPayload {
  public func encode(to encoder: any Encoder) throws {
    try defaultEncode(to: encoder)
  }

  func toRequestPayload() throws -> GenerateContentAPI.Part {
    return GenerateContentAPI.Part(
      data: .codeExecutionResult(codeExecutionResult),
      thought: _isThought,
      thoughtSignature: thoughtSignature
    )
  }
}

