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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct InlineData: Codable, Equatable, Sendable {
  let mimeType: String
  let data: Data

  init(data: Data, mimeType: String) {
    self.data = data
    self.mimeType = mimeType
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct FileData: Codable, Equatable, Sendable {
  let fileURI: String
  let mimeType: String

  init(fileURI: String, mimeType: String) {
    self.fileURI = fileURI
    self.mimeType = mimeType
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct FunctionCall: Equatable, Sendable {
  let name: String
  let args: JSONObject

  init(name: String, args: JSONObject) {
    self.name = name
    self.args = args
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct FunctionResponse: Codable, Equatable, Sendable {
  let name: String
  let response: JSONObject

  init(name: String, response: JSONObject) {
    self.name = name
    self.response = response
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct ErrorPart: Part, Error {
  let error: Error

  init(_ error: Error) {
    self.error = error
  }
}

// MARK: - Codable Conformances

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension FunctionCall: Codable {
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    if let args = try container.decodeIfPresent(JSONObject.self, forKey: .args) {
      self.args = args
    } else {
      args = JSONObject()
    }
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ErrorPart: Codable {
  init(from decoder: any Decoder) throws {
    fatalError("Decoding an ErrorPart is not supported.")
  }

  func encode(to encoder: any Encoder) throws {
    fatalError("Encoding an ErrorPart is not supported.")
  }
}

// MARK: - Equatable Conformances

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ErrorPart: Equatable {
  static func == (lhs: ErrorPart, rhs: ErrorPart) -> Bool {
    fatalError("Comparing ErrorParts for equality is not supported.")
  }
}
