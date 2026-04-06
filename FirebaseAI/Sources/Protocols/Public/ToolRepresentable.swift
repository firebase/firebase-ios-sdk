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
#endif

public protocol ToolRepresentable: Sendable {
  var toolRepresentation: FirebaseAILogic.Tool { get }
}

#if compiler(>=6.2.3) && canImport(FoundationModels)
  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public extension FoundationModels.Tool
    where Self.Output: FoundationModels.ConvertibleToGeneratedContent {
    var toolRepresentation: FirebaseAILogic.Tool {
      return FirebaseAILogic.Tool.autoFunctionDeclaration(self)
    }
  }
#endif // compiler(>=6.2.3) && canImport(FoundationModels)
