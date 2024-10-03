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

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public protocol Part: PartsRepresentable, Codable, Sendable, Equatable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct TextPart: Part {
  public let text: String

  public init(_ text: String) {
    self.text = text
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct InlineData: Codable, Equatable, Sendable {
  public let mimeType: String
  public let data: Data

  public init(mimeType: String, data: Data) {
    self.mimeType = mimeType
    self.data = data
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct InlineDataPart: Part {
  public let inlineData: InlineData

  public init(inlineData: InlineData) {
    self.inlineData = inlineData
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct FileData: Codable, Equatable, Sendable {
  enum CodingKeys: String, CodingKey {
    case mimeType = "mime_type"
    case uri = "file_uri"
  }

  public let mimeType: String
  public let uri: String

  public init(mimeType: String, uri: String) {
    self.mimeType = mimeType
    self.uri = uri
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct FileDataPart: Part {
  public let fileData: FileData

  public init(fileData: FileData) {
    self.fileData = fileData
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct FunctionCallPart: Part {
  public let functionCall: FunctionCall

  public init(functionCall: FunctionCall) {
    self.functionCall = functionCall
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct FunctionResponsePart: Part {
  public let functionResponse: FunctionResponse

  public init(functionResponse: FunctionResponse) {
    self.functionResponse = functionResponse
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct ErrorPart: Part, Error {
  let error: Error

  init(_ error: Error) {
    self.error = error
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ErrorPart: Equatable {
  static func == (lhs: ErrorPart, rhs: ErrorPart) -> Bool {
    fatalError("Comparing ErrorParts for equality is not supported.")
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ErrorPart: Codable {
  init(from decoder: any Decoder) throws {
    fatalError("Decoding an ErrorPart is not supported.")
  }

  func encode(to encoder: any Encoder) throws {
    fatalError("Encoding an ErrorPart is not supported.")
  }
}
