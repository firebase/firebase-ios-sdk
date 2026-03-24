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

#if canImport(FoundationModels)
  import FoundationModels
#endif // canImport(FoundationModels)

extension FirebaseAI {
  final class SystemLanguageModel: Sendable {
    private let _model: (any Sendable)?

    init() {
      #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
          _model = FoundationModels.SystemLanguageModel()
        } else {
          _model = nil
        }
      #else
        _model = nil
      #endif
    }

    #if canImport(FoundationModels)
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      var model: FoundationModels.SystemLanguageModel? {
        return _model as? FoundationModels.SystemLanguageModel
      }
    #endif // canImport(FoundationModels)

    var isAvailable: Bool {
      #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, visionOS 26.0, *), let model else { return false }
      #endif // canImport(FoundationModels)

      return model.isAvailable
    }
  }
}
