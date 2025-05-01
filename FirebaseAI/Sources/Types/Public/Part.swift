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

/// A discrete piece of data in a media format interpretable by an AI model.
///
/// Within a single value of ``Part``, different data types may not mix.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public protocol Part: PartsRepresentable, Codable, Sendable, Equatable {}

/// A text part containing a string value.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct TextPart: Part {
  /// Text value.
  public let text: String

  public init(_ text: String) {
    self.text = text
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
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct InlineDataPart: Part {
  let inlineData: InlineData

  /// The data provided in the inline data part.
  public var data: Data { inlineData.data }

  /// The IANA standard MIME type of the data.
  public var mimeType: String { inlineData.mimeType }

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
    self.init(InlineData(data: data, mimeType: mimeType))
  }

  init(_ inlineData: InlineData) {
    self.inlineData = inlineData
  }
}

/// File data stored in Cloud Storage for Firebase, referenced by URI.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct FileDataPart: Part {
  let fileData: FileData

  public var uri: String { fileData.fileURI }
  public var mimeType: String { fileData.mimeType }

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
    self.init(FileData(fileURI: uri, mimeType: mimeType))
  }

  init(_ fileData: FileData) {
    self.fileData = fileData
  }
}

/// A predicted function call returned from the model.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct FunctionCallPart: Part {
  let functionCall: FunctionCall

  /// The name of the function to call.
  public var name: String { functionCall.name }

  /// The function parameters and values.
  public var args: JSONObject { functionCall.args }

  /// Constructs a new function call part.
  ///
  /// > Note: A `FunctionCallPart` is typically received from the model, rather than created
  /// manually.
  ///
  /// - Parameters:
  ///   - name: The name of the function to call.
  ///   - args: The function parameters and values.
  public init(name: String, args: JSONObject) {
    self.init(FunctionCall(name: name, args: args))
  }

  init(_ functionCall: FunctionCall) {
    self.functionCall = functionCall
  }
}

/// Result output from a function call.
///
/// Contains a string representing the `FunctionDeclaration.name` and a structured JSON object
/// containing any output from the function is used as context to the model. This should contain the
/// result of a ``FunctionCallPart`` made based on model prediction.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct FunctionResponsePart: Part {
  let functionResponse: FunctionResponse

  /// The name of the function that was called.
  public var name: String { functionResponse.name }

  /// The function's response or return value.
  public var response: JSONObject { functionResponse.response }

  /// Constructs a new `FunctionResponse`.
  ///
  /// - Parameters:
  ///   - name: The name of the function that was called.
  ///   - response: The function's response.
  public init(name: String, response: JSONObject) {
    self.init(FunctionResponse(name: name, response: response))
  }

  init(_ functionResponse: FunctionResponse) {
    self.functionResponse = functionResponse
  }
}
