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
  struct Instructions: Sendable {
    enum InstructionsPart {
      case text(String)
      case structure(FirebaseAI.GeneratedContent)
    }

    let parts: [InstructionsPart]

    init(parts: [InstructionsPart]) {
      self.parts = parts
    }

    public init(_ content: some FirebaseAI.InstructionsRepresentable) {
      parts = content.firebaseInstructionsRepresentation.parts
    }

    public init(@FirebaseAI.InstructionsBuilder _ content: () throws -> Instructions) rethrows {
      self = try content()
    }

    #if canImport(FoundationModels)
      @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      func toFoundationModels() -> FoundationModels.Instructions {
        return FoundationModels.Instructions {
          for part in parts {
            switch part {
            case let .text(text):
              text
            case let .structure(structure):
              structure
            }
          }
        }
      }
    #endif // canImport(FoundationModels)

    func toModelContent() -> ModelContent {
      return ModelContent(
        role: "system",
        parts: parts.map {
          switch $0 {
          case let .text(string):
            return TextPart(string)
          case let .structure(generatedContent):
            return TextPart(generatedContent.jsonString)
          }
        }
      )
    }
  }
}

extension FirebaseAI.Instructions: FirebaseAI.InstructionsRepresentable {
  public var firebaseInstructionsRepresentation: FirebaseAI.Instructions {
    self
  }
}
