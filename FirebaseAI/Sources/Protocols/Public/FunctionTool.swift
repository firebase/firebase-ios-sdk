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

public protocol FunctionTool<Arguments, Output>: ToolRepresentable {
  associatedtype Arguments : FirebaseAI.ConvertibleFromGeneratedContent
  associatedtype Output : FirebaseAI.ConvertibleToGeneratedContent

  var name: String { get }
  var description: String { get }
  var parametersSchema: FirebaseAI.GenerationSchema { get }
  var responseSchema: FirebaseAI.GenerationSchema? { get }
  var includesSchemaInInstructions: Bool { get }

  @concurrent func call(arguments: Self.Arguments) async throws -> Self.Output
}

public extension FunctionTool {
  var name: String { String(describing: Self.self) }
  var responseSchema: FirebaseAI.GenerationSchema? { nil }
  var includesSchemaInInstructions: Bool { true }
}

public extension FunctionTool where Self.Arguments: FirebaseAI.Generable {
  var parametersSchema: FirebaseAI.GenerationSchema { Arguments.firebaseGenerationSchema }
}

#if canImport(FoundationModels)
  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public extension FunctionTool where Self.Arguments: FoundationModels.Generable {
    var parametersSchema: FirebaseAI.GenerationSchema {
      FirebaseAI.GenerationSchema(Arguments.generationSchema)
    }
  }
#endif // canImport(FoundationModels)

public extension FunctionTool where Self.Output: FirebaseAI.Generable {
  var responseSchema: FirebaseAI.GenerationSchema? { Output.firebaseGenerationSchema }
}

#if canImport(FoundationModels)
  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public extension FunctionTool where Self.Output: FoundationModels.Generable {
    var responseSchema: FirebaseAI.GenerationSchema? {
      FirebaseAI.GenerationSchema(Output.generationSchema)
    }
  }
#endif // canImport(FoundationModels)
