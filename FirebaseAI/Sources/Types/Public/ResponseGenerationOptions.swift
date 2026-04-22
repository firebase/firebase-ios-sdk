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

#if compiler(>=6.2.3)
  /// Options for controlling model response generation.
  ///
  /// See ``GenerationOptionsRepresentable`` for details on how to configure generation options.
  public struct ResponseGenerationOptions: Sendable, Equatable {
    let geminiGenerationConfig: GenerationConfig?
    let foundationModelsGenerationOptions: FirebaseAI.GenerationOptions?

    init(geminiGenerationConfig: GenerationConfig? = nil,
         foundationModelsGenerationOptions: FirebaseAI.GenerationOptions? = nil) {
      self.geminiGenerationConfig = geminiGenerationConfig
      self.foundationModelsGenerationOptions = foundationModelsGenerationOptions
    }
  }

  extension ResponseGenerationOptions: GenerationOptionsRepresentable {
    public var responseGenerationOptions: ResponseGenerationOptions {
      return self
    }
  }
#endif // compiler(>=6.2.3)
