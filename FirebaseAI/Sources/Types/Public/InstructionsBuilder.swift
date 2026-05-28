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

public extension FirebaseAI {
  @resultBuilder
  struct InstructionsBuilder {
    public static func buildBlock<each I>(_ components: repeat each I)
      -> FirebaseAI.Instructions where repeat each I: FirebaseAI.InstructionsRepresentable {
        var allComponents: [FirebaseAI.Instructions.InstructionsPart] = []
        repeat allComponents
          .append(contentsOf: (each components).firebaseInstructionsRepresentation.parts)
        return FirebaseAI.Instructions(parts: allComponents)
      }

    public static func buildArray(_ instructions: [some FirebaseAI.InstructionsRepresentable])
      -> FirebaseAI.Instructions {
      let allComponents = instructions.flatMap { $0.firebaseInstructionsRepresentation.parts }
      return FirebaseAI.Instructions(parts: allComponents)
    }

    public static func buildEither(first component: some FirebaseAI.InstructionsRepresentable)
      -> FirebaseAI.Instructions {
      component.firebaseInstructionsRepresentation
    }

    public static func buildEither(second component: some FirebaseAI.InstructionsRepresentable)
      -> FirebaseAI.Instructions {
      component.firebaseInstructionsRepresentation
    }

    public static func buildOptional(_ instructions: FirebaseAI.Instructions?)
      -> FirebaseAI.Instructions {
      instructions ?? FirebaseAI.Instructions(parts: [])
    }

    public static func buildLimitedAvailability(_ instructions: some FirebaseAI
      .InstructionsRepresentable) -> FirebaseAI.Instructions {
      instructions.firebaseInstructionsRepresentation
    }

    public static func buildExpression<I>(_ expression: I)
      -> I where I: FirebaseAI.InstructionsRepresentable {
      expression
    }

    public static func buildExpression(_ expression: FirebaseAI.Instructions)
      -> FirebaseAI.Instructions {
      expression
    }

    #if canImport(FoundationModels)
      @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      public static func buildExpression(_ expression: FoundationModels
        .ConvertibleToGeneratedContent) -> FirebaseAI.Instructions {
        FirebaseAI.Instructions(expression.generatedContent)
      }
    #endif // canImport(FoundationModels)
  }
}
