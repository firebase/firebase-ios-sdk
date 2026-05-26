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

@resultBuilder
public struct SystemInstructionsBuilder {
  public static func buildBlock<each I>(_ components: repeat each I) -> SystemInstructions
    where repeat each I: SystemInstructionsRepresentable {
      var allComponents: [SystemInstructions.InstructionsPart] = []
      repeat allComponents
        .append(contentsOf: (each components).systemInstructionsRepresentation.parts)
      return SystemInstructions(parts: allComponents)
    }

  public static func buildArray(_ instructions: [some SystemInstructionsRepresentable])
    -> SystemInstructions {
    let allComponents = instructions.flatMap { $0.systemInstructionsRepresentation.parts }
    return SystemInstructions(parts: allComponents)
  }

  public static func buildEither(first component: some SystemInstructionsRepresentable)
    -> SystemInstructions {
    component.systemInstructionsRepresentation
  }

  public static func buildEither(second component: some SystemInstructionsRepresentable)
    -> SystemInstructions {
    component.systemInstructionsRepresentation
  }

  public static func buildOptional(_ instructions: SystemInstructions?) -> SystemInstructions {
    instructions ?? SystemInstructions(parts: [])
  }

  public static func buildLimitedAvailability(_ instructions: some SystemInstructionsRepresentable)
    -> SystemInstructions {
    instructions.systemInstructionsRepresentation
  }

  public static func buildExpression<I>(_ expression: I) -> I
    where I: SystemInstructionsRepresentable {
    expression
  }

  public static func buildExpression(_ expression: SystemInstructions) -> SystemInstructions {
    expression
  }
}
