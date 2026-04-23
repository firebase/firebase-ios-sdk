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
  public struct GeminiModelProvider: LanguageModelProvider {
    let modelName: String
    let safetySettings: [SafetySetting]?
    let requestOptions: RequestOptions

    init(modelName: String, safetySettings: [SafetySetting]? = nil,
         requestOptions: RequestOptions = RequestOptions()) {
      self.modelName = modelName
      self.safetySettings = safetySettings
      self.requestOptions = requestOptions
    }

    public func _languageModel(firebaseAI: FirebaseAI) -> any LanguageModel {
      return firebaseAI.geminiModel(
        name: modelName,
        safetySettings: safetySettings,
        requestOptions: requestOptions
      )
    }
  }
#endif // compiler(>=6.2.3)
