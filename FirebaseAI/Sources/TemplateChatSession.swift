
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

/// A chat session that allows for conversation with a model.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public class TemplateChatSession {
  private let templateGenerateContent: ([ModelContent], String, [String: Any]) async throws
    -> GenerateContentResponse
  private let template: String
  public var history: [ModelContent]

  init(templateGenerateContent: @escaping (([ModelContent], String, [String: Any]) async throws
         -> GenerateContentResponse),
  template: String, history: [ModelContent]) {
    self.templateGenerateContent = templateGenerateContent
    self.template = template
    self.history = history
  }

  /// Sends a message to the model and returns the response.
  public func sendMessage(_ message: any PartsRepresentable,
                          variables: [String: Any]) async throws -> GenerateContentResponse {
    let response = try await templateGenerateContent(history, template, variables)
    history.append(ModelContent(role: "user", parts: message.partsValue))
    if let modelResponse = response.candidates.first {
      history.append(modelResponse.content)
    }
    return response
  }
}
