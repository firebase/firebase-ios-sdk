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

#if compiler(>=6.2)
  #if canImport(FoundationModels)
    import FoundationModels
  #endif // canImport(FoundationModels)

  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  public extension FirebaseAI {
    protocol ConvertibleToGeneratedContent {
      var firebaseGeneratedContent: FirebaseAI.GeneratedContent { get }
    }
  }

  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  extension String: FirebaseAI.ConvertibleToGeneratedContent {
    public var firebaseGeneratedContent: FirebaseAI.GeneratedContent {
      FirebaseAI.GeneratedContent(kind: .string(self), isComplete: true)
    }
  }

  #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public extension FirebaseAI.ConvertibleToGeneratedContent
      where Self: FoundationModels.ConvertibleToGeneratedContent {
      var firebaseGeneratedContent: FirebaseAI.GeneratedContent {
        return FirebaseAI.GeneratedContent(
          kind: generatedContent.kind,
          id: FirebaseAI.GenerationID(responseID: nil, generationID: generatedContent.id),
          isComplete: generatedContent.isComplete
        )
      }
    }

  #endif // canImport(FoundationModels)
#endif // compiler(>=6.2)
