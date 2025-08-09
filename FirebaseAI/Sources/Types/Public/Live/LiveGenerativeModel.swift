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
  let apiConfig: APIConfig
  let requestOptions: RequestOptions

  init(modelResourceName: String,
       firebaseInfo: FirebaseInfo,
       apiConfig: APIConfig,
       requestOptions: RequestOptions,
       urlSession: URLSession = GenAIURLSession.default) {
    self.modelResourceName = modelResourceName
    self.apiConfig = apiConfig
    // TODO: Add LiveGenerationConfig
    // TODO: Add tools
    // TODO: Add tool config
    // TODO: Add system instruction
    self.requestOptions = requestOptions
  }

  public func connect() async throws -> LiveSession {
    // TODO: Implement connection
    return LiveSession()
  }
}
