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
public struct InlineDataPart: Part {
  let inlineData: InlineData

  public var data: Data { inlineData.data }
  public var mimeType: String { inlineData.mimeType }

  public init(data: Data, mimeType: String) {
    self.init(InlineData(data: data, mimeType: mimeType))
  }

  init(_ inlineData: InlineData) {
    self.inlineData = inlineData
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct FileDataPart: Part {
  let fileData: FileData

  public var uri: String { fileData.fileURI }
  public var mimeType: String { fileData.mimeType }

  public init(uri: String, mimeType: String) {
    self.init(FileData(fileURI: uri, mimeType: mimeType))
  }

  init(_ fileData: FileData) {
    self.fileData = fileData
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct FunctionCallPart: Part {
  // TODO: Consider making FunctionCall internal and exposing params on FunctionCallPart instead.
  public let functionCall: FunctionCall

  public init(_ functionCall: FunctionCall) {
    self.functionCall = functionCall
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct FunctionResponsePart: Part {
  // TODO: Consider making FunctionResponsePart internal and exposing params here instead.
  public let functionResponse: FunctionResponse

  public init(functionResponse: FunctionResponse) {
    self.functionResponse = functionResponse
  }
}
