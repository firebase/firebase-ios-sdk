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
  final class LanguageModelSession: Sendable {
    private let _session: (any Sendable)?

    #if canImport(FoundationModels)
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      var session: FoundationModels.LanguageModelSession? {
        return _session as? FoundationModels.LanguageModelSession
      }
    #endif // canImport(FoundationModels)

    var isResponding: Bool {
      #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, visionOS 26.0, *), let session else { return false }

        return session.isResponding
      #else
        return false
      #endif // canImport(FoundationModels)
    }

    init(model: FirebaseAI.SystemLanguageModel) {
      #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
          guard let model = model.model else { fatalError() }
          _session = FoundationModels.LanguageModelSession(model: model)
        } else {
          _session = nil
        }
      #else
        _session = nil
      #endif
    }
  }
}
