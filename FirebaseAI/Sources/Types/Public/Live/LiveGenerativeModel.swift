// Copyright 2025 Google LLC
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
public final class LiveGenerativeModel {
  let modelResourceName: String
  let firebaseInfo: FirebaseInfo
  let apiConfig: APIConfig
  let generationConfig: LiveGenerationConfig?
  let requestOptions: RequestOptions
  let urlSession: URLSession

  init(modelResourceName: String,
       firebaseInfo: FirebaseInfo,
       apiConfig: APIConfig,
       generationConfig: LiveGenerationConfig? = nil,
       requestOptions: RequestOptions,
       urlSession: URLSession = GenAIURLSession.default) {
    self.modelResourceName = modelResourceName
    self.firebaseInfo = firebaseInfo
    self.apiConfig = apiConfig
    self.generationConfig = generationConfig
    // TODO: Add tools
    // TODO: Add tool config
    // TODO: Add system instruction
    self.requestOptions = requestOptions
    self.urlSession = urlSession
  }

  public func connect() async throws -> LiveSession {
    let liveSession = LiveSession(
      modelResourceName: modelResourceName,
      generationConfig: generationConfig,
      url: webSocketURL(),
      urlSession: urlSession
    )
    print("Opening Live Session...")
    try await liveSession.open()
    return liveSession
  }

  func webSocketURL() -> URL {
    let urlString = switch apiConfig.service {
    case .vertexAI:
      "wss://firebasevertexai.googleapis.com/ws/google.firebase.vertexai.v1beta.LlmBidiService/BidiGenerateContent/locations/us-central1?key=\(firebaseInfo.apiKey)"
    case .googleAI:
      "wss://firebasevertexai.googleapis.com/ws/google.firebase.vertexai.v1beta.GenerativeService/BidiGenerateContent?key=\(firebaseInfo.apiKey)"
    }
    guard let url = URL(string: urlString) else {
      // TODO: Add error handling
      fatalError()
    }
    return url
  }
}
